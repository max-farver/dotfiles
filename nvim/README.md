# MiniMax-style Neovim config (vim.pack)

Personal Neovim configuration centered on `mini.nvim` and Neovim 0.12's built-in plugin manager, `vim.pack`.

## Highlights

- Built-in plugin management with `vim.pack` (no external manager).
- `mini.nvim`-first UX (`mini.files`, `mini.pick`, `mini.clue`, `mini.notify`, etc.).
- LSP/format/lint workflow via `nvim-lspconfig`, `conform.nvim`, and `nvim-lint`.
- Testing/debugging with `neotest`, `nvim-dap`, `debugmaster.nvim`.
- Git tooling with `gitsigns`, `diffview`, `gitlinker`.
- Filetype-specific plugin loading in `after/ftplugin/*.lua`.

## Requirements

- **Neovim 0.12+** (uses `vim.pack`).
- `git` (required by `vim.pack`).
- Recommended tools: `rg`, Nerd Font, and language/tooling CLIs you use (go, python, terraform, sqlfluff, etc.).

## Installation

```sh
git clone <your-fork-or-copy> "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
```

Start Neovim. Plugins are installed automatically by `vim.pack`.

## Plugin management

This config exposes a tiny helper:

- `_G.Config.pack_add(specs)` → `vim.pack.add(specs, { confirm = false })`
- `_G.Config.pack_add_once(specs)` → add only unseen specs (dedup by `name`/`src`)

and a command:

- `:PackUpdate` → `vim.pack.update()`

Lockfile used by `vim.pack`:

- `~/.config/nvim/nvim-pack-lock.json`

Track this file in git for reproducible plugin revisions across machines.

---

## Handling dependencies (important)

`vim.pack` has no `depends` key. Dependencies are handled by **explicit add order**.

### Rule of thumb

Put dependency specs **before** the plugin that needs them, preferably in one `add()` call.

```lua
local add = _G.Config.pack_add

add({
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/ruifm/gitlinker.nvim" },
})
```

### For filetype plugins (`after/ftplugin`)

Do the same inside the ftplugin loader function so first open has everything in order.

```lua
local add_once = _G.Config.pack_add_once or _G.Config.pack_add

add_once({
  { src = "https://github.com/nvim-neotest/neotest" },
  { src = "https://github.com/nvim-neotest/neotest-python" },
})
```

For Neotest adapters, keep core setup centralized and register adapters from ftplugins
(e.g. `after/ftplugin/python.lua`, `after/ftplugin/go.lua`, `after/ftplugin/ruby.lua`).

### Post-install/update actions (hooks)

Use the `PackChanged` autocmd in `init.lua` for actions like:

- `TSUpdate` after `nvim-treesitter`
- `MasonUpdate` after `mason.nvim`
- `mkdp#util#install()` after `markdown-preview.nvim`

If adding a plugin that needs a post-update step, add a case there.

### Adding a new plugin (checklist)

1. Add a spec in native form:
   - `add({ { src = "https://github.com/user/repo" } })`
2. If it has dependencies, put dependency specs first in the same `add({ ... })` list.
3. Configure it after `add()` (typically `require('plugin').setup({...})`).
4. If it needs post-install/update actions, add a `PackChanged` case in `init.lua`.
5. If it's filetype-specific, place it in `after/ftplugin/<ft>.lua` and guard with a one-time flag.
6. Sanity check startup:
   - `nvim --headless '+q'`
7. Update plugins/lockfile when needed:
   - `:PackUpdate`
   - commit `nvim-pack-lock.json`

## Project overrides

Project-local `.nvim.lua` can provide overrides via globals:

- `vim.g.project_plugin_opts`
- `vim.g.project_lsp_servers`
- `vim.g.project_formatters`
- `vim.g.project_linters`

Merged by helpers in `lua/util/project.lua` and consumed by ftplugin helpers.

## Useful commands

- `:PackUpdate` – update plugins.
- `:FormatDisable[!]` / `:FormatEnable` / `:Format` – formatting controls.
- `:ThemeDark` / `:ThemeLight` / `:ThemeToggle` – theme switching.

## Repo layout

- `init.lua` – bootstrap, `vim.pack` hooks/helpers, shared config helpers.
- `plugin/` – core options, keymaps, plugin configs.
- `after/ftplugin/` – filetype-specific plugin/LSP behavior.
- `lua/util/` – shared utilities (project overrides, root detection, statusline, etc.).
