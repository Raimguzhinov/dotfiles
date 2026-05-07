{ ... }:
let
  makeJetbrainsPkgs =
    pkgs: pkgs-unstable:

    let
      # tar c -C nixos/modules/features jetbrains-agent/ | xz -9 | base64 -w76 > nixos/modules/features/jetbrains-agent.b64
      jetbrainsAgent =
        pkgs.runCommandLocal "jetbrains-agent"
          {
            nativeBuildInputs = [ pkgs.xz ];
          }
          ''
            mkdir -p $out
            base64 -d ${pkgs.writeText "agent.b64" (builtins.readFile ./jetbrains-agent.b64)} \
              | tar xJ --strip-components=1 -C $out
          '';

      commonVmopts =
        xmx: # e.g. "4096m" or "1024m"
        ''
          -Xms128m
          -Xmx${xmx}
          -XX:ReservedCodeCacheSize=512m
          -XX:+IgnoreUnrecognizedVMOptions
          -XX:+UseG1GC
          -XX:SoftRefLRUPolicyMSPerMB=50
          -XX:CICompilerCount=2
          -XX:+HeapDumpOnOutOfMemoryError
          -XX:-OmitStackTraceInFastThrow
          -ea
          -Dsun.io.useCanonCaches=false
          -Djdk.http.auth.tunneling.disabledSchemes=""
          -Djdk.attach.allowAttachSelf=true
          -Djdk.module.illegalAccess.silent=true
          -Dkotlinx.coroutines.debug=off
          -XX:ErrorFile=$USER_HOME/java_error_in_idea_%p.log
          -XX:HeapDumpPath=$USER_HOME/java_error_in_idea.hprof

          --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED
          --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED
        '';

      jaAgent =
        toolkit: # "auto", "WLToolkit", or "XToolkit"
        ''
          -javaagent:${jetbrainsAgent}/ja-netfilter.jar=jetbrains
          -Dawt.toolkit.name=${toolkit}
        '';

      mkIde =
        base: xmx:
        let
          auto = base.override { vmopts = commonVmopts xmx + jaAgent "auto"; };
          wl = base.override { vmopts = commonVmopts xmx + jaAgent "WLToolkit"; };
          x11 = base.override { vmopts = commonVmopts xmx + jaAgent "XToolkit"; };
        in
        {
          inherit auto wl x11;
        };

      golandPkgs = mkIde pkgs-unstable.jetbrains.goland "4096m";
      pycharmPkgs = mkIde pkgs-unstable.jetbrains.pycharm "4096m";
      ideaPkgs = mkIde pkgs-unstable.jetbrains.idea "4096m";
      clionPkgs = mkIde pkgs-unstable.jetbrains.clion "1024m";
      datagrip = mkIde pkgs-unstable.jetbrains.datagrip "1024m";
      phpstormPkgs = mkIde pkgs-unstable.jetbrains.phpstorm "1024m";
      riderPkgs = mkIde pkgs-unstable.jetbrains.rider "1024m";
      webstormPkgs = mkIde pkgs-unstable.jetbrains.webstorm "1024m";
    in
    {
      # Exposed as flake packages/apps — nix run 'github:Raimguzhinov/dotfiles?dir=nixos#<name>'
      goland = golandPkgs.auto;
      goland-wl = golandPkgs.wl;
      goland-x11 = golandPkgs.x11;
      pycharm = pycharmPkgs.auto;
      pycharm-wl = pycharmPkgs.wl;
      pycharm-x11 = pycharmPkgs.x11;
      idea = ideaPkgs.auto;
      idea-wl = ideaPkgs.wl;
      idea-x11 = ideaPkgs.x11;
      clion = clionPkgs.auto;
      clion-wl = clionPkgs.wl;
      clion-x11 = clionPkgs.x11;
      datagrip = datagrip.auto;
      datagrip-wl = datagrip.wl;
      datagrip-x11 = datagrip.x11;
      phpstorm = phpstormPkgs.auto;
      phpstorm-wl = phpstormPkgs.wl;
      phpstorm-x11 = phpstormPkgs.x11;
      rider = riderPkgs.auto;
      rider-wl = riderPkgs.wl;
      rider-x11 = riderPkgs.x11;
      webstorm = webstormPkgs.auto;
      webstorm-wl = webstormPkgs.wl;
      webstorm-x11 = webstormPkgs.x11;
    };
in
{
  perSystem =
    { pkgs, pkgs-jetbrains, ... }:
    {
      packages = makeJetbrainsPkgs pkgs pkgs-jetbrains;
    };

  flake.homeModules.jetbrains =
    { pkgs, pkgs-jetbrains, ... }:
    let
      jbPkgs = makeJetbrainsPkgs pkgs pkgs-jetbrains;
    in
    {
      home.packages = [
        jbPkgs.goland-wl
        jbPkgs.pycharm-wl
      ];
      home.file.".ideavimrc".text = # vim
        ''
          " .ideavimrc is a configuration file for IdeaVim plugin. It uses
          "   the same commands as the original .vimrc configuration.
          " You can find a list of commands here: https://jb.gg/h38q75
          " Find more examples here: https://jb.gg/share-ideavimrc
          let mapleader = " "

          "" -- Suggested options --
          " Show a few lines of context around the cursor. Note that this makes the
          " text scroll if you mouse-click near the start or end of the window.
          set scrolloff=5
          set incsearch
          set ideajoin
          set idearefactormode=keep
          set ideamarks
          set number
          set relativenumber
          set clipboard^=unnamedplus
          set sneak

          " WhichKey
          set which-key
          " disable the timeout option
          set notimeout
          " increase the timeoutlen (default: 1000), don't add space around the equal sign
          set timeoutlen=5000
          let g:WhichKey_ShowVimActions = "true"

          " Don't use Ex mode, use Q for formatting.
          map Q gq
          vmap v V
          "inoremap jk <Esc>
          imap jk <Esc>

          map <leader>w :w<CR><Action>(eu.oakroot.GoImportTidy)
          map <leader>q :q<CR>
          map <leader>x <Action>(CloseContent)
          map <leader>+ <Action>(Run)
          map <leader>sv <Action>(SplitVertically)
          map <leader>sh <Action>(SplitHorizontally)
          map <C-o> <Action>(Back)
          map <C-i> <Action>(Forward)

          " Search
          map <leader>fa <Action>(SearchEverywhere)
          map <leader>ff <Action>(GotoFile)
          map <leader>fb <Action>(RecentFiles)
          map <leader>fz <Action>(Find)
          map <leader>fd <Action>(HelpDiagnosticTools)
          map <leader>ft <Action>(ActivateTODOToolWindow)

          " IDE Tabs
          map <tab> <Action>(NextTab)
          map <S-tab> <Action>(PreviousTab)
          map <leader><tab> <Action>(Switcher)

          " Tests
          map <leader>to <Action>(GotoTest)
          map <leader>tr <Action>(RunClass)

          " Git
          map <leader>gg <Action>(CheckinProject)
          map <leader>gp <Action>(Vcs.UpdateProject)
          map <leader>gP <Action>(Vcs.Push)
          map <leader>gb <Action>(Annotate)

          " LSP
          map gd <Action>(GotoDeclaration)
          map gi <Action>(GotoImplementation)
          map gI <Action>(GotoSuperMethod)
          map gD <Action>(GotoTypeDeclaration)
          map <C-s> <Action>(ParameterInfo)
          imap <C-s> <Action>(ParameterInfo)
          map <leader>la <Action>(ShowIntentionActions)
          map <leader>li <Action>(ImplementMethods)
          map <leader>lg <Action>(Generate)

          " --- Enable IdeaVim plugins https://jb.gg/ideavim-plugins
          Plug 'preservim/nerdtree'
          map <leader>e :NERDTree<CR>
          Plug 'machakann/vim-highlightedyank'
          " Highlight copied text
          Plug 'tpope/vim-commentary'
          " Commentary plugin
          map <leader>/ :Commentary<CR>

          "" -- Map IDE actions to IdeaVim -- https://jb.gg/abva4t
          "" Map \r to the Reformat Code action
          "map \r <Action>(ReformatCode)
          map <leader>ra <Action>(RenameElement)
          map <leader>K <Action>(QuickJavaDoc)

          "" Debug
          map <leader>dr <Action>(Debug)
          map <leader>db <Action>(ToggleLineBreakpoint)
        '';
    };
}
