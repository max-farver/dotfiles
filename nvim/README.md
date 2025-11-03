# mfarver.nvim

Personal Neovim configuration built around a patched fork of `lazy.nvim` and the `mini.nvim` ecosystem. The goal is a fast startup, excellent defaults for everyday editing, and enough hooks to tailor language tooling per project without turning this into a full distribution.

## Highlights

- **Lean core**: bootstraps `lazy.nvim` from `max-farver/lazy.nvim@fix-recursive`, trims the default runtime path, and relies on simple Lua modules under `lua/config`.
- **mini.nvim-first workflow**: `mini.files`, `mini.pick`, `mini.completion`, `mini.snippets`, `mini.notify`, and friends replace heavier analogs while keeping UI polish.
- **Rich UI touches**: `lualine.nvim` with project-aware components, `incline.nvim` tabs, `tiny-inline-diagnostic`, `tiny-glimmer`, and `snacks.nvim` toggles for quick tweaks (`<leader>u?`).
- **Language-aware LSP**: shared `on_attach` logic, buffer-scoped formatters/linters via `conform.nvim` and `nvim-lint`, `none-ls.nvim` for gap fillers, and helpers to merge per-project overrides.
- **Testing & debugging**: `nvim-dap`, `debugmaster.nvim`, `neotest` (with Go extras), and optional coverage reporting keep feedback loops tight.
- **Quickfix & git tooling**: `nvim-bqf`, `quicker.nvim`, `gitsigns.nvim`, `diffview.nvim`, and `gitlinker.nvim` streamline review, search, and collaboration.

## Requirements

- Neovim 0.10+ (uses `vim.lsp.config`, `vim.lsp.enable`, and `vim.secure.read`).
- Base tooling: `git`, `rg`, `fd`, a C compiler, and a Nerd Font for icons.
- Language-specific CLIs you care about (Go, Python, Terraform, SQL, etc.); run `:ToolsCheck` to see what this config expects.
- Optional: clipboard integration (`xclip`, `wl-copy`, `pbcopy`, etc.) and emoji fonts if you want inline glyphs.

## Installation

- Back up any existing `$XDG_CONFIG_HOME/nvim` directory.
- Clone or symlink this repo into `~/.config/nvim` (or another directory if you launch with `NVIM_APPNAME`):

  ```sh
  git clone <your-fork-or-copy> "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
  ```

- Start Neovim; the bootstrap in `lua/config/lazy.lua` will clone the pinned `lazy.nvim` fork and install plugins.
- Open `:Lazy` to monitor installs, then restart Neovim once everything completes.

## Everyday Usage

- **Files**: `<leader>fe` / `<leader>e` open `mini.files` at project root or current file; `S` syncs pending operations, `Q` syncs and closes.
- **Fuzzy finding**: `<leader>ff` finds files (root), `<leader>/` live-greps, `<leader>fo` recent files—each powered by `mini.pick` with `<C-q>` to send matches to quickfix.
- **Diagnostics**: `[d` / `]d` cycle issues; `<leader>ud` toggles diagnostics via Snacks; floating windows use `tiny-inline-diagnostic`.
- **Git**: `<leader>gs` stages the current hunk, `<leader>gp` previews, `<leader>go` opens the current selection on the remote via `gitlinker`.
- **Tests & debugging**: `<leader>t?` prefixes drive `neotest`; `<leader>d?` manages DAP sessions; `<leader>dd` toggles Debugmaster’s global mode.
- **Utility toggles**: `<leader>uf` flips global autoformat, `<leader>uT` toggles Treesitter, `<leader>ub` switches light/dark—all backed by `snacks.nvim`.

## Project Overrides

Drop a `.nvim.lua` file in your project root to extend or override the defaults. The file is read securely before plugins load, so your customizations flow into ftplugins and language helpers.

```lua
-- .nvim.lua
vim.g.project_plugin_opts = {
  ['ray-x/go.nvim'] = {
    goimports = 'gopls',
    build_tags = 'unit,integration,bench',
  },
}

vim.g.project_lsp_servers = {
  gopls = {
    settings = {
      gopls = { directoryFilters = { '-vendor' } },
    },
  },
}

vim.g.project_formatters = {
  go = { 'goimports' },
}

vim.g.project_linters = {
  go = { 'golangci-lint' },
}
```

Helpers in `lua/config/project.lua` and `lua/config/ftplugin_helpers.lua` merge these tables with the defaults, so you can opt-in per adapter without touching the core config.

## Snippets & Language Hooks

- Snippets live under `snippets/<lang>/` and load through `mini.snippets` (see `snippets/lua/ftplugin.lua` for a template).
- Language-specific behavior resides in `after/ftplugin/*.lua`; each module exposes `M.plugins` so Lazy can register extra specs only when that filetype loads.

## Tooling Tips

- `:ToolsCheck` (from `lua/config/toolscheck.lua`) reports missing external binaries.
- `:FormatDisable[!]` / `:FormatEnable` toggle `conform.nvim` autoformat globally or per buffer; `<leader>uF` mirrors the buffer toggle.
- `:Lazy sync`, `:Lazy check`, and `:Lazy restore` remain the primary plugin management entry points.
- Use `NVIM_APPNAME` to keep alternate builds—for example, `NVIM_APPNAME=nvim-mfarver nvim` runs this config isolated from your default.

## Repo Layout

- `init.lua` – wiring for options, autocmds, keymaps, lazy bootstrap, and the base colorscheme (`dracula` by default, with fallbacks in `lua/plugins/themes.lua`).
- `lua/config/` – shared helpers (statusline, root detection, project overrides, etc.).
- `lua/plugins/` – Lazy specs grouped by topic (`core`, `ui`, `lsp`, `git`, `neotest`, `mini/*`, etc.).
- `after/ftplugin/` – language-aware plugins, LSP setup, and local tweaks via the helper scaffolding.
- `snippets/` – collection of `mini.snippets` sources.
