#!/bin/bash

available() {
    command -v "$1" >/dev/null 2>&1
}

git_clone_specific_commit() {
    local repo_url="$1"
    local commit="$2"
    local default_branch="${3:-master}"
    local repo_name="${repo_url##*/}"
    local strategy="${LLAMA_STRATEGY:-merge}"

    # Merge/rebase mode: LLAMA_MERGE is set, clone default branch, apply PR on top
    if [[ "$commit" == refs/pull/* && -n "${LLAMA_MERGE:-}" ]]; then
        echo "==> Cloning default branch '$default_branch' and applying PR ref $commit"
        git clone --depth 1 "$repo_url" "$repo_name"
        cd "$repo_name" || return 1

        # Fetch the PR ref
        if ! git fetch origin "$commit" 2>&1; then
            echo "ERROR: Failed to fetch PR ref $commit from $repo_url"
            echo "The PR may not exist, be closed, or the repo may be unreachable."
            echo "Build aborted."
            return 1
        fi

        local applied=false

        # Try merge or rebase the PR on top of the default branch
        case "$strategy" in
            merge)
                if git merge FETCH_HEAD --no-edit 2>&1; then
                    applied=true
                fi
                ;;
            rebase)
                if git rebase FETCH_HEAD 2>&1; then
                    applied=true
                fi
                ;;
            *)
                echo "ERROR: Unknown LLAMA_STRATEGY='$strategy' (expected 'merge' or 'rebase')"
                return 1
                ;;
        esac

        # Fall back to PR branch checkout if merge/rebase failed
        if [ "$applied" = false ]; then
            echo ""
            echo "WARNING: ${strategy^^} conflict when applying PR $commit on top of '$default_branch'"
            echo "Falling back to PR branch checkout (PR head only, no merge with master)."
            git reset --hard FETCH_HEAD 2>&1
        fi

        git submodule update --init --recursive
        return 0
    fi

    # Checkout mode: shallow clone the ref directly (PR head, branch, or default)
    git clone --depth 1 "$repo_url" "$repo_name"
    cd "$repo_name" || return 1

    # If checking out the default branch, we already have it
    if [ "$commit" != "$default_branch" ]; then
        if ! git fetch origin "$commit" 2>&1; then
            git checkout "$commit" 2>&1
        else
            git checkout FETCH_HEAD 2>&1
        fi
    fi
    git submodule update --init --recursive
}

cmake_check_warnings() {
    awk -v rc=0 '/CMake Warning:/ { rc=1 } 1; END {exit rc}'
}
