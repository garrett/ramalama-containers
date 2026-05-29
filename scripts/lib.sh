#!/bin/bash

available() {
    command -v "$1" >/dev/null 2>&1
}

git_clone_specific_commit() {
    local repo_url="$1"
    local commit="$2"
    local repo_name="${repo_url##*/}"

    # Resolve PR refs to a commit SHA so shallow clone works cleanly
    if [[ "$commit" == refs/pull/* ]]; then
        commit=$(git ls-remote "$repo_url" "$commit" | cut -f1)
    fi

    git clone --depth 1 --revision "$commit" "$repo_url" "$repo_name"
    cd "$repo_name" || return 1
    git submodule update --init --recursive
}

cmake_check_warnings() {
    awk -v rc=0 '/CMake Warning:/ { rc=1 } 1; END {exit rc}'
}
