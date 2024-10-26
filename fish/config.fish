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
#alias gitree='rg --ignore --hidden --files --glob '!.git/' "$@" | tree --fromfile -a'
alias vsrun='brew services start code-server && open ~/Applications/Chrome\ Apps.localized/VS\ Code.app/'
alias vsstop='brew services stop code-server'
alias e='exit'
alias rr='yazi'
alias docker:last='docker ps -lq'
alias pass='gopass'
