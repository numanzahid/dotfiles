# Setup fzf
# ---------
if [[ ! "$PATH" == */home/numan/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/numan/.fzf/bin"
fi

eval "$(fzf --bash)"
