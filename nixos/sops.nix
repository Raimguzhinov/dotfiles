{ config, ... }:

{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";

    gnupg.home = "${config.home.homeDirectory}/.gnupg";

    secrets.github_token = { };
    secrets."youtrack/url" = { };
    secrets."youtrack/token" = { };
    secrets."git/private" = { };
  };

  programs.git.includes = [{ path = config.sops.secrets."git/private".path; }];

  programs.zsh.initContent = ''
    export GITHUB_TOKEN=$(cat ${config.sops.secrets.github_token.path})
    export YOUTRACK_URL=$(cat ${config.sops.secrets."youtrack/url".path})
    export YOUTRACK_TOKEN=$(cat ${config.sops.secrets."youtrack/token".path})
  '';
}
