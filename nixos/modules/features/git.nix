{ ... }:
{
  flake.homeModules.git =
    { pkgs, username, ... }:
    {
      programs.git = {
        enable = true;
        lfs.enable = true;
        settings = {
          alias = {
            co = "checkout";
            br = "branch";
            ci = "commit";
            st = "status";
            hist = "log --oneline --decorate --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an> %G?'%Creset --abbrev-commit --date=relative";
            hist-full = "log --oneline --decorate --graph --all";
            bcommit = "!f(){ git commit -m \"$(git symbolic-ref --short HEAD) $*\"; }; f";
            pushall = "!f(){ git push -u origin \"$@\" || exit 1; git push mirror \"$@\" || echo \"mirror push failed\"; }; f";
          };
          init.defaultBranch = "main";
          core.editor = "nvim";
          pull.rebase = true;
          color.ui = true;
          rebase = {
            autoSquash = true;
            autoStash = true;
            updateRefs = true;
          };
          diff.tool = "meld";
          difftool.prompt = false;
          merge.tool = "meld";
          mergetool.prompt = false;
          commit.gpgsign = true;
          gpg.program = "${pkgs.gnupg}/bin/gpg";
          user.signingkey = "0x719B8382A9DBA991";
        };
        includes = [
          { path = "/home/${username}/.config/git/identities/gitlab_work_url"; }
          { path = "/home/${username}/.config/git/identities/github_user"; }
          {
            condition = "gitdir:~/Work/";
            path = "/home/${username}/.config/git/identities/gitlab_work_user";
          }
        ];
      };

      programs.delta = {
        enable = true;
        enableGitIntegration = true;
        options = {
          line-numbers = true;
          side-by-side = true;
        };
      };

      home.packages = [ pkgs.meld ];
    };
}
