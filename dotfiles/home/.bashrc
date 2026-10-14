# .bashrc

# Claude Code et binaires utilisateur (aussi pour les shells non interactifs, ex: ssh)
export PATH="$HOME/.local/bin:$PATH"

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
