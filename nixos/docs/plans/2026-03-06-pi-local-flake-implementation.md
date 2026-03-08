# Local pi Flake Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Vendor the pi flake locally and add its package to `terminal/ai.nix` without depending on the remote gist.

**Architecture:** Copy the upstream gist flake into a local flake file under `pkgs/pi/flake.nix`, then expose it to the root flake as a path input. Consume the resulting package from `terminal/ai.nix` via `inputs.pi-local.packages.${pkgs.system}.default`.

**Tech Stack:** Nix flakes, Home Manager module structure, NixOS flake inputs.

---

### Task 1: Vendor pi flake source

**Files:**
- Create: `pkgs/pi/flake.nix`

**Step 1: Add local flake file**

Create `pkgs/pi/flake.nix` with the vendored content from the gist, unchanged except for local formatting consistency.

**Step 2: Verify file parses visually**

Run: `nix flake show ./pkgs/pi`
Expected: flake metadata and package/app outputs are listed.

### Task 2: Wire local flake into root flake

**Files:**
- Modify: `flake.nix`

**Step 1: Add path input**

Add:

```nix
pi-local.url = "path:./pkgs/pi";
```

in the `inputs` set of root `flake.nix`.

**Step 2: Keep outputs args flexible**

No explicit outputs binding required because root already uses `...` in input destructuring.

**Step 3: Verify root flake is still evaluable**

Run: `nix flake show .`
Expected: command succeeds and existing outputs still resolve.

### Task 3: Add pi package to AI tool list

**Files:**
- Modify: `terminal/ai.nix`

**Step 1: Add package entry**

Append:

```nix
inputs.pi-local.packages.${pkgs.system}.default
```

to `home.packages` list.

**Step 2: Verify module evaluation**

Run: `nix eval .#nixosConfigurations.nixos.config.home-manager.users.mfarver.home.packages --apply builtins.length`
Expected: command succeeds and returns package count.

### Task 4: End-to-end validation

**Files:**
- Modify: none

**Step 1: Check local pi flake outputs explicitly**

Run: `nix flake show ./pkgs/pi`
Expected: contains `packages.<system>.default` and app output.

**Step 2: Check top-level flake still resolves**

Run: `nix flake show .`
Expected: succeeds without evaluation errors.
