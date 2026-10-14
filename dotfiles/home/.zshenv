export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim
# Le résolveur DNS intégré de Go échoue ("no such host") derrière le DNS NAT de VMware alors que
# la libc fonctionne: on force le résolveur libc pour tous les programmes Go (gh, lazygit, podman...)
export GODEBUG=netdns=cgo
