#!/usr/bin/env bats
# Generated Kiro settings must match the installed Typos spell checker (#674).

setup() {
    TEST_TMP="$(mktemp -d)"
    export GENERATED_KIRO_CONFIG="$TEST_TMP/settings.json"
    awk "/<<'KIRO_CONF'/{f=1;next} /^KIRO_CONF$/{f=0} f" \
        "$BATS_TEST_DIRNAME/../scripts/setup-dev-tools-mac.sh" > "$GENERATED_KIRO_CONFIG"
}

teardown() {
    rm -rf "$TEST_TMP"
}

@test "Kiro defaults configure Typos without obsolete spell-checker or Todo Tree settings (#674, #683)" {
    run python3 -c 'import json, sys; settings = json.load(open(sys.argv[1])); assert settings["typos.diagnosticSeverity"] == "Information"; assert not any(key.startswith(("cSpell.", "todo-tree.")) for key in settings)' "$GENERATED_KIRO_CONFIG"

    [ "$status" -eq 0 ]
}
