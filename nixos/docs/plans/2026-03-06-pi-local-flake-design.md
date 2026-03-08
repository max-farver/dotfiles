# Local pi Flake Integration Design

## Goal

Add the pi flake definition from the provided gist into this NixOS config as local source code, without depending on the remote gist URL.

## Chosen Approach

Vendor the gist as a local flake at `pkgs/pi/flake.nix`, then wire it into the root flake via a path input and consume the package in `terminal/ai.nix`.

## Why This Approach

- Keeps the large pi package definition isolated from the root `flake.nix`.
- Preserves flake-based packaging and makes updates straightforward.
- Avoids external gist dependency while still allowing local editing.

## Planned Changes

1. Add `pkgs/pi/flake.nix` containing the vendored pi flake.
2. Update root `flake.nix` inputs with `pi-local.url = "path:./pkgs/pi";`.
3. Add `inputs.pi-local.packages.${pkgs.system}.default` to `terminal/ai.nix` `home.packages`.

## Validation

- Evaluate or build Home Manager/NixOS config to ensure the new package resolves.
- Confirm `terminal/ai.nix` includes pi package alongside existing AI tools.
