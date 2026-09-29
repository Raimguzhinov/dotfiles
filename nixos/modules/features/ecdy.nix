{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      packages.ecdy = inputs.ecdy.packages.${system}.default;
    };

  flake.homeModules.ecdy = {
    imports = [ inputs.ecdy.homeManagerModules.default ];

    programs.ecdy = {
      enable = true;
      settings = {
        default_agent = "pi";
        agents.pi.command = [ "pi-acp" ];
      };
    };
  };
}
