{ ... }:
{
  flake.homeModules.clashVerge =
    { ... }:
    let
      dataDir = "io.github.clash-verge-rev.clash-verge-rev";

      homeDomains = [ "+.nixos.netcraze.pro" ];
      homeResolvers = [
        "192.168.1.129"
        "https://dns.google/dns-query"
        "https://cloudflare-dns.com/dns-query"
        "https://dns.adguard-dns.com/dns-query"
        "https://common.dot.dns.yandex.net/dns-query"
        "tls://dns.quad9.net"
      ];
    in
    {
      xdg.dataFile."${dataDir}/profiles/Script.js".text = /* javascript */ ''
        function main(config, profileName) {
          var domains = ${builtins.toJSON homeDomains};
          var resolvers = ${builtins.toJSON homeResolvers};
          var dns = config.dns || (config.dns = {});

          var policy = Object.assign({}, dns["nameserver-policy"]);
          var filter = (dns["fake-ip-filter"] || []).slice();

          domains.forEach(function (domain) {
            policy[domain] = resolvers;
            if (filter.indexOf(domain) === -1) {
              filter.unshift(domain);
            }
          });

          dns["nameserver-policy"] = policy;
          dns["fake-ip-filter"] = filter;

          return config;
        }
      '';
    };
}
