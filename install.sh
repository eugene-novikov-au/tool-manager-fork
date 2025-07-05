#!/usr/bin/env bash
#
# install.sh
#
# This script installs the Tool-Manager (tm).
# It checks for Bash version compatibility, clones the tm repository
# from GitHub (if not already installed or TM_HOME is not set),
# and adds a line to the user's ~/.bashrc to source the tm environment.
#

# --- Helper Functions ---
_err() {
  echo "[ERROR] [install.sh] $*" >&2
}

# --- Configuration ---
log_prefix="[tool-manager install] "
tm_git_repo="git@github.com:codemucker/tool-manager.git"
tm_home="$HOME/.tool-manager"
git_clone=1

# --- Bash Version Check ---
if [[ ! "$(echo "${BASH_VERSION:-0}" | grep -e '^[5-9]\..*' )" ]]; then
  _err "Incompatible bash version, expect bash version 5 or later, installed is '${BASH_VERSION:-0}'"
  _err "On mac you can install bash(5) or later via homebrew"
  exit 1
fi

# --- Determine Installation Path ---
if [[ -n "$TM_HOME" ]] && [[ -d "$TM_HOME" ]]; then
  tm_home="$TM_HOME"
fi
tm_bashrc="$tm_home/.bashrc"
home_bashrc="$HOME/.bashrc"

# --- Check if already installed ---
if [[ -f "$tm_bashrc" ]]; then
  echo "${log_prefix}tool-manager (tm) is already installed at '$tm_home'. Skipping install"
  echo "${log_prefix} - to update, run 'git pull' from within '$tm_home' or call 'tm-update-self'"
  git_clone=0
fi

# --- Clone repository ---
if [[ "$git_clone" == 1 ]]; then # String comparison for clarity, though numeric would work
  echo "${log_prefix}Cloning Tool Manager from '$tm_git_repo' to '$tm_home'..."
  git clone "$tm_git_repo" "$tm_home" || { _err "Failed to clone repository from '$tm_git_repo' to '$tm_home'. Aborting."; exit 1; }
  echo "${log_prefix}Clone successful."
fi

# --- Update user's .bashrc ---
# Check if tm_bashrc is already sourced.
# This pattern looks for a line starting with "source" followed by a path ending with "/tool-manager/.bashrc"
# or the specific $tm_bashrc path.
if grep -q "source \".*\/tool-manager\/\.bashrc\"" "$home_bashrc" || grep -qFx "source \"$tm_bashrc\"" "$home_bashrc"; then
    echo "${log_prefix}tool-manager already sourced in '$home_bashrc'. Skipping update"
else
  echo "${log_prefix}Adding tool-manager source to '$home_bashrc'..."
  cat << EOF >> "$home_bashrc"

# Added by Tool Manager install script ($tm_git_repo/install.sh) on $(date)
# Source Tool Manager environment if the file exists
if [[ -f "$tm_bashrc" ]]; then
  source "$tm_bashrc"
fi
EOF
  echo "${log_prefix}tool-manager (tm) installed and configured at '$tm_home'"
fi
