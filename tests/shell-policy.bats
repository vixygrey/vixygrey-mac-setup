#!/usr/bin/env bats
# Behavioral contract for generated shell policy boundaries (#648, #651).

setup() {
    TEST_TMP="$(mktemp -d)"
    export GENERATED_ZPROFILE="$TEST_TMP/zprofile"
    export GENERATED_ZSHRC="$TEST_TMP/zshrc"
    export SHELL_TEST_HOME="$TEST_TMP/home"
    export SHELL_TEST_BIN="$TEST_TMP/bin"
    mkdir -p "$SHELL_TEST_HOME" "$SHELL_TEST_BIN"

    awk "/<<'ZPROFILE_CONF'/{f=1;next} /^ZPROFILE_CONF$/{f=0} f" \
        "$BATS_TEST_DIRNAME/../scripts/setup-dev-tools-mac.sh" > "$GENERATED_ZPROFILE"
    awk "/<<'MANAGED_ZSHRC'/{f=1;next} /^MANAGED_ZSHRC$/{f=0} f" \
        "$BATS_TEST_DIRNAME/../scripts/setup-dev-tools-mac.sh" > "$GENERATED_ZSHRC"

    printf '%s\n' \
        '#!/bin/sh' \
        'if [ "$1" = hook ] && [ "$2" = zsh ]; then' \
        '    printf "%s\\n" "export DIRENV_HOOK=loaded"' \
        'fi' > "$SHELL_TEST_BIN/direnv"
    chmod +x "$SHELL_TEST_BIN/direnv"
}

teardown() {
    rm -rf "$TEST_TMP"
}

@test "non-interactive shells retain runtime paths without human display policy (#648)" {
    run env -i \
        HOME="$SHELL_TEST_HOME" \
        PATH="$SHELL_TEST_BIN:/usr/bin:/bin" \
        zsh -dfc '
            function ulimit { print -r -- "$*" > "$HOME/ulimit-call"; }
            source "$1"
            print -r -- "editor=${EDITOR-unset}"
            print -r -- "visual=${VISUAL-unset}"
            print -r -- "pager=${PAGER-unset}"
            print -r -- "manpager=${MANPAGER-unset}"
            print -r -- "less=${LESS-unset}"
            print -r -- "gpg=${GPG_TTY-unset}"
        ' zsh "$GENERATED_ZPROFILE"

    [ "$status" -eq 0 ]
    [[ "$output" == *"editor=unset"* ]]
    [[ "$output" == *"visual=unset"* ]]
    [[ "$output" == *"pager=unset"* ]]
    [[ "$output" == *"manpager=unset"* ]]
    [[ "$output" == *"less=unset"* ]]
    [[ "$output" == *"gpg=unset"* ]]
    [ ! -e "$SHELL_TEST_HOME/ulimit-call" ]
}

@test "interactive human shells retain editor, pager, and descriptor settings (#648)" {
    run env -i \
        HOME="$SHELL_TEST_HOME" \
        PATH="$SHELL_TEST_BIN:/usr/bin:/bin" \
        zsh -dfic '
            function ulimit { print -r -- "$*" > "$HOME/ulimit-call"; }
            source "$1"
            print -r -- "editor=${EDITOR-unset}"
            print -r -- "visual=${VISUAL-unset}"
            print -r -- "pager=${PAGER-unset}"
            print -r -- "manpager=${MANPAGER-unset}"
            print -r -- "less=${LESS-unset}"
            print -r -- "gpg=${GPG_TTY-unset}"
        ' zsh "$GENERATED_ZPROFILE"

    [ "$status" -eq 0 ]
    [[ "$output" == *"editor=micro"* ]]
    [[ "$output" == *"visual=micro"* ]]
    [[ "$output" == *"pager=bat --style=plain --paging=always"* ]]
    [[ "$output" == *"manpager=sh -c 'col -bx | bat -l man -p'"* ]]
    [[ "$output" == *"less=-R -F -X -i -J -M -W -x4"* ]]
    [[ "$output" == *"gpg=unset"* ]]
    [ "$(< "$SHELL_TEST_HOME/ulimit-call")" = "-n 65536" ]
}

@test "direnv runs only in human interactive shells and never sets GPG_TTY without a terminal (#648, #651)" {
    run env -i \
        HOME="$SHELL_TEST_HOME" \
        PATH="$SHELL_TEST_BIN:/usr/bin:/bin" \
        zsh -dfic '
            source "$1"
            print -r -- "hook=${DIRENV_HOOK-unset}"
            print -r -- "gpg=${GPG_TTY-unset}"
        ' zsh "$GENERATED_ZSHRC"

    [ "$status" -eq 0 ]
    [[ "$output" == *"hook=loaded"* ]]
    [[ "$output" == *"gpg=unset"* ]]

    run env -i \
        AI_AGENT=1 \
        HOME="$SHELL_TEST_HOME" \
        PATH="$SHELL_TEST_BIN:/usr/bin:/bin" \
        zsh -dfic '
            source "$1"
            print -r -- "hook=${DIRENV_HOOK-unset}"
            print -r -- "gpg=${GPG_TTY-unset}"
        ' zsh "$GENERATED_ZSHRC"

    [ "$status" -eq 0 ]
    [[ "$output" == *"hook=unset"* ]]
    [[ "$output" == *"gpg=unset"* ]]

    run env -i \
        HOME="$SHELL_TEST_HOME" \
        PATH="$SHELL_TEST_BIN:/usr/bin:/bin" \
        zsh -dfc '
            source "$1"
            print -r -- "hook=${DIRENV_HOOK-unset}"
            print -r -- "gpg=${GPG_TTY-unset}"
        ' zsh "$GENERATED_ZSHRC"

    [ "$status" -eq 0 ]
    [[ "$output" == *"hook=unset"* ]]
    [[ "$output" == *"gpg=unset"* ]]
}
