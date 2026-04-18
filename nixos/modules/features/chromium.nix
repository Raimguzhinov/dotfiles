{ ... }:
{
  flake.homeModules.chromium =
    { config, pkgs, ... }:
    {
      programs.chromium = {
        enable = true;
        package = pkgs.chromium;
        commandLineArgs = [
          # Use PipeWire camera portal (xdg-desktop-portal) instead of V4L2
          "--enable-features=WebRtcPipeWireCapturer"
        ];
        extensions = [
          { id = "lmeddoobegbaiopohmpmmobpnpjifpii"; } # Open in Firefox™ Browser
          { id = "kkhfnlkhiapbiehimabddjbimfaijdhk"; } # Gopass Bridge
        ];
      };

      home.file.".config/chromium/NativeMessagingHosts/com.justwatch.gopass.json".text = ''
        {
          "name": "com.justwatch.gopass",
          "description": "Gopass wrapper to search and return passwords",
          "path": "${config.home.homeDirectory}/.config/gopass/gopass_wrapper.sh",
          "type": "stdio",
          "allowed_origins": [
            "chrome-extension://kkhfnlkhiapbiehimabddjbimfaijdhk/"
          ]
        }
      '';

      home.file.".config/chromium/NativeMessagingHosts/com.add0n.node.json".text = ''
        {
          "name": "com.add0n.node",
          "description": "Node Host for Native Messaging",
          "path": "${config.home.homeDirectory}/.config/com.add0n.node/run.sh",
          "type": "stdio",
          "allowed_origins": [
            "chrome-extension://lmeddoobegbaiopohmpmmobpnpjifpii/",
            "chrome-extension://mjoebkkejejidnkfdekpbooceogbapnf/",
            "chrome-extension://amojccmdnkdlcjcplmkijeenigbhfbpd/",
            "chrome-extension://looohpideggedchhpphemdmppnmdkgfd/",
            "chrome-extension://ocnfecjfebnllnapjjoncgjnnkfmobjc/",
            "chrome-extension://jgpghknlbaljigdhcjimjnkkjniiipmm/",
            "chrome-extension://bifmfjgpgndemajpeeoiopbeilbaifdo/",
            "chrome-extension://ihpiinojhnfhpdmmacgmpoonphhimkaj/",
            "chrome-extension://gkmonffckeeffppchajngpdakfppalfo/",
            "chrome-extension://kjoabfljeghcinlpjhdbdfbcflapkccm/",
            "chrome-extension://cehiomcamjpnfmemkmpjadaclohoibgo/",
            "chrome-extension://nfpgfobeckckemhmggkdfjkjaiikadnd/",
            "chrome-extension://bffjckjhidlcnenenacdahhpbacpgapo/",
            "chrome-extension://eaicplkoeceoelookkiaeekhodehdhde/",
            "chrome-extension://bhfenhhfpcpkknkahnlogooiodcofkjl/",
            "chrome-extension://mgmnomlncpmfgelhofilonnecmbdaoia/",
            "chrome-extension://oofmnabdpcibefadlibdpnnbglcehfpj/",
            "chrome-extension://lhplfipknbnglagbgbfogdaihdcekfga/",
            "chrome-extension://balknnpjeohaolphkfhghbaapifbokik/",
            "chrome-extension://hhalgjmpmjelidhhjldondajffjbcmcg/",
            "chrome-extension://jjlkfjglmelpbkgfeebcdipalggpapag/",
            "chrome-extension://bdlaolidgmapdilglbocpmbfipdpfjef/",
            "chrome-extension://noedpljikmfalclpadmnjbabbignpfge/",
            "chrome-extension://gmdcejkkcimnbfmicdpohgicekomipde/",
            "chrome-extension://dilpigogejfnnahbbmnpjmccammdaiom/",
            "chrome-extension://jfpmkcifglhenaihlnefaccjbmcmbigf/",
            "chrome-extension://cmjahocdpafkodabbojjaebogoigcipj/",
            "chrome-extension://dlobcokaeaiaihfebfhpdoongldphgkf/",
            "chrome-extension://fabccabfpmdadbhljpcmcbmepepfllnb/",
            "chrome-extension://enemdfoackoekaedijjmjlckkleokhih/",
            "chrome-extension://iajkcajifgglcaojccgiohphgjmoleia/",
            "chrome-extension://ldoihpohemnbokndocafmiblepbjeacb/",
            "chrome-extension://emlgnifoahkaeocfmafkpnfbijoioefh/",
            "chrome-extension://cglibgbhfapdcidmcpnbbekdanacjgkf/",
            "chrome-extension://hedcbilfmphgkpnokgcflaljgpecagfd/",
            "chrome-extension://knfbgpkbkfebddfbklfpgmdjgolnkkfl/",
            "chrome-extension://khgbdhkpcapllhgfekjegcinegfhjbmi/",
            "chrome-extension://honagjpkinogkppkapphkpdffnegagge/",
            "chrome-extension://ljealnphmlekclcdoeficainfegfjgkc/",
            "chrome-extension://babedbfkpnfmnopiagfocoelpfmpldkc/",
            "chrome-extension://cbdomccfnegbmmpfakfpnonihdnfmonn/",
            "chrome-extension://ojmcfmboidiokgkgmilnmjnjkdbgakpn/",
            "chrome-extension://ghnflaojldkldmjdiocenfmeonemoogb/",
            "chrome-extension://ajgodcbbfnpdbopgmfcgdbfhabbnilbp/",
            "chrome-extension://eokgbaidifojhfknoiicmnffiaakelpm/",
            "chrome-extension://ncemgeeikbbjoojolbihkpcoiomidhfi/",
            "chrome-extension://icfhhpfimihpdgglmdlnmpaadfeaacbk/",
            "chrome-extension://hjfcjapkfahlmlefedkkpbbkeddpnnlc/",
            "chrome-extension://hkjcboammhlecfomgabecgoppnncbhjp/",
            "chrome-extension://ijhhpgjhnfoalaedkmgpbehokefplfni/",
            "chrome-extension://ciphgjdgpkhlngiadnpebblpcjcoabcp/",
            "chrome-extension://hmkmedgmocnmelekbdpogdpednpfjdne/",
            "chrome-extension://apldpaggahklckhcoaoifaolmifdnecg/"
          ]
        }
      '';
      home.file.".config/com.add0n.node/run.sh" = {
        source = pkgs.writeShellScript "native-client-runner" ''
          ${pkgs.nodejs}/bin/node "$(dirname "$0")/host.js"
        '';
        executable = true;
      };
      home.file.".config/com.add0n.node/host.js".text = ''
        'use strict';

        function lazyRequire(lib, name) {
          if (!name) {
            name = lib;
          }
          global.__defineGetter__(name, function() {
            return require(lib);
          });
          return global[name];
        }

        const spawn = require('child_process').spawn;
        const fs = lazyRequire('fs');
        const os = lazyRequire('os');
        const path = lazyRequire('path');

        let files = [];
        const sprocess = [];

        const config = {
          version: '1.0.6'
        };
        // closing node when parent process is killed
        process.stdin.resume();
        process.stdin.on('end', () => {
          files.forEach(file => {
            try {
              fs.unlink(file);
            }
            catch (e) {}
          });
          sprocess.forEach(ps => ps.kill());

          process.exit();
        });

        // process.on('uncaughtException', e => console.error(e));

        function observe(msg, push, done) {
          if (msg.cmd === 'version') {
            push({
              version: config.version
            });
            done();
          }
          if (msg.cmd === 'spec') {
            push({
              version: config.version,
              env: process.env,
              separator: path.sep,
              tmpdir: os.tmpdir()
            });
            done();
          }
          else if (msg.cmd === 'echo') {
            push(msg);
            done();
          }
          else if (msg.cmd === 'spawn') {
            if (msg.env) {
              msg.env.forEach(n => process.env.PATH += path.delimiter + n);
            }
            const p = Array.isArray(msg.command) ? path.join(...msg.command) : msg.command;
            const sp = spawn(p, msg.arguments || [], Object.assign({env: process.env}, msg.properties));

            if (msg.kill) {
              sprocess.push(sp);
            }

            sp.stdout.on('data', stdout => push({stdout}));
            sp.stderr.on('data', stderr => push({stderr}));
            sp.on('close', code => {
              push({
                cmd: msg.cmd,
                code
              });
              done();
            });
            sp.on('error', e => {
              push({
                code: 1007,
                error: e.message
              });
              done();
            });
            if (Array.isArray(msg.stdin)) {
              msg.stdin.forEach(c => sp.stdin.write(c));
              sp.stdin.end();
            }
          }
          else if (msg.cmd === 'clean-tmp') {
            files.forEach(file => {
              try {
                fs.unlink(file);
              }
              catch (e) {}
            });
            files = [];
            push({
              code: 0
            });
            done();
          }
          else if (msg.cmd === 'exec') {
            if (msg.env) {
              msg.env.forEach(n => process.env.PATH += path.delimiter + n);
            }
            const p = Array.isArray(msg.command) ? path.join(...msg.command) : msg.command;
            const sp = spawn(p, msg.arguments || [], Object.assign({
              env: process.env,
              detached: true
            }, msg.properties));
            if (msg.kill) {
              sprocess.push(sp);
            }
            let stderr = ${"''"};
            let stdout = ${"''"};
            if (sp.stdout) {
              sp.stdout.on('data', data => stdout += data);
            }
            if (sp.stderr) {
              sp.stderr.on('data', data => stderr += data);
            }
            sp.on('close', code => {
              push({
                code,
                stderr,
                stdout
              });
              done();
            });
            if (sp.stdin) {
              if (Array.isArray(msg.stdin)) {
                msg.stdin.forEach(c => sp.stdin.write(c));
                sp.stdin.end();
              }
            }
            if (msg.unref) {
              sp.unref();
            }
          }
          else if (msg.cmd === 'env') {
            push({
              env: process.env
            });
            done();
          }
          // this is from openstyles/native-client
          else if ('script' in msg) {
            let close;
            const exception = e => {
              push({
                code: -1,
                type: 'exception',
                error: e.stack
              });
              close();
            };
            close = () => {
              process.removeListener('uncaughtException', exception);
              done();
              close = () => {};
            };
            process.addListener('uncaughtException', exception);

            const vm = require('vm');
            const sandbox = {
              version: config.version,
              env: process.env,
              push,
              close,
              setTimeout,
              args: msg.args,
              // only allow internal modules that extension already requested permission for
              require: name => (msg.permissions || []).indexOf(name) === -1 ? null : require(name)
            };
            const script = new vm.Script(msg.script);
            const context = vm.createContext(sandbox);
            script.runInContext(context);
          }
          else {
            let error = 'This version of the native client does not support "' + msg.cmd + '" command. Check for updates...';
            // Display warning about old unsupported commands
            if (['ifup', 'dir', 'save-data', 'net', 'copy', 'remove', 'move'].includes(msg.cmd)) {
              error = 'The "' + msg.cmd + '" command is no longer supported in this version of the native client. ' +
                'Downgrade to version 0.9.7 if your extension requires this command.';
            }
            push({
              error,
              cmd: msg.cmd,
              code: 1000
            });

            done();
          }
        }
        /* message passing */
        const nativeMessage = require('${config.home.homeDirectory}/.config/com.add0n.node/messaging');

        const input = new nativeMessage.Input();
        const transform = new nativeMessage.Transform(observe);
        const output = new nativeMessage.Output();

        process.stdin
          .pipe(input)
          .pipe(transform)
          .pipe(output)
          .pipe(process.stdout);
      '';
      home.file.".config/com.add0n.node/messaging.js".text = ''
        // chrome-native-messaging module
        //
        // Defines three Transform streams:
        //
        // - Input - transform native messages to JavaScript objects
        // - Output - transform JavaScript objects to native messages
        // - Transform - transform message objects to reply objects
        // - Debug - transform JavaScript objects to lines of JSON (for debugging, obviously)

        const stream = require('stream');
        const util = require('util');

        function Input() {
          stream.Transform.call(this);

          // Transform bytes...
          this._writableState.objectMode = false;
          // ...into objects.
          this._readableState.objectMode = true;

          // Unparsed data.
          this.buf = Buffer.alloc(0);
          // Parsed length.
          this.len = null;
        }

        util.inherits(Input, stream.Transform);

        Input.prototype._transform = function(chunk, encoding, done) {
          // Save this chunk.
          this.buf = Buffer.concat([this.buf, chunk]);

          const self = this;

          function parseBuf() {
            // Do we have a length yet?
            if (typeof self.len !== 'number') {
              // Nope. Do we have enough bytes for the length?
              if (self.buf.length >= 4) {
                // Yep. Parse the bytes.
                self.len = self.buf.readUInt32LE(0);
                // Remove the length bytes from the buffer.
                self.buf = self.buf.slice(4);
              }
            }

            // Do we have a length yet? (We may have just parsed it.)
            if (typeof self.len === 'number') {
              // Yep. Do we have enough bytes for the message?
              if (self.buf.length >= self.len) {
                // Yep. Slice off the bytes we need.
                const message = self.buf.slice(0, self.len);
                // Remove the bytes for the message from the buffer.
                self.buf = self.buf.slice(self.len);
                // Clear the length so we know we need to parse it again.
                self.len = null;
                // Parse the message bytes.
                const obj = JSON.parse(message.toString());
                // Enqueue it for reading.
                self.push(obj);
                // We could have more messages in the buffer so check again.
                parseBuf();
              }
            }
          }

          // Check for a parsable buffer (both length and message).
          parseBuf();

          // We're done.
          done();
        };

        function Output() {
          stream.Transform.call(this);

          this._writableState.objectMode = true;
          this._readableState.objectMode = false;
        }

        util.inherits(Output, stream.Transform);

        Output.prototype._transform = function(chunk, encoding, done) {
          const len = Buffer.alloc(4);
          const buf = Buffer.from(JSON.stringify(chunk), 'utf8');

          len.writeUInt32LE(buf.length, 0);

          this.push(len);
          this.push(buf);

          done();
        };

        function Transform(handler) {
          stream.Transform.call(this);

          this._writableState.objectMode = true;
          this._readableState.objectMode = true;

          this.handler = handler;
        }

        util.inherits(Transform, stream.Transform);

        Transform.prototype._transform = function(msg, encoding, done) {
          this.handler(msg, this.push.bind(this), done);
        };

        function Debug() {
          stream.Transform.call(this);

          this._writableState.objectMode = true;
          this._readableState.objectMode = false;
        }

        util.inherits(Debug, stream.Transform);

        Debug.prototype._transform = function(chunk, encoding, done) {
          this.push(JSON.stringify(chunk) + '\n');

          done();
        };

        exports.Input = Input;
        exports.Output = Output;
        exports.Transform = Transform;
        exports.Debug = Debug;
      '';

    };
}
