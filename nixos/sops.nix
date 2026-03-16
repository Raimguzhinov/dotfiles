{ config, ... }:

{
  systemd.user.services.sops-nix = {
    Unit.After = [ "gpg-agent.service" ];
    Unit.Wants = [ "gpg-agent.service" ];
    Service.Restart = "on-failure";
    Service.RestartSec = "3s";
    Service.StartLimitBurst = 5;
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";

    gnupg.home = "${config.home.homeDirectory}/.gnupg";

    secrets.github_token = { };
    secrets."youtrack/url" = { };
    secrets."youtrack/token" = { };
    secrets."git/github" = { };
    secrets."git/gitlab_work" = { };
    secrets."product/services_root" = { };
    secrets."pass_store/clone_cmd" = { };
  };

  programs.git.includes = [
    {
      path = config.sops.secrets."git/github".path;
    }
    {
      condition = "gitdir:~/Work/";
      path = config.sops.secrets."git/gitlab_work".path;
    }
  ];

  programs.zsh.initContent = ''
    _sops_load_secrets() {
      if [[ -z "$SOPS_SECRETS_LOADED" && -f ${config.sops.secrets.github_token.path} ]]; then
        export GITHUB_TOKEN=$(cat ${config.sops.secrets.github_token.path} 2> /dev/null)
        export YOUTRACK_URL=$(cat ${config.sops.secrets."youtrack/url".path} 2> /dev/null)
        export YOUTRACK_TOKEN=$(cat ${config.sops.secrets."youtrack/token".path} 2> /dev/null)
        export SOPS_SECRETS_LOADED=1
      fi
    }
    add-zsh-hook precmd _sops_load_secrets

    # Post-install reminder until password-store is cloned
    if [[ ! -d ~/.password-store && -f ${config.sops.secrets."pass_store/clone_cmd".path} ]]; then
      echo "Клонировать хранилище паролей:"
      echo "  $(cat ${config.sops.secrets."pass_store/clone_cmd".path})"
    fi
  '';
}
