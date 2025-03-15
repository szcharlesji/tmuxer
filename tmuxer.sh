#!/usr/bin/env bash
#
# tmuxer - A tmux session manager with project directory navigation
# https://github.com/szcharles/tmuxer
#

VERSION="0.1.0"
CONFIG_FILE="$HOME/.tmuxer.conf"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'
BOLD='\033[1m'

# Display ASCII art banner
show_banner() {
    echo -e "${CYAN}"
    echo '████████╗███╗   ███╗██╗   ██╗██╗  ██╗███████╗██████╗ '
    echo '╚══██╔══╝████╗ ████║██║   ██║╚██╗██╔╝██╔════╝██╔══██╗'
    echo '   ██║   ██╔████╔██║██║   ██║ ╚███╔╝ █████╗  ██████╔╝'
    echo '   ██║   ██║╚██╔╝██║██║   ██║ ██╔██╗ ██╔══╝  ██╔══██╗'
    echo '   ██║   ██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗███████╗██║  ██║'
    echo '   ╚═╝   ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝'
    echo -e "${RESET}"
    echo -e "${YELLOW}${BOLD}tmuxer v${VERSION}${RESET} - A tmux session manager with project directory navigation"
    echo
}

# Display help message
show_help() {
    echo -e "${BOLD}USAGE:${RESET}"
    echo -e "  tmuxer [OPTIONS] [DIRECTORY]"
    echo -e "  tmr    [OPTIONS] [DIRECTORY]  (Shorthand alias)"
    echo
    echo -e "${BOLD}OPTIONS:${RESET}"
    echo -e "  -h, --help       Display this help message"
    echo -e "  -v, --version    Display version information"
    echo -e "  -l, --list       List existing tmux sessions"
    echo -e "  -k, --kill NAME  Kill the specified tmux session"
    echo -e "  -a, --attach     List and attach to existing tmux sessions"
    echo -e "  --code           Use code layout (single pane with editor)"
    echo -e "  --dev            Use dev layout (editor + terminal split)"
    echo -e "  --terminal       Use terminal layout (just terminal, no editor)"
    echo
    echo -e "${BOLD}CONFIGURATION:${RESET}"
    echo -e "  Configuration file: ${CONFIG_FILE}"
    echo -e "  Add project root directories to this file, one per line"
    echo
    echo -e "${BOLD}EXAMPLES:${RESET}"
    echo -e "  tmuxer              # Select directory and create/attach to session"
    echo -e "  tmuxer ~/projects   # Create/attach to session for specified directory"
    echo -e "  tmuxer --dev        # Create session with development layout"
    echo -e "  tmuxer -l           # List existing sessions"
    echo
}

# Display version information
show_version() {
    echo -e "tmuxer v${VERSION}"
}

# List existing tmux sessions
list_sessions() {
    echo -e "${BOLD}Existing tmux sessions:${RESET}"
    if ! tmux list-sessions 2>/dev/null; then
        echo -e "${YELLOW}No active tmux sessions${RESET}"
    fi
}

# Kill a specific tmux session
kill_session() {
    local session_name=$1
    if [[ -z "$session_name" ]]; then
        echo -e "${RED}Error: No session name provided${RESET}"
        return 1
    fi
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        tmux kill-session -t "$session_name"
        echo -e "${GREEN}Session '$session_name' killed${RESET}"
    else
        echo -e "${RED}Error: Session '$session_name' not found${RESET}"
        list_sessions
    fi
}

# Interactive session selector
select_session() {
    local session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --height=~30% --prompt="Select session: ")
    if [[ -n "$session" ]]; then
        if [[ -z "$TMUX" ]]; then
            tmux attach-session -t "$session"
        else
            tmux switch-client -t "$session"
        fi
        exit 0
    fi
}

# Select a directory from available options
select_directory() {
    local current_dir=$(pwd)
    
    # Create a temporary file to store our sorted directories
    local temp_file=$(mktemp)
    
    # Add current directory subdirectories first (will appear at the top in fzf with --tac)
    find "$current_dir" -mindepth 1 -maxdepth 1 -type d | sort -r >> "$temp_file"
    
    # Read additional directories from config file if it exists
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS= read -r dir || [[ -n "$dir" ]]; do
            # Skip comments and empty lines
            [[ "$dir" =~ ^#.*$ || -z "$dir" ]] && continue
            
            # Expand ~ if present
            dir="${dir/#\~/$HOME}"
            
            # Add subdirectories if the directory exists
            if [[ -d "$dir" ]]; then
                find "$dir" -mindepth 1 -maxdepth 1 -type d | sort -r >> "$temp_file"
            fi
        done < "$CONFIG_FILE"
    else
        # Create default config file if it doesn't exist
        echo -e "# tmuxer configuration file\n# Add project directories below, one per line\n~/projects\n" > "$CONFIG_FILE"
        echo -e "${YELLOW}Created default config file at $CONFIG_FILE${RESET}"
    fi
    
    # Finally add the current directory (will appear at the bottom in fzf with --tac)
    echo "$current_dir" >> "$temp_file"
    
    # Use fzf with the sorted list and custom preview
    echo -e "${CYAN}Select a project directory:${RESET}" >&2
    local selected=$(cat "$temp_file" | fzf --tac --height=~50% \
        --preview 'ls -la --color=always {}' \
        --preview-window=right:50% \
        --prompt="Project directory: ")
    
    # Clean up
    rm "$temp_file"
    
    echo "$selected"
}

# Create tmux session with the specified layout
create_tmux_session() {
    local selected=$1
    local layout=${2:-"dev"}  # Default layout is "dev"
    
    local selected_name=$(basename "$selected" | tr . _)
    local tmux_running=$(pgrep tmux)

    # If tmux is not running and we're not in a tmux session
    if [[ -z "$TMUX" ]] && [[ -z "$tmux_running" ]]; then
        case "$layout" in
            "code")
                tmux new-session -s "$selected_name" -c "$selected"
                tmux send-keys "nvim" C-m
                ;;
            "terminal")
                tmux new-session -s "$selected_name" -c "$selected"
                ;;
            *)  # "dev" layout (default)
                tmux new-session -s "$selected_name" -c "$selected"
                # Start nvim in the first pane
                tmux send-keys "nvim" C-m
                # Split vertically with a smaller height (20%)
                tmux split-window -v -p 20 -c "$selected"
                # Split the bottom pane horizontally
                tmux split-window -h -c "$selected"
                # Select the top pane (nvim)
                tmux select-pane -t 0
                ;;
        esac
        exit 0
    fi

    # If the session doesn't exist yet
    if ! tmux has-session -t="$selected_name" 2>/dev/null; then
        tmux new-session -ds "$selected_name" -c "$selected"
        
        case "$layout" in
            "code")
                tmux send-keys -t "$selected_name" "nvim" C-m
                ;;
            "terminal")
                # Just the terminal, no additional setup needed
                ;;
            *)  # "dev" layout (default)
                # Start nvim in the first pane
                tmux send-keys -t "$selected_name" "nvim" C-m
                # Split vertically with a smaller height (20%)
                tmux split-window -t "$selected_name" -v -p 20 -c "$selected"
                # Split the bottom pane horizontally
                tmux split-window -t "$selected_name" -h -c "$selected"
                # Select the top pane (nvim)
                tmux select-pane -t "$selected_name:0.0"
                ;;
        esac
    fi

    # Attach to the session
    if [[ -z "$TMUX" ]]; then
        tmux attach-session -t "$selected_name"
    else
        tmux switch-client -t "$selected_name"
    fi
}

# Check dependencies
check_dependencies() {
    if ! command -v tmux >/dev/null 2>&1; then
        echo -e "${RED}Error: tmux is not installed. Please install tmux first.${RESET}"
        exit 1
    fi
    
    if ! command -v fzf >/dev/null 2>&1; then
        echo -e "${RED}Error: fzf is not installed. Please install fzf first.${RESET}"
        exit 1
    fi
}

# Main function
main() {
    check_dependencies
    
    # Parse command line arguments
    local selected=""
    local layout="dev"
    
    # If no arguments provided, show the banner
    if [[ $# -eq 0 ]]; then
        show_banner
    fi
    
    # Process options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_banner
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -l|--list)
                list_sessions
                exit 0
                ;;
            -k|--kill)
                shift
                kill_session "$1"
                exit 0
                ;;
            -a|--attach)
                select_session
                exit 0
                ;;
            --code)
                layout="code"
                ;;
            --dev)
                layout="dev"
                ;;
            --terminal)
                layout="terminal"
                ;;
            -*)
                echo -e "${RED}Error: Unknown option $1${RESET}"
                show_help
                exit 1
                ;;
            *)
                selected="$1"
                ;;
        esac
        shift
    done
    
    # If no directory was provided, let user select one
    if [[ -z "$selected" ]]; then
        selected=$(select_directory)
    fi
    
    # Exit if no directory was selected
    if [[ -z "$selected" ]]; then
        exit 0
    fi
    
    # Create tmux session with the selected directory
    create_tmux_session "$selected" "$layout"
}

# Run the main function
main "$@"
