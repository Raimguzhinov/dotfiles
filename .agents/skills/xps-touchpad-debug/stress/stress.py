#!/usr/bin/env python3
import argparse, errno, fcntl, glob, json, os, re, shutil, signal, struct, subprocess, sys, threading, time

CLIENT = "i2c-VEN_04F3:00"
DEV = "/sys/bus/i2c/devices/" + CLIENT
DRV = "/sys/bus/i2c/drivers/i2c_hid_acpi"
WATCHDOG = "xps-touchpad-watchdog.service"
NAME = "VEN_04F3:00 04F3:31D1 "
EC_IO = "/sys/kernel/debug/ec/ec0/io"

HANG_RE = re.compile(
    r"i2c_designware\.1: controller timed out|timeout waiting for bus ready|timeout in disabling adapter"
    r"|VEN_04F3:00: failed .*-110")
STOP_RE = re.compile(r"i2c_designware\.1: spurious STOP")
REL_RE = re.compile(r"i2c_designware\.1|VEN_04F3|04F3:31D1")
IRQ_RE = re.compile(r"i2c_designware\.1|VEN_04F3")
IRQ_RATE_LIMIT = 50
IRQ_WINDOW = 2.0


def ioc(d, t, nr, size):
    return (d << 30) | (size << 16) | (t << 8) | nr


ABS_MT_SLOT, ABS_MT_TRACKING_ID = 0x2F, 0x39
BTN_LEFT, BTN_TOUCH = 0x110, 0x14A



def feature_reports(desc):
    g = {"size": 0, "count": 0, "id": 0}
    stack, bits, i = [], {}, 0
    while i < len(desc):
        b = desc[i]
        if b == 0xFE:
            i += 3 + desc[i + 1]
            continue
        n = (0, 1, 2, 4)[b & 3]
        v = int.from_bytes(desc[i + 1:i + 1 + n], "little")
        tag = b & 0xFC
        if tag == 0x74:
            g["size"] = v
        elif tag == 0x94:
            g["count"] = v
        elif tag == 0x84:
            g["id"] = v
        elif tag == 0xA4:
            stack.append(dict(g))
        elif tag == 0xB4 and stack:
            g = stack.pop()
        elif tag == 0xB0:
            bits[g["id"]] = bits.get(g["id"], 0) + g["size"] * g["count"]
        i += 1 + n
    return {rid: (b + 7) // 8 for rid, b in bits.items()}



def hid_dir():
    d = sorted(glob.glob(DEV + "/0018:04F3:31D1.*"))
    return d[-1] if d else None


def hidraw_node(hd):
    n = glob.glob(hd + "/hidraw/hidraw*") if hd else []
    return "/dev/" + os.path.basename(n[0]) if n else None


def evdev(hd, kind):
    for d in glob.glob(hd + "/input/input*") if hd else []:
        try:
            if open(d + "/name").read().strip() == NAME + kind:
                ev = glob.glob(d + "/event*")
                return "/dev/input/" + os.path.basename(ev[0]) if ev else None
        except OSError:
            pass
    return None


def irq_counts():
    out = {}
    with open("/proc/interrupts") as f:
        for line in f:
            if IRQ_RE.search(line):
                p = line.split()
                cnt = sum(int(x) for x in p[1:] if x.isdigit())
                out[p[0].rstrip(":") + " " + p[-1]] = cnt
    return out


def irq_delta(a, b):
    return {k: b[k] - a.get(k, 0) for k in b}


def suspend_stats():
    r = {}
    for k in ("success", "fail"):
        try:
            r[k] = int(open("/sys/power/suspend_stats/" + k).read())
        except OSError:
            r[k] = None
    return r



def with_timeout(fn, timeout):
    res = {}

    def run():
        try:
            res["v"] = fn()
        except OSError as e:
            res["errno"] = e.errno
            res["err"] = errno.errorcode.get(e.errno, str(e.errno))
        except Exception as e:
            res["err"] = repr(e)

    t = threading.Thread(target=run, daemon=True)
    t0 = time.monotonic()
    t.start()
    t.join(timeout)
    res["dur"] = round(time.monotonic() - t0, 4)
    if t.is_alive():
        res["timeout"] = True
    return res


def feature_probe(hd):
    r = {"ok": False}
    node = hidraw_node(hd)
    if not node:
        r["err"] = "nodev"
        return r
    try:
        reps = feature_reports(open(hd + "/report_descriptor", "rb").read())
    except OSError as e:
        r["err"] = "desc:" + str(e)
        return r
    if not reps:
        r["err"] = "no_feature_reports"
        return r
    rid = min(reps)
    ln = reps[rid] + 1
    r.update(node=node, report_id=rid, len=ln)

    def get():
        fd = os.open(node, os.O_RDWR)
        try:
            buf = bytearray(ln)
            buf[0] = rid
            n = fcntl.ioctl(fd, ioc(3, ord("H"), 0x07, len(buf)), buf, True)
            return n, buf[:max(n, 0)].hex()
        finally:
            os.close(fd)

    res = with_timeout(get, 5)
    r["dur"] = res["dur"]
    if res.get("timeout"):
        r["err"] = "timeout"
    elif "v" in res:
        r["ok"], r["ret"], r["data"] = True, res["v"][0], res["v"][1]
    else:
        r["err"], r["errno"] = res.get("err"), res.get("errno")
    return r


def evdev_state(node):
    if not node:
        return {"err": "nodev"}
    try:
        fd = os.open(node, os.O_RDONLY | os.O_NONBLOCK)
    except OSError as e:
        return {"err": errno.errorcode.get(e.errno, str(e))}
    try:
        st = {}
        keys = bytearray(96)
        fcntl.ioctl(fd, ioc(2, 0x45, 0x18, 96), keys)
        st["keys"] = [n for c, n in ((BTN_LEFT, "BTN_LEFT"), (BTN_TOUCH, "BTN_TOUCH"))
                      if keys[c // 8] >> (c % 8) & 1]
        absinfo = bytearray(24)
        try:
            fcntl.ioctl(fd, ioc(2, 0x45, 0x40 + ABS_MT_SLOT, 24), absinfo)
            ns = struct.unpack("6i", absinfo)[2] + 1
            buf = bytearray(struct.pack("i", ABS_MT_TRACKING_ID) + b"\0" * 4 * ns)
            fcntl.ioctl(fd, ioc(2, 0x45, 0x0A, len(buf)), buf)
            st["tracking"] = list(struct.unpack("%di" % ns, buf[4:]))
        except OSError:
            pass
        return st
    except OSError as e:
        return {"err": errno.errorcode.get(e.errno, str(e))}
    finally:
        os.close(fd)


def jcursor():
    m = re.search(r"-- cursor: (\S+)", sh("journalctl", "-k", "-n", "0", "--show-cursor", "-o", "cat", timeout=30)[1])
    return m.group(1) if m else None


def klog(since, cur=None):
    cmd = ["journalctl", "-k", "-o", "short-unix", "--no-pager"]
    cmd += ["--after-cursor", cur] if cur else ["--since", "@%d" % int(since)]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=30).stdout
    except subprocess.TimeoutExpired:
        return []
    lines = []
    for l in out.splitlines():
        try:
            if cur or float(l.split(" ", 1)[0]) >= since:
                lines.append(l)
        except ValueError:
            pass
    return lines


def ec_read(off=0x20, n=1):
    try:
        with open(EC_IO, "rb") as f:
            f.seek(off)
            d = f.read(n)
        return d.hex() if len(d) == n else None
    except OSError:
        return None


def health(since, irq0, cur=None):
    h = {"t": time.time(), "cursor": jcursor()}
    lines = klog(since, cur)
    h["ec20_after"] = ec_read()
    rel = [l for l in lines if REL_RE.search(l)]
    h["klog"] = {"hang": sum(bool(HANG_RE.search(l)) for l in lines),
                 "spurious_stop": sum(bool(STOP_RE.search(l)) for l in lines),
                 "related": len(rel), "sample": rel[:5] + (["..."] + rel[-5:] if len(rel) > 10 else rel[5:10])}
    hd = hid_dir()
    h["bound"] = os.path.exists(DEV + "/driver") and hd is not None
    h["hid"] = os.path.basename(hd) if hd else None
    h["feature"] = feature_probe(hd)
    h["touchpad"] = evdev_state(evdev(hd, "Touchpad"))
    h["mouse"] = evdev_state(evdev(hd, "Mouse"))
    a = irq_counts()
    time.sleep(IRQ_WINDOW)
    b = irq_counts()
    h["irq_cycle_delta"] = irq_delta(irq0, b) if irq0 else None
    h["irq_idle_rate"] = {k: round(v / IRQ_WINDOW, 1) for k, v in irq_delta(a, b).items()}
    return h


def phantom(h):
    tp, ms = h["touchpad"], h["mouse"]
    return bool(any(t != -1 for t in tp.get("tracking", [])) or tp.get("keys") or ms.get("keys"))


def classify(h):
    f = h["feature"]
    io_fail = not f["ok"] and (f.get("err") == "timeout" or f.get("errno") not in (None, errno.EACCES))
    if h["klog"]["hang"] or io_fail:
        return "hang"
    if h["klog"]["spurious_stop"] or phantom(h) or any(v > IRQ_RATE_LIMIT for v in h["irq_idle_rate"].values()):
        return "drift"
    if not h["bound"] or not f["ok"]:
        return "other"
    return "ok"



def sh(*cmd, timeout=None):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout + p.stderr).strip()[-500:]
    except (subprocess.TimeoutExpired, OSError) as e:
        return -1, repr(e)


def rebind():
    r = {}
    for op in ("unbind", "bind"):
        t0 = time.monotonic()
        try:
            with open(DRV + "/" + op, "w") as f:
                f.write(CLIENT)
            r[op] = "ok"
        except OSError as e:
            r[op] = errno.errorcode.get(e.errno, str(e))
        r[op + "_dur"] = round(time.monotonic() - t0, 3)
        if op == "unbind":
            time.sleep(1)
    return r


def rtcwake(path, secs):
    t0 = time.monotonic()
    rc, out = sh(path, "-m", "freeze", "-s", str(secs), timeout=secs + 300)
    return {"rc": rc, "out": out[-200:], "dur": round(time.monotonic() - t0, 1)}


def run_hook(cmd):
    t0 = time.monotonic()
    rc, out = sh("sh", "-c", cmd, timeout=300)
    return {"rc": rc, "out": out[-200:], "dur": round(time.monotonic() - t0, 2)}


class Run:
    def __init__(self, a):
        self.a = a
        os.makedirs(a.out, exist_ok=True)
        self.jsonl = open(os.path.join(a.out, "results.jsonl"), "a", buffering=1)
        self.counts = {"ok": 0, "hang": 0, "drift": 0, "other": 0}
        self.n = self.susp_fail = self.drift_persist = self.ec_changed = 0
        self.t0 = time.time()
        self.ec_start = ec_read()
        self.ec_vals = {self.ec_start} if self.ec_start else set()
        self.jsonl.write(json.dumps({"event": "start", "t": self.t0, "ec20": self.ec_start, "ec_dump": ec_read(0, 256)}) + "\n")

    def summary(self):
        lines = ["scenario: %s" % " ".join(sys.argv[1:]), "started: %s" % time.ctime(self.t0),
                 "updated: %s" % time.ctime(), "cycles: %d" % self.n]
        lines += ["%s: %d" % kv for kv in self.counts.items()]
        lines += ["hang_rate: %.2f%%" % (100.0 * self.counts["hang"] / self.n if self.n else 0),
                  "drift_persisted: %d" % self.drift_persist, "suspend_failed: %d" % self.susp_fail,
                  "ec20_start: %s" % self.ec_start, "ec20_changed_cycles: %d" % self.ec_changed,
                  "ec20_values: %s" % sorted(self.ec_vals)]
        tmp = os.path.join(self.a.out, "summary.txt.tmp")
        with open(tmp, "w") as f:
            f.write("\n".join(lines) + "\n")
        os.replace(tmp, os.path.join(self.a.out, "summary.txt"))

    def cycle(self, i, action):
        rec = {"cycle": i, "scenario": self.a.cmd, "t_start": time.time()}
        irq0, ss0, cur0 = irq_counts(), suspend_stats(), jcursor()
        rec["ec20_before"] = ec_read()
        rec.update(action())
        ss1 = suspend_stats()
        rec["suspend_stats_delta"] = {k: (ss1[k] - ss0[k]) if ss1[k] is not None and ss0[k] is not None else None
                                      for k in ss0}
        rw = rec.get("rtcwake")
        rec["suspend_failed"] = bool(rw and (rw["rc"] != 0 or (rec["suspend_stats_delta"]["fail"] or 0) > 0))
        self.susp_fail += rec["suspend_failed"]
        time.sleep(3)
        h = health(rec["t_start"], irq0, cur0)
        rec["health"] = h
        e0, e1 = rec["ec20_before"], h["ec20_after"]
        rec["ec20_after"] = e1
        self.ec_vals |= {e for e in (e0, e1) if e}
        self.ec_changed += e0 != e1
        if e1 != self.ec_start or e0 != e1:
            rec["ec_dump"] = ec_read(0, 256)
        c = rec["class"] = classify(h)
        if c == "ok" and rec["suspend_failed"]:
            c = rec["class"] = "other"
        self.counts[c] += 1
        self.n += 1
        fatal = False
        if c == "drift":
            time.sleep(10)
            h2 = health(h["t"], None, h["cursor"])
            rec["drift_recheck"] = h2
            rec["drift_persisted"] = classify(h2) == "drift"
            self.drift_persist += rec["drift_persisted"]
        elif c == "hang":
            fatal = True
        rec["t_end"] = time.time()
        self.jsonl.write(json.dumps(rec) + "\n")
        self.summary()
        f = h["feature"]
        print("%s #%d/%d %-5s feat=%s klog(hang=%d stop=%d rel=%d) phantom=%s irq/s=%s%s%s" % (
            time.strftime("%H:%M:%S"), i, self.a.cycles, c, "ok" if f["ok"] else f.get("err"),
            h["klog"]["hang"], h["klog"]["spurious_stop"], h["klog"]["related"], phantom(h),
            max(h["irq_idle_rate"].values(), default=0), " SUSPEND_FAILED" if rec["suspend_failed"] else "",
            " ec20=%s>%s" % (e0, e1)), flush=True)
        return fatal

    def loop(self, action):
        deadline = self.t0 + self.a.max_hours * 3600
        for i in range(1, self.a.cycles + 1):
            if time.time() > deadline:
                print("max-hours reached", flush=True)
                return 0
            if self.cycle(i, action):
                print("HANG at cycle %d: stopping, recovery requires manual hibernate" % i, flush=True)
                return 3
            if self.a.cmd == "t2a" and i < self.a.cycles:
                time.sleep(self.a.idle)
        return 0


def find_rtcwake(p):
    for c in (p, shutil.which("rtcwake"), "/run/current-system/sw/bin/rtcwake"):
        if c and os.access(c, os.X_OK):
            return c
    sys.exit("rtcwake not found")


def selftest():
    hd = hid_dir()
    print("hid dir:", hd)
    if hd:
        reps = feature_reports(open(hd + "/report_descriptor", "rb").read())
        print("feature reports {id: payload_bytes}:", {hex(k): v for k, v in sorted(reps.items())})
        print("chosen report id: 0x%02x" % min(reps) if reps else "none")
    h = health(time.time() - 60, irq_counts())
    print(json.dumps(h, indent=1))
    print("class:", classify(h))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--selftest", action="store_true")
    sp = p.add_subparsers(dest="cmd")
    for name in ("t1", "t2a", "t2b", "t3"):
        s = sp.add_parser(name)
        s.add_argument("--cycles", type=int, required=True)
        s.add_argument("--out", required=True)
        s.add_argument("--max-hours", type=float, default=12)
        s.add_argument("--rtcwake")
        if name in ("t1", "t2b", "t3"):
            s.add_argument("--sleep", type=int, required=True)
            s.add_argument("--hook")
        if name == "t2a":
            s.add_argument("--idle", type=float, required=True)
        if name == "t2b":
            s.add_argument("--bind-delay", type=float, required=True)
    a = p.parse_args()
    if a.selftest:
        return selftest()
    if not a.cmd:
        p.error("need a subcommand")
    if os.geteuid() != 0:
        sys.exit("must run as root")

    def on_term(sig, frm):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, on_term)
    signal.signal(signal.SIGHUP, on_term)
    sh("modprobe", "ec_sys")
    rtc = find_rtcwake(a.rtcwake) if a.cmd != "t2a" else None

    def t1():
        r = {"rtcwake": rtcwake(rtc, a.sleep)}
        if a.hook:
            r["hook"] = run_hook(a.hook)
        return r

    def t2b():
        r = t1()
        time.sleep(a.bind_delay)
        r["rebind"] = rebind()
        return r

    actions = {"t1": t1, "t2a": lambda: {"rebind": rebind()}, "t2b": t2b, "t3": t1}
    rc = 1
    print("stopping", WATCHDOG, sh("systemctl", "stop", WATCHDOG), flush=True)
    try:
        run = Run(a)
        run.summary()
        rc = run.loop(actions[a.cmd])
    except KeyboardInterrupt:
        print("interrupted", flush=True)
        rc = 130
    finally:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        if rc == 3:
            print(WATCHDOG, "left stopped (hang; starting it would hibernate)", flush=True)
        else:
            print("starting", WATCHDOG, sh("systemctl", "start", WATCHDOG), flush=True)
        sh("chown", "-R", "1000:100", a.out)
    return rc


if __name__ == "__main__":
    sys.exit(main() or 0)
