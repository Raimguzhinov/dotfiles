{ ... }:
let
  model = "ornith-ai/Ornith-1.5-35B-A3B";
  port = 8085;
  api = "http://127.0.0.1:${toString port}";
  prefixFile = "pi-prefix.bin";
  modelBody = builtins.toJSON { inherit model; };
in
{
  flake.nixosModules.llamaCpp =
    { pkgs, pkgs-unstable, ... }:
    {
      config = {
        services.llama-cpp = {
          enable = true;
          host = "0.0.0.0";
          inherit port;
          package = pkgs-unstable.llama-cpp.override {
            blasSupport = true;
            vulkanSupport = true;
            cudaSupport = false;
            rocmSupport = false;
            metalSupport = false;
            openclSupport = false;
          };
          modelsPreset = {
            "*".dedup-cache-models = "true";
            ${model} = {
              hf-repo = "bartowski/Ornith-1.5-35B-A3B-GGUF";
              hf-file = "Ornith-1.5-35B-A3B-Q3_K_M.gguf";
              load-on-startup = "true";
              no-mmproj = "true";
              ctx-size = "65536";
              temp = "0.6";
              top-p = "0.95";
              top-k = "20";
              jinja = "on";
              flash-attn = "on";
            };
          };
          extraFlags = [
            "--device"
            "none"
            "--threads"
            "6"
            "--parallel"
            "1"
            "--cache-ram"
            "2048"
            "--models-max"
            "1"
            "--slot-save-path"
            "/var/lib/llama-cpp"
          ];
        };

        systemd.services.llama-cpp.serviceConfig = {
          CPUWeight = 20;
          IOWeight = 20;
          Nice = 10;
          MemoryHigh = "21G";
          OOMScoreAdjust = 500;
        };

        systemd.services.llama-cpp-prefix = {
          description = "Load the llama.cpp model and restore the cached pi prompt prefix";
          after = [ "llama-cpp.service" ];
          partOf = [ "llama-cpp.service" ];
          wantedBy = [ "llama-cpp.service" ];
          path = [
            pkgs.curl
            pkgs.jq
          ];
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = "10min";
          };
          script = ''
            curl -s --max-time 10 -X POST ${api}/models/load \
              -H 'Content-Type: application/json' -d '${modelBody}' || true
            for _ in $(seq 120); do
              status=$(curl -s --max-time 5 ${api}/models \
                | jq -r --arg m '${model}' '.data[] | select(.id == $m) | .status.value' || true)
              [ "$status" = loaded ] && break
              sleep 5
            done
            curl -s --max-time 60 -X POST '${api}/slots/0?action=restore&model=${model}' \
              -H 'Content-Type: application/json' \
              -d '${
                builtins.toJSON {
                  inherit model;
                  filename = prefixFile;
                }
              }' || true
          '';
        };

        powerManagement.powerDownCommands = ''
          ${pkgs.curl}/bin/curl -s --max-time 10 -X POST ${api}/models/unload \
            -H 'Content-Type: application/json' -d '${modelBody}' || true
        '';

        powerManagement.resumeCommands = ''
          ${pkgs.systemd}/bin/systemctl start --no-block llama-cpp-prefix.service
        '';
      };
    };

  flake.homeModules.llamaCpp =
    { pkgs, pkgs-unstable, ... }:
    let
      captureProxy = pkgs.writeText "pi-capture-proxy.py" ''
        import http.server, os, sys, urllib.error, urllib.request

        out = sys.argv[1]

        class Handler(http.server.BaseHTTPRequestHandler):
            def reply(self, code, data, ctype="application/json"):
                self.send_response(code)
                self.send_header("Content-Type", ctype)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def do_GET(self):
                try:
                    r = urllib.request.urlopen("${api}" + self.path, timeout=30)
                    self.reply(r.status, r.read(), r.headers.get("Content-Type", "application/json"))
                except urllib.error.HTTPError as e:
                    self.reply(e.code, e.read())

            def do_POST(self):
                body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
                if "chat/completions" in self.path:
                    path = os.path.join(out, "req.json")
                    if not os.path.exists(path):
                        open(path, "wb").write(body)
                self.reply(400, b'{"error":{"message":"captured"}}')

            def log_message(self, *args):
                pass

        http.server.ThreadingHTTPServer(("127.0.0.1", 18086), Handler).serve_forever()
      '';

      llamaWarmPi = pkgs.writeShellApplication {
        name = "llama-warm-pi";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.python3
          pkgs.coreutils
        ];
        text = ''
          tmp=$(mktemp -d)
          proxy=""
          cleanup() {
            [ -n "$proxy" ] && kill "$proxy" 2>/dev/null
            rm -rf "$tmp"
          }
          trap cleanup EXIT

          command cp -rs "$HOME/.pi/agent" "$tmp/agent"
          rm "$tmp/agent/auth.json"
          jq '."llama.cpp".env.LLAMA_BASE_URL = "http://127.0.0.1:18086"' \
            "$HOME/.pi/agent/auth.json" > "$tmp/agent/auth.json"
          mkdir "$tmp/bare" "$tmp/proj"
          echo "# project" > "$tmp/proj/AGENTS.md"

          capture() {
            mkdir "$tmp/cap"
            python3 ${captureProxy} "$tmp/cap" &
            proxy=$!
            sleep 1
            (cd "$1" && PI_CODING_AGENT_DIR="$tmp/agent" timeout 120 \
              pi -p --provider llama.cpp --model '${model}' hi </dev/null >/dev/null 2>&1) || true
            kill "$proxy"
            proxy=""
            mv "$tmp/cap/req.json" "$2"
            rmdir "$tmp/cap"
          }

          tokens() {
            jq --arg m '${model}' '{model: $m, messages, tools}' "$1" \
              | curl -sf '${api}/apply-template?model=${model}' -H 'Content-Type: application/json' -d @- \
              | jq --arg m '${model}' '{model: $m, content: .prompt}' \
              | curl -sf '${api}/tokenize?model=${model}' -H 'Content-Type: application/json' -d @- \
              | jq -c .tokens
          }

          echo "Capturing the pi prompt..."
          capture "$tmp/bare" "$tmp/bare.json"
          capture "$tmp/proj" "$tmp/proj.json"
          tokens "$tmp/bare.json" > "$tmp/bare.tok"
          tokens "$tmp/proj.json" > "$tmp/proj.tok"

          jq -n --arg m '${model}' --slurpfile a "$tmp/bare.tok" --slurpfile b "$tmp/proj.tok" '
            ($a[0]) as $x | ($b[0]) as $y
            | ([range(0; [($x | length), ($y | length)] | min)] | map(select($x[.] != $y[.])) | first) as $n
            | {model: $m, prompt: $x[0:$n], n_predict: 0, cache_prompt: true}
          ' > "$tmp/prefix.json"

          echo "Processing $(jq '.prompt | length' "$tmp/prefix.json") prefix tokens, this takes several minutes..."
          curl -sf '${api}/completion' -H 'Content-Type: application/json' -d @"$tmp/prefix.json" \
            | jq -r '"Done in \(.timings.prompt_ms / 1000 | floor) s"'
          curl -sf -X POST '${api}/slots/0?action=save&model=${model}' -H 'Content-Type: application/json' \
            -d '${
              builtins.toJSON {
                inherit model;
                filename = prefixFile;
              }
            }' | jq -r '"Saved \(.n_saved) tokens to ${prefixFile}"'
        '';
      };
    in
    {
      home.packages = [
        llamaWarmPi
        (pkgs-unstable.llama-cpp.override {
          blasSupport = true;
          vulkanSupport = true;
          cudaSupport = false;
          rocmSupport = false;
          metalSupport = false;
          openclSupport = false;
        })
      ];
    };
}
