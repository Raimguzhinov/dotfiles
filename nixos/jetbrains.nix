{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # https://3.jetbra.in/
    (jetbrains.goland.override {
      vmopts = ''
        -Xms128m
        -Xmx4096m
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
            
        -Dawt.toolkit.name=WLToolkit-javaagent:/home/dias/dotfiles/SpecificDots/JetBrains/ja-netfilter.jar=jetbrains
        -javaagent:/home/dias/dotfiles/SpecificDots/JetBrains/ja-netfilter.jar=jetbrains
        -Dawt.toolkit.name=WLToolkit
      '';
    })
    (jetbrains.pycharm.override {
      vmopts = ''
        -Xms128m
        -Xmx4096m
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

        -javaagent:/home/dias/dotfiles/SpecificDots/JetBrains/ja-netfilter.jar=jetbrains
      '';
    })
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
}
