# .zshrc léger, sans oh-my-zsh (démarrage rapide, peu de RAM)

# Historique
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# Complétion
autoload -Uz compinit && compinit -C -d ~/.cache/zcompdump
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Touches (mode emacs, Home/End/Suppr)
bindkey -e
bindkey '^[[H' beginning-of-line '^[[F' end-of-line '^[[3~' delete-char

# Prompt façon robbyrussell: ➜ dossier git:(branche)
setopt PROMPT_SUBST
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{blue}git:(%F{red}%b%F{blue})%f'
precmd() { vcs_info }
PROMPT='%(?:%F{green}➜:%F{red}➜) %F{cyan}%c%f${vcs_info_msg_0_} '

# Outils
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
for f in /usr/share/fzf/key-bindings.zsh /usr/share/fzf/completion.zsh; do
    [ -r "$f" ] && . "$f"
done
[ -r ~/.config/zsh/aliases ] && . ~/.config/zsh/aliases

# Plugins (la coloration syntaxique doit rester en dernier)
[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && . /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && . /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
