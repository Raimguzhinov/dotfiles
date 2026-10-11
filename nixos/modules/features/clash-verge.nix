{ ... }:
{
  flake.homeModules.clashVerge =
    { osConfig, ... }:
    let
      dataDir = "io.github.clash-verge-rev.clash-verge-rev";

      homeDomains = [ "+.nixos.netcraze.pro" ];
      homeResolvers = [
        "https://dns.google/dns-query"
        "https://cloudflare-dns.com/dns-query"
        "https://dns.adguard-dns.com/dns-query"
        "https://common.dot.dns.yandex.net/dns-query"
        "tls://dns.quad9.net"
      ];

      directRules = [ "UID,${toString osConfig.users.users.searx.uid},DIRECT" ];
    in
    {
      xdg.dataFile."${dataDir}/profiles/Script.js".text = /* javascript */ ''
        function main(config, profileName) {
          var domains = ${builtins.toJSON homeDomains};
          var resolvers = ${builtins.toJSON homeResolvers};
          var directRules = ${builtins.toJSON directRules};
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

          var rules = (config.rules || []).filter(function (rule) {
            return directRules.indexOf(rule) === -1;
          });
          config.rules = directRules.concat(rules);

          return config;
        }
      '';
    };
}
