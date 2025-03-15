#!/usr/bin/env bash

if [[ $# -eq 1 ]]; then
    selected=$1
else
    current_dir=$(pwd)
    
    # Create a temporary file to store our sorted directories
    temp_file=$(mktemp)
    
    # Add current directory subdirectories first (will appear at the top in fzf with --tac)
    find "$current_dir" -mindepth 1 -maxdepth 1 -type d | sort -r >> "$temp_file"
    
    # Read additional directories from .tmuxer.conf if it exists
    config_file="$HOME/.tmuxer.conf"
    if [[ -f "$config_file" ]]; then
        while IFS= read -r dir || [[ -n "$dir" ]]; do
            # Skip comments and empty lines
            [[ "$dir" =~ ^#.*$ || -z "$dir" ]] && continue
            
            # Expand ~ if present
            dir="${dir/#\~/$HOME}"
            
            # Add subdirectories if the directory exists
            if [[ -d "$dir" ]]; then
                find "$dir" -mindepth 1 -maxdepth 1 -type d | sort -r >> "$temp_file"
            fi
        done < "$config_file"
    fi
    
    # Finally add the current directory (will appear at the bottom in fzf with --tac)
    echo "$current_dir" >> "$temp_file"
    
    # Use fzf with the sorted list
    selected=$(cat "$temp_file" | fzf --tac)
    
    # Clean up
    rm "$temp_file"
fi

if [[ -z $selected ]]; then
    exit 0
fi

selected_name=$(basename "$selected" | tr . _)
tmux_running=$(pgrep tmux)

if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
    tmux new-session -s $selected_name -c $selected
    # Start nvim in the first pane
    tmux send-keys "nvim" C-m
    # Split vertically with a smaller height (20%)
    tmux split-window -v -p 20 -c $selected
    # Split the bottom pane horizontally
    tmux split-window -h -c $selected
    # Select the top pane (nvim)
    tmux select-pane -t 0
    exit 0
fi

if ! tmux has-session -t=$selected_name 2> /dev/null; then
    tmux new-session -ds $selected_name -c $selected
    # Start nvim in the first pane
    tmux send-keys -t $selected_name "nvim" C-m
    # Split vertically with a smaller height (20%)
    tmux split-window -t $selected_name -v -p 20 -c $selected
    # Split the bottom pane horizontally
    tmux split-window -t $selected_name -h -c $selected
    # Select the top pane (nvim)
    tmux select-pane -t $selected_name:0.0
fi

tmux a
