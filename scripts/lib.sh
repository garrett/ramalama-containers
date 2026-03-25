#!/bin/bash
#
# lib.sh - Helper functions for building llama.cpp containers
#

# Check if a command is available
available() {
    command -v "$1" >/dev/null 2>&1
}

# Clone a specific commit from a git repository
# Args: $1 = repository URL, $2 = commit hash/branch
git_clone_specific_commit() {
    local repo_url="$1"
    local commit="$2"
    local repo_name="${repo_url##*/}"
    
    git clone --depth 1 --revision "$commit" "$repo_url" "$repo_name"
    cd "$repo_name" || return 1
    git submodule update --init --recursive
}

# Check for CMake warnings and fail if found
cmake_check_warnings() {
    awk -v rc=0 '/CMake Warning:/ { rc=1 } 1; END {exit rc}'
}