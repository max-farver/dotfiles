#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SCRIPT="$REPO_ROOT/scripts/manage-tailscale-service.sh"
  SOURCE_CONFIG="$REPO_ROOT/system-specific/machines/homelab/tailscale-serve.json"

  TEST_DIR="$(mktemp -d)"
  TEST_CONFIG="$TEST_DIR/tailscale-serve.json"
  cp "$SOURCE_CONFIG" "$TEST_CONFIG"
  TEST_SSH_KEY="$TEST_DIR/test_id_ed25519"
  printf 'not-a-real-key\n' > "$TEST_SSH_KEY"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "validate succeeds on baseline config" {
  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" validate
  [ "$status" -eq 0 ]
}

@test "add creates service with expected endpoint mapping" {
  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" add --name demo --target-port 9000
  [ "$status" -eq 0 ]

  run jq -r '.services["svc:demo"].endpoints["tcp:443"]' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "http://127.0.0.1:9000" ]

  run jq -r '.services["svc:demo"].advertised // true' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "add updates existing service deterministically" {
  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" add --name glance --target-port 8181 --https-port 8443
  [ "$status" -eq 0 ]

  run jq -r '.services["svc:glance"] | keys | join(",")' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "endpoints" ]

  run jq -r '.services["svc:glance"].endpoints["tcp:8443"]' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "http://127.0.0.1:8181" ]

  first_hash="$(sha256sum "$TEST_CONFIG" | awk '{print $1}')"

  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" add --name glance --target-port 8181 --https-port 8443
  [ "$status" -eq 0 ]

  second_hash="$(sha256sum "$TEST_CONFIG" | awk '{print $1}')"
  [ "$first_hash" = "$second_hash" ]
}

@test "add with no-advertise stores advertised false" {
  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" add --name internal --target-port 9010 --no-advertise
  [ "$status" -eq 0 ]

  run jq -r '.services["svc:internal"].advertised' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "remove deletes service and is idempotent" {
  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" remove --name glance
  [ "$status" -eq 0 ]

  run jq -r '.services["svc:glance"] == null' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  hash_after_remove="$(sha256sum "$TEST_CONFIG" | awk '{print $1}')"

  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" remove --name glance
  [ "$status" -eq 0 ]

  hash_after_second_remove="$(sha256sum "$TEST_CONFIG" | awk '{print $1}')"
  [ "$hash_after_remove" = "$hash_after_second_remove" ]
}

@test "add rejects invalid names and ports" {
  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" add --name "Bad_Name" --target-port 9000
  [ "$status" -ne 0 ]

  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" add --name good-name --target-port 99999
  [ "$status" -ne 0 ]

  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" add --name good-name --target-port 9000 --https-port 0
  [ "$status" -ne 0 ]
}

@test "apply-live dry-run prints remote commands" {
  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" apply-live --target-host root@example --ssh-key "$TEST_SSH_KEY" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [[ "$output" == *"tailscale"* ]]
  [[ "$output" == *"reset"* ]]
}

@test "add with apply-live dry-run updates json and prints live commands" {
  run env TAILSCALE_SERVE_CONFIG="$TEST_CONFIG" "$SCRIPT" add --name live-demo --target-port 9090 --apply-live --target-host root@example --ssh-key "$TEST_SSH_KEY" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"svc:live-demo"* ]]
  [[ "$output" == *"[dry-run]"* ]]

  run jq -r '.services["svc:live-demo"].endpoints["tcp:443"]' "$TEST_CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "http://127.0.0.1:9090" ]
}
