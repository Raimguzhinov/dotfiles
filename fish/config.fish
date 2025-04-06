if status is-interactive
    # Commands to run in interactive sessions can go here
end
alias getip="wget -qO - eth0.me"
alias pbcat="wl-copy <"
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
#alias gitree='rg --ignore --hidden --files --glob "!.git/" "$@" | tree --fromfile -a'
alias vsrun='brew services start code-server && open ~/Applications/Chrome\ Apps.localized/VS\ Code.app/'
alias vsstop='brew services stop code-server'
alias e='exit'
alias docker:last='docker ps -lq'
alias pass='gopass'
alias la='leai'
alias sudo='sudo -E'
set -gx EDITOR nvim
set -gx GIT_EDITOR vim.tiny
set -gx GOROOT /home/dias/sdk/go1.20
set -gx PATH $PATH $GOROOT/bin
set -gx GOPATH $HOME/go
set -gx PATH $PATH $GOPATH/bin
set -U fish_key_bindings fish_default_key_bindings
oh-my-posh init fish --config $HOME/.config/oh-my-posh/themes/amro.omp.json | source
zoxide init --cmd cd fish | source
thefuck --alias | source 

# Generated for envman. Do not edit.
test -s /home/dias/config/envman/load.fish; and source /home/dias/.config/envman/load.fish
