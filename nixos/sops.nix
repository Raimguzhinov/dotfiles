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

    secrets."youtrack/url" = { };
    secrets."youtrack/token" = { };
    secrets."git/github_token" = { };
    secrets."git/github_user" = {
      path = "${config.home.homeDirectory}/.config/git/identities/github_user";
      mode = "0644";
    };
    secrets."git/gitlab_work_user" = {
      path = "${config.home.homeDirectory}/.config/git/identities/gitlab_work_user";
      mode = "0644";
    };
    secrets."git/gitlab_work_url" = {
      path = "${config.home.homeDirectory}/.config/git/identities/gitlab_work_url";
      mode = "0644";
    };
    secrets."product/services_root" = { };
    secrets."pass_store/clone_cmd" = { };
    secrets."work_ai/litellm_url" = { };
    secrets."work_ai/litellm_api_key" = { };
    secrets."work_ai/mcp_sse_url" = { };
  };

  programs.zsh.initContent = ''
    _sops_load_secrets() {
      if [[ -f ${config.sops.secrets."git/github_token".path} ]]; then
        export GITHUB_TOKEN=$(cat ${config.sops.secrets."git/github_token".path} 2> /dev/null)
      fi
      if [[ -f ${config.sops.secrets."youtrack/url".path} && -f ${
        config.sops.secrets."youtrack/token".path
      } ]]; then
        export YOUTRACK_URL=$(cat ${config.sops.secrets."youtrack/url".path} 2> /dev/null)
        export YOUTRACK_TOKEN=$(cat ${config.sops.secrets."youtrack/token".path} 2> /dev/null)
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
