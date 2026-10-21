import fcntl, os, select, struct, sys, time

DEV = sys.argv[1] if len(sys.argv) > 1 else "/dev/input/event10"
SECS = float(sys.argv[2]) if len(sys.argv) > 2 else 20


def ioc_r(nr, size):
    return (2 << 30) | (size << 16) | (0x45 << 8) | nr


ABS_MT_SLOT, ABS_MT_TOOL_TYPE, ABS_MT_TRACKING_ID = 0x2F, 0x37, 0x39
KEYS = {0x110: "BTN_LEFT", 0x14A: "BTN_TOUCH", 0x145: "TOOL_FINGER",
        0x14D: "DOUBLETAP", 0x14E: "TRIPLETAP", 0x14F: "QUADTAP", 0x148: "QUINTTAP"}
TOOL = {0: "FINGER", 1: "PEN", 2: "PALM"}

fd = os.open(DEV, os.O_RDONLY | os.O_NONBLOCK)
absinfo = bytearray(24)
fcntl.ioctl(fd, ioc_r(0x40 + ABS_MT_SLOT, 24), absinfo)
nslots = struct.unpack("6i", absinfo)[2] + 1


def slots(code):
    buf = bytearray(struct.pack("i", code) + b"\0" * 4 * nslots)
    fcntl.ioctl(fd, ioc_r(0x0A, len(buf)), buf)
    return list(struct.unpack("%di" % nslots, buf[4:]))


def keys():
    buf = bytearray(96)
    fcntl.ioctl(fd, ioc_r(0x18, len(buf)), buf)
    return [n for c, n in KEYS.items() if buf[c // 8] >> (c % 8) & 1]


def snapshot(tag):
    tid, tool = slots(ABS_MT_TRACKING_ID), slots(ABS_MT_TOOL_TYPE)
    s = " ".join("s%d:id=%d,%s" % (i, tid[i], TOOL.get(tool[i], tool[i])) for i in range(nslots))
    print("[%s] %s | keys down: %s" % (tag, s, ",".join(keys()) or "-"), flush=True)


snapshot("snapshot")
print("now touch/click with ONE finger, then TWO fingers (%ds)..." % SECS, flush=True)
EV = struct.Struct("qqHHi")
slot, frame, end = 0, [], time.time() + SECS
while time.time() < end:
    if not select.select([fd], [], [], 0.5)[0]:
        continue
    data = os.read(fd, EV.size * 64)
    for off in range(0, len(data), EV.size):
        _, _, t, c, v = EV.unpack_from(data, off)
        if t == 3 and c == ABS_MT_SLOT:
            slot = v
        elif t == 3 and c == ABS_MT_TRACKING_ID:
            frame.append("s%d %s" % (slot, "UP" if v == -1 else "DOWN id=%d" % v))
        elif t == 3 and c == ABS_MT_TOOL_TYPE:
            frame.append("s%d tool=%s" % (slot, TOOL.get(v, v)))
        elif t == 1 and c in KEYS:
            frame.append("%s=%d" % (KEYS[c], v))
        elif t == 0 and c == 3:
            frame.append("SYN_DROPPED")
        elif t == 0 and c == 0 and frame:
            print("  " + "; ".join(frame), flush=True)
            frame = []
snapshot("end")
