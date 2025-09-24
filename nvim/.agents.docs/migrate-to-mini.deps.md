# Migrating from lazy.nvim to mini.deps

This document outlines how to migrate this Neovim configuration from lazy.nvim to mini.deps, while preserving lazy-load behavior (event/cmd/ft/keys), plugin options/config hooks, and a locked, reproducible plugin set.

## Goals
- Replace lazy.nvim plugin management with mini.deps.
- Keep current lazy-loading semantics to avoid startup regressions.
- Preserve lock/pin behavior for reproducibility.
- Minimize invasive changes; enable staged rollout and easy rollback.

## Current State (snapshot)
- Bootstrap: `init.lua` requires `config.lazy` which bootstraps lazy.nvim and loads plugin specs from `lua/plugins/*`.
- Spec usage relies on lazy fields: `event`, `cmd`, `ft`, `keys`, `dependencies`, `opts`, `config`, `build`, `version`, `init`, `cond`, and custom `VeryLazy`.
- Lockfile: `lazy-lock.json` at repo root pins SHAs.
- UI: `lua/plugins/ui.lua` references `require('lazy.status')` for updates.
- Disabled built-ins via lazy `rtp.disabled_plugins` list in `lua/config/lazy.lua`.

## Strategy
Use mini.deps for install/update/lock, plus a thin “compat loader” that translates our existing lazy-style specs into:
- Install graph via `MiniDeps.add` (with dependencies and build hooks).
- Opt/start loading and runtime activation via `packadd` and on-demand shims for `event/cmd/ft/keys`.
- One-time `opts` resolution and `config` execution on first activation.
- A synthetic `User VeryLazy` event fired after startup to mimic lazy.nvim.

This approach allows incremental migration and keeps most spec files unchanged.

## Phased Plan

### Phase 0 — Bootstrap mini.deps (keep lazy in place for now)
Add `lua/config/deps.lua` to bootstrap mini.deps without altering the rest of the config yet.

Example bootstrap (sketch):

```lua
-- lua/config/deps.lua
local data = vim.fn.stdpath('data')
local pack = data .. '/site/pack/deps/start/mini.deps'
if (vim.uv or vim.loop).fs_stat(pack) == nil then
  vim.fn.system({ 'git', 'clone', '--filter=blob:none', 'https://github.com/nvim-mini/mini.deps', pack })
end
vim.cmd('packadd mini.deps')

require('mini.deps').setup({
  -- Optionally set path for lockfile:
  -- path = { lock = vim.fn.stdpath('config') .. '/deps.lock.json' },
})

-- Provide a synthetic VeryLazy event similar to lazy.nvim
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    vim.defer_fn(function()
      vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy' })
    end, 50)
  end,
})
```

Hook-up happens at cutover by switching `init.lua` from `require('config.lazy')` to `require('config.deps')`.

### Phase 1 — Build a thin compat loader
Add `lua/config/plugin_loader.lua` that accepts the same lazy-style spec tables used today and:

- Install/pin:
  - Call `MiniDeps.add({ source = 'user/repo', depends = {...}, hooks = {...} })` for each plugin.
  - Translate `dependencies` recursively with the same treatment.
  - Map `build` to `hooks` for install/update (e.g., nvim-treesitter `:TSUpdate`).
  - Prefer lockfile for SHAs; only use `ref/tag` in `MiniDeps.add` when necessary.

- Lazy-load semantics:
  - If any of `event/cmd/ft/keys` are present (or `lazy = true`), treat plugin as `opt` and load via `packadd` on demand.
  - Create one-shot shims that on first trigger: `packadd` the plugin, run its `init` (if provided), resolve `opts`, run `config(_, opts)`, and then re-dispatch the trigger.
    - event: autocmd(s) for the given events (plus `User VeryLazy` support).
    - cmd: user command stubs that load, then recurse to the real command.
    - ft: `FileType` autocmd for listed filetypes.
    - keys: provisional mappings that load, rebind the final map, then re-execute the key once.
  - If no triggers (`lazy = false`), treat as `start`: `packadd` + configure immediately.

- One-time execution guard to ensure each plugin’s `config` only runs once.

Pseudo-API shape:

```lua
-- lua/config/plugin_loader.lua
local M = {}
function M.load_specs(specs)
  -- 1) Register/install via MiniDeps.add (and deps/build hooks)
  -- 2) For each spec, set up shims for event/cmd/ft/keys or eager load
  -- 3) On first activation, run init -> opts -> config
end
return M
```

### Phase 2 — Lockfile and update flow
- Introduce a mini.deps lockfile (e.g., `deps.lock.json`).
- Initially mirror SHAs from `lazy-lock.json` so the state stays identical at cutover.
  - Option: write a one-off Lua script that reads `lazy-lock.json` and writes a `deps.lock.json` in the format expected by mini.deps.
- Provide simple commands:
  - `:DepsUpdate` → update plugins via mini.deps API.
  - `:DepsLock` → write/refresh the lockfile.
  - `:DepsClean` → remove unused plugins.
- Optional: background update check on startup to compute pending update counts and store them for statusline use.

### Phase 3 — Port plugin groups and validate
Proceed incrementally, validating that triggers work as expected:
1) Core, general, git groups.
2) Treesitter (`build = ':TSUpdate'`), UI.
3) LSP/tooling (mason, lint/conform, none-ls), then language-specific (go/python/sql).
4) mini.* modules (already using `nvim-mini/*`).

Checklist per group:
- Trigger parity: event/cmd/ft/keys fire once and re-enter safely.
- Keymaps: behavior before/after lazy-load matches current.
- Dependencies load before parent `config`.
- Build hooks execute on install/update.

### Phase 4 — Replace lazy-specific UI and remove lazy
- Replace `require('lazy.status')` in `lua/plugins/ui.lua` with a tiny status provider:
  - New module `lua/config/updates.lua` that caches update counts (e.g., computed at startup or on demand).
  - UI reads from that provider instead of `lazy.status`.

- Disable built-in Vim plugins at startup (replaces lazy’s `rtp.disabled_plugins`):

```lua
-- Add early (e.g., in lua/config/options.lua)
vim.g.loaded_gzip = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_tutor = 1
vim.g.loaded_zipPlugin = 1
```

- Finalize cutover:
  - `init.lua`: replace `require('config.lazy')` with `require('config.deps')`.
  - Remove `lua/config/lazy.lua`.
  - Remove `lazy-lock.json` after the new lockfile is validated.

## Feature Mapping Reference
- event → autocmd(s) to `packadd` + configure; add synthetic `User VeryLazy`.
- cmd → stub commands load then re-invoke the original.
- ft → `FileType` autocmd to load on matching filetypes.
- keys → provisional mappings that load, rebind, and replay the key once; support `expr` maps by re-evaluating after load.
- dependencies → `MiniDeps.add(... depends = {...})`; ensure deps are loaded before parent config.
- build → `hooks` on install/update (e.g., run `:TSUpdate`).
- version/lock → use mini.deps lockfile for SHAs; only set `ref/tag` in `add()` when needed.
- init → run before first load to set globals/paths.
- cond → skip add/load if false.
- priority → rarely needed; emulate by load order where applicable.
- checker/change_detection → replace with `:DepsUpdate` + optional background update check.

## Files To Add/Change
- Add:
  - `lua/config/deps.lua` — mini.deps bootstrap + `VeryLazy` event.
  - `lua/config/plugin_loader.lua` — compat loader interpreting lazy-style specs.
  - `lua/config/updates.lua` — optional; computes/caches update info for statusline.
- Change at cutover:
  - `init.lua` — switch `require('config.lazy')` → `require('config.deps')`.
  - `lua/plugins/ui.lua` — replace `lazy.status` usages.
  - `lua/config/options.lua` (or new `config/rtp.lua`) — disable built-in plugins via `vim.g.loaded_*`.
- Remove after validation:
  - `lua/config/lazy.lua`
  - `lazy-lock.json`

## Validation Checklist
- Startup: no errors; no unexpected eager loads; built-ins disabled.
- Triggers: commands (`OverseerRun`, `GrugFar`, `TmuxNavigateLeft`), events (`BufReadPost`, `InsertEnter`, `VeryLazy`), filetypes (sql/go/python/terraform), and keys (dial/yanky/flash) all lazy-load and behave correctly.
- LSP attach and diagnostics actions still bind and work; nvim-lint autocommands fire.
- Treesitter build hooks run when needed.
- Lockfile reflects current pins; update/lock commands work.

## Rollout Plan
- Develop on a branch; keep lazy enabled until Phase 3 completes for core groups.
- Switch `init.lua` to `config.deps` and dogfood for several days.
- Remove lazy files and lockfile once stable.

## Open Questions
- Keymap shims for `expr`: prefer replaying the mapping vs. re-evaluating? Default to re-evaluating post-load for correctness.
- Update checks: compute only at startup, or schedule periodic checks?
- Lockfile path: root (`deps.lock.json`) or under `lua/config/` — pick what’s most convenient for your workflow.

## Time Estimate
- Bootstrap + loader: 3–5 hours.
- Group-by-group port and testing: ~0.5–1 day.
- Cleanup + docs + lock migration: 1–2 hours.

---

### Appendix: Minimal Loader Patterns (sketches)

```lua
-- Event shim
vim.api.nvim_create_autocmd({ 'BufReadPost' }, {
  once = true,
  callback = function()
    vim.cmd('packadd my/plugin')
    -- run init/opts/config once
  end,
})

-- Cmd shim
vim.api.nvim_create_user_command('MyCmd', function(ctx)
  vim.cmd('packadd my/plugin')
  -- run init/opts/config once, then re-exec original command
  vim.cmd('MyCmd ' .. ctx.args)
end, { nargs = '*' })

-- Keys shim
vim.keymap.set('n', '<leader>x', function()
  vim.cmd('packadd my/plugin')
  -- run init/opts/config once, then re-dispatch the key
  vim.api.nvim_feedkeys(vim.keycode('<leader>x'), 'im', false)
end, { desc = 'Lazy-load my/plugin' })
```
