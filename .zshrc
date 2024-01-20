# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

eval "$(zoxide init zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$HOME/nvm.sh" ] && \. "$HOME/nvm.sh"
[ -s "$HOME/bash_completion" ] && \. "$HOME/bash_completion"

export VISUAL=nvim;
export EDITOR=nvim;

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/Users/r0ot/.oh-my-zsh"
export LC_ALL='en_US.UTF-8'
export LC_ALL='ru_RU.UTF-8'

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes

# ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_THEME="spaceship"
ZSH_TMUX_AUTOSTART='true'

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=( git sudo web-search copypath copybuffer dirhistory history macos zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases

alias zshconfig="nvim ~/.zshrc"
alias ohmyzsh="nvim ~/.oh-my-zsh"
alias python="python3"
alias xcopy="xsel --clipboard --input"
alias xcat="xsel --clipboard --input <"
alias xpaste="xsel --clipboard --output"
alias getip="wget -qO - eth0.me"
alias pbcat="pbcopy <"
alias now='date +"%T"'
alias nowtime=now
alias nowdate='date +"%d-%m-%Y"'
alias rm='rm -i'
alias cd..='cd ..'
alias cd...='cd ../../'
alias cd....='cd ../../../'
alias cd.....='cd ../../../../'
alias cd-='cd -'
alias clr='clear'
alias cat='bat -p -P'
alias g++='g++ -std=c++20'
alias c+='clang++ -std=c++20 -O2'
alias принц='spotify play artist V$XV PRiNCE'
alias скрип='spotify play artist скриптонит'
alias gitree='rg --ignore --hidden --files --glob '!.git/' "$@" | tree --fromfile -a'
alias vsrun='brew services start code-server && open ~/Applications/Chrome\ Apps.localized/VS\ Code.app/'
alias vsstop='brew services stop code-server'
alias e='exit'
alias rr='ranger'
alias obs='cd && nvim +NvimTreeToggle /Users/r0ot/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/notes/.'
alias docker:last='docker ps -lq'
alias pass='gopass'

if [ -x "$(command -v colorls)" ]; then
    alias ls="colorls"
    alias la="colorls -al"
    alias l.="colorls -al"
fi

if [ -x "$(command -v exa)" ]; then
    alias ls="exa --icons -G -F --group"
    alias la="exa --long --icons -G -F --all --group"
    alias l.="exa --long --icons -G -F -d .* --all --group"
fi

docker:bash () {
  if [ $# != 1 ]; then
    docker exec -it `docker:last` bash
  else
    docker exec -it $1 bash
  fi
}

d:run () {
  if [ $# == 0 ]; then
    docker run -it -v `pwd`:/app -w /app --rm buildpack-deps:trusty bash
  elif [ $# == 1 ]; then
    docker run -it -v `pwd`:/app -w /app --rm $1 
  else
    docker run -it -v `pwd`:/app -w /app --rm $1 ${@:2}
  fi
}

mkcd ()
{
	mkdir -p -- "$1" && cd -P -- "$1"
}

lfcd () {
    tmp="$(mktemp)"
    lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir="$(cat "$tmp")"
        rm -f "$tmp"
        if [ -d "$dir" ]; then
            if [ "$dir" != "$(pwd)" ]; then
                cd "$dir"
            fi
        fi
    fi
}

cdf() {
    target=`osascript -e 'tell application "Finder" to if (count of Finder windows) > 0 then get POSIX path of (target of front Finder window as text)'`
    if [ "$target" != "" ]; then
        cd "$target"; pwd
    else
        echo 'No Finder window found' >&2
    fi
}

clangf() {
  if ls -1 *.cpp 2>/dev/null || ls -1 *.c 2>/dev/null || ls -1 src/*.cpp 2>/dev/null || ls -1 src/*.c 2>/dev/null; then
    cp ~/dotfiles/.clang-format .
    cp ~/dotfiles/.clang-tidy .
    echo "Копирование .clang-format завершено."
  else
    echo "Файлы *.cpp, *.c или src/*.cpp не найдены в текущем каталоге."
  fi
}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# source /Users/r0ot/.config/broot/launcher/bash/br
export PATH="/usr/local/sbin:$PATH"

# eval $(thefuck --alias)

export LF_ICONS="\
tw=:\
st=:\
ow=:\
dt=:\
di=:\
fi=:\
ln=:\
or=:\
ex=:\
*.c=:\
*.cc=:\
*.clj=:\
*.coffee=:\
*.cpp=:\
*.css=:\
*.d=:\
*.dart=:\
*.erl=:\
*.exs=:\
*.fs=:\
*.go=:\
*.h=:\
*.hh=:\
*.hpp=:\
*.hs=:\
*.html=:\
*.java=:\
*.jl=:\
*.js=:\
*.json=:\
*.lua=:\
*.md=:\
*.php=:\
*.pl=:\
*.pro=:\
*.py=:\
*.rb=:\
*.rs=:\
*.scala=:\
*.ts=:\
*.vim=:\
*.cmd=:\
*.ps1=:\
*.sh=:\
*.bash=:\
*.zsh=:\
*.fish=:\
*.tar=:\
*.tgz=:\
*.arc=:\
*.arj=:\
*.taz=:\
*.lha=:\
*.lz4=:\
*.lzh=:\
*.lzma=:\
*.tlz=:\
*.txz=:\
*.tzo=:\
*.t7z=:\
*.zip=:\
*.z=:\
*.dz=:\
*.gz=:\
*.lrz=:\
*.lz=:\
*.lzo=:\
*.xz=:\
*.zst=:\
*.tzst=:\
*.bz2=:\
*.bz=:\
*.tbz=:\
*.tbz2=:\
*.tz=:\
*.deb=:\
*.rpm=:\
*.jar=:\
*.war=:\
*.ear=:\
*.sar=:\
*.rar=:\
*.alz=:\
*.ace=:\
*.zoo=:\
*.cpio=:\
*.7z=:\
*.rz=:\
*.cab=:\
*.wim=:\
*.swm=:\
*.dwm=:\
*.esd=:\
*.jpg=:\
*.jpeg=:\
*.mjpg=:\
*.mjpeg=:\
*.gif=:\
*.bmp=:\
*.pbm=:\
*.pgm=:\
*.ppm=:\
*.tga=:\
*.xbm=:\
*.xpm=:\
*.tif=:\
*.tiff=:\
*.png=:\
*.svg=:\
*.svgz=:\
*.mng=:\
*.pcx=:\
*.mov=:\
*.mpg=:\
*.mpeg=:\
*.m2v=:\
*.mkv=:\
*.webm=:\
*.ogm=:\
*.mp4=:\
*.m4v=:\
*.mp4v=:\
*.vob=:\
*.qt=:\
*.nuv=:\
*.wmv=:\
*.asf=:\
*.rm=:\
*.rmvb=:\
*.flc=:\
*.avi=:\
*.fli=:\
*.flv=:\
*.gl=:\
*.dl=:\
*.xcf=:\
*.xwd=:\
*.yuv=:\
*.cgm=:\
*.emf=:\
*.ogv=:\
*.ogx=:\
*.aac=:\
*.au=:\
*.flac=:\
*.m4a=:\
*.mid=:\
*.midi=:\
*.mka=:\
*.mp3=:\
*.mpc=:\
*.ogg=:\
*.ra=:\
*.wav=:\
*.oga=:\
*.opus=:\
*.spx=:\
*.xspf=:\
*.pdf=:\
*.nix=:\
"

export PATH="/usr/local/opt/postgresql@16/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/postgresql@16/lib"
export CPPFLAGS="-I/usr/local/opt/postgresql@16/include"
export PKG_CONFIG_PATH="/usr/local/opt/postgresql@16/lib/pkgconfig"
export VK_CLIENT_SECRET=$(pass show dev.vk.com/apikey | head -n 1)
export OPENAI_API_KEY=$(pass show neuroapi.host/token)
export OPENAI_API_HOST="https://neuroapi.host"
# source /usr/local/opt/spaceship/spaceship.zsh

export PATH=$PATH:/Users/r0ot/.spicetify

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"
