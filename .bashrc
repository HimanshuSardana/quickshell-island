#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias c=clear
alias ssh='kitty +kitten ssh'
PS1='[\u@\h \W]\$ '
export EDITOR=nvim
export VISUAL=nvim
export PATH="$HOME/.local/bin:$PATH"


# Pi
export PATH="/home/himanshu/.local/share/pi-node/node-v22.23.2-linux-x64/bin:$PATH"
