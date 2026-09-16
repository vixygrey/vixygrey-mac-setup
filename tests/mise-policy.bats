#!/usr/bin/env bats
# Behavioral contract for generated mise trust and installation policy (#652).

setup() {
    TEST_TMP="$(mktemp -d)"
    export GENERATED_MISE_CONFIG="$TEST_TMP/mise.toml"
    awk "/<<'MISE_CONF'/{f=1;next} /^MISE_CONF$/{f=0} f" \
        "$BATS_TEST_DIRNAME/../scripts/setup-dev-tools-mac.sh" > "$GENERATED_MISE_CONFIG"
}

teardown() {
    rm -rf "$TEST_TMP"
}

@test "mise requires explicit project trust and installation while preserving default tools (#652)" {
    run python3 -c 'import sys, tomllib; config = tomllib.load(open(sys.argv[1], "rb")); settings = config["settings"]; assert settings["auto_install"] is False, "automatic installation remained enabled"; assert "trusted_config_paths" not in settings, "blanket trust remained configured"; assert config["tools"] == {"node": "lts", "python": "3.12"}, "default tool selection changed"' "$GENERATED_MISE_CONFIG"

    [ "$status" -eq 0 ]
}
