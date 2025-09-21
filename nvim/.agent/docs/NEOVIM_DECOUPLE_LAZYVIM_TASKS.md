# Neovim Config: Decouple from LazyVim — Task List

This document captures a complete, ordered checklist to finish decoupling the Neovim configuration in this repo from the LazyVim distro, and to reach parity with your selected Lazy Extras and UI preferences.

Repository root (current config): `~/.config/nvim-kickstart`
LazyVim reference repo: `tmp/LazyVim`

Owner decisions (locked in):
- Bufferline: NO
- mini.icons: YES
- Enable default Snacks UI modules and toggles: YES
- Default colorscheme: Dracula
- VSCode functionality: REQUIRED

Note: File paths below are relative to the repo root.

---

## 1) Remove LazyVim Coupling

Problem: A lingering call to `LazyVim.root()` keeps a runtime dependency on LazyVim.

- [ ] Add a small root helper:
  - Create `lua/config/root.lua` exporting `get()` that attempts:
    - Active LSP root for current buffer (ignore copilot) if available.
    - Else search upward for markers (e.g., `.git`, `package.json`, `pyproject.toml`, `go.mod`, `Gemfile`, `Makefile`, `Cargo.toml`, `lua` folder).
    - Else `vim.uv.cwd()`.
- [ ] Update Snacks explorer to use the new helper instead of `LazyVim.root()`:
  - File: `lua/plugins/snacks/explorer.lua`
  - Replace: `Snacks.explorer({ cwd = LazyVim.root() })`
  - With:    `Snacks.explorer({ cwd = require('config.root').get() })`

---

## 2) Defaults — Options Parity

Base file: `lua/config/options.lua`
LazyVim reference: `tmp/LazyVim/lua/lazyvim/config/options.lua`

Add/adjust the following (choose to keep or tweak any that you don’t want):

- [ ] `opt.linebreak = true`
- [ ] `opt.smoothscroll = true`
- [ ] `opt.wildmode = "longest:full,full"`
- [ ] `opt.winminwidth = 5`
- [ ] Folding parity:
  - [ ] `opt.foldmethod = "indent"`
  - [ ] `opt.foldtext = ""`
  - (Keep your existing `foldlevel`/`fillchars` choices or adopt LazyVim’s icons)
- [ ] Session options — include these in addition to your current ones:
  - [ ] `"help"`, `"globals"`, `"skiprtp"`, `"folds"`
- [ ] Ruler and list:
  - [ ] `opt.ruler = false`
  - [ ] Decide `opt.list` (LazyVim uses `true`; currently you have `false`).
- [ ] Markdown indentation fix:
  - [ ] `vim.g.markdown_recommended_style = 0`

Globals to consider (optional based on your workflows):
- [ ] `vim.g.autoformat = true` (or false) to control auto-format features if you want a toggle.

Theme source of truth (see section 6).

---

## 3) Defaults — Autocmds Parity

Base file: `lua/config/autocmds.lua`
LazyVim reference: `tmp/LazyVim/lua/lazyvim/config/autocmds.lua`

Add these common autocmds (keep your Go test flags & reload logic):

- [ ] Yank highlight:
  - `TextYankPost` → `(vim.hl or vim.highlight).on_yank()`
- [ ] Resize splits on `VimResized` (use `tabdo wincmd =` and return to current tab).
- [ ] Restore cursor location on `BufReadPost` (skip e.g. `gitcommit`).
- [ ] Quick-close with `q` for auxiliary buffers (`help`, `qf`, `notify`, `lspinfo`, `grug-far`, `startuptime`, etc.).
- [ ] Mark `man` filetype buffers unlisted.
- [ ] Text filetypes: enable wrap + spell for `text`, `plaintex`, `typst`, `gitcommit`, `markdown`.
- [ ] JSON: set `conceallevel = 0` for `json`, `jsonc`, `json5`.
- [ ] Auto-create directory on `BufWritePre` if missing.
- [ ] Extend reload checktime to include `TermClose` and `TermLeave` events.

---

## 4) Defaults — Keymaps Parity

Base file: `lua/config/keymaps.lua`
LazyVim reference: `tmp/LazyVim/lua/lazyvim/config/keymaps.lua`

Keep your existing maps. Add the following (avoid conflicts with tmux-navigator on `<C-Arrow>`; do not add `<C-Arrow>` resizes unless desired):

- Splits & window mgmt:
  - [ ] `<leader>-` → split below (`<C-w>s`)
  - [ ] `<leader>|` → split right (`<C-w>v`)
  - [ ] `<leader>wd` → close window (`<C-w>c`)
- Move lines:
  - [ ] `<A-j>`/`<A-k>` in normal/insert/visual (use the standard motion/`gv=` patterns)
- Buffers:
  - [ ] `<S-h>` / `<S-l>` → prev/next buffer
  - [ ] `[b` / `]b` → prev/next buffer
  - [ ] `<leader>bb` and `<leader>\`` → switch to alternate buffer (`#`)
  - [ ] `<leader>bo` → delete other buffers (use Snacks.bufdelete.other if available)
  - [ ] `<leader>bD` → delete buffer and window
- Save and indent quality-of-life:
  - [ ] `<C-s>` in normal/insert/visual → save
  - [ ] Keep selection on `<` and `>` in visual mode
  - [ ] Insert-mode undo breakpoints: map `,`, `.`, `;` to append `<c-g>u`
- Search navigation:
  - [ ] Saner `n/N` (expr maps that respect `v:searchforward`)
- Diagnostics:
  - [ ] `]d`, `[d` → next/prev diagnostic
  - [ ] `]e`, `[e` → next/prev error
  - [ ] `]w`, `[w` → next/prev warning
  - [ ] Keep `<leader>cd` → line diagnostics float
- Quickfix/Location list:
  - [ ] `<leader>xq` → toggle quickfix
  - [ ] `<leader>xl` → toggle location list
- Terminal and tabs (optional but recommended):
  - [ ] `<leader>ft` → floating terminal (root dir)
  - [ ] `<leader>fT` → floating terminal (cwd)
  - [ ] `<c-/>` → toggle floating terminal
  - [ ] Tabs suite: `<leader><tab>f/l/o/]/d/[/<tab>` for first/last/only/next/close/prev/new

Snacks toggles (see section 5): add under `<leader>u…`.

---

## 5) UI — mini.icons and Snacks UI Modules/Toggles

Files:
- `lua/plugins/ui.lua`
- `lua/plugins/snacks/nvim.lua`
- `lua/config/keymaps.lua` (toggle bindings)

mini.icons (required):
- [ ] Add plugin `nvim-mini/mini.icons` with:
  - `opts.file` and `opts.filetype` customizations (optional; copy sensible defaults)
  - `init` to `require('mini.icons').mock_nvim_web_devicons()` to provide a drop-in for `nvim-web-devicons`

Snacks UI modules (enable defaults similar to LazyVim):
- [ ] In `lua/plugins/snacks/nvim.lua`, ensure these are enabled in `opts`:
  - `indent`, `input`, `notifier`, `scope`, `scroll`, `words`, `toggle` (configure), and keep `statuscolumn = { enabled = false }`
  - Keep your existing picker and dashboard settings as-is

Snacks toggles (keymaps in `lua/config/keymaps.lua`):
- [ ] `Snacks.toggle.option("spell")` → `<leader>us`
- [ ] `Snacks.toggle.option("wrap")` → `<leader>uw`
- [ ] `Snacks.toggle.line_number()` → `<leader>ul`
- [ ] `Snacks.toggle.option("relativenumber")` → `<leader>uL`
- [ ] `Snacks.toggle.diagnostics()` → `<leader>ud`
- [ ] `Snacks.toggle.treesitter()` → `<leader>uT`
- [ ] `Snacks.toggle.option("conceallevel", { off = 0, on = 2 })` → `<leader>uc`
- [ ] `Snacks.toggle.option("background", { off = "light", on = "dark" })` → `<leader>ub`
- [ ] `Snacks.toggle.dim()` → `<leader>uD`
- [ ] `Snacks.toggle.animate()` → `<leader>ua`
- [ ] `Snacks.toggle.indent()` → `<leader>ug`
- [ ] `Snacks.toggle.scroll()` → `<leader>uS`
- [ ] `Snacks.toggle.profiler()` → `<leader>dpp`
- [ ] `Snacks.toggle.profiler_highlights()` → `<leader>dph`
- [ ] If supported: `Snacks.toggle.inlay_hints()` → `<leader>uh`

---

## 6) Theme Consistency

Files:
- `init.lua`
- `lua/plugins/themes.lua`

- [ ] Keep Dracula as default in `init.lua` (`pcall(vim.cmd.colorscheme, "dracula")`).
- [ ] Remove/disable any forced colorscheme changes inside plugin configs to avoid overriding Dracula, e.g. in the GitHub theme config:
  - Remove `vim.cmd("colorscheme github_dark")` in `lua/plugins/themes.lua`.
- [ ] Keep other themes installed for optional manual switching.

---

## 7) VSCode Functionality

Goal: Make config behave well when running under VSCode Neovim extension (`vim.g.vscode` is true).

Add a dedicated file:
- [ ] `lua/plugins/vscode.lua` with behavior:
  - Detect `vim.g.vscode` and adjust plugin loading via `cond = not vim.g.vscode` where appropriate (e.g., disable heavy UI like `noice`, `lualine`, `incline`, telescope extensions if desired).
  - Snacks config overrides for VSCode: disable heavy modules like `dashboard`, `indent`, `picker`, `quickfile`, `scroll`, `statuscolumn`; set `vim.g.snacks_animate = false`.
  - Treesitter highlight can be disabled in VSCode for speed (`opts = { highlight = { enable = false } }`).
  - VSCode-specific keymaps (use `require('vscode').action(...)`):
    - `<leader><space>` → Find
    - `<leader>/` → Find in Files
    - `<leader>ss` → Goto Symbol
    - `u` / `<C-r>` → VSCode undo/redo (keep histories in sync)
    - `<S-h>` / `<S-l>` → Previous/Next editor
  - Terminal mapping: use `require('vscode').action('workbench.action.terminal.toggleTerminal')` to mirror your floating terminal behavior.

Note: You can implement VSCode adjustments either by file-level `cond = not vim.g.vscode` or an override plugin spec that sets these options when VSCode is detected.

---

## 8) Duplicate Plugin Cleanup

Remove redundant plugin specs where a richer version already exists:

- [ ] `yanky.nvim` — remove from `lua/plugins/core.lua` (keep the version in `lua/plugins/general.lua` with keys and opts)
- [ ] `dial.nvim` — remove from `lua/plugins/core.lua` (keep the version in `lua/plugins/general.lua` with custom opts/config)
- [ ] `inc-rename.nvim` — remove from `lua/plugins/core.lua` (keep the version in `lua/plugins/general.lua`)

`FixCursorHold` exists globally and as a dependency for neotest — leave both references; lazy will dedupe.

---

## 9) Explorer Root Mapping

- [ ] Update `lua/plugins/snacks/explorer.lua` mappings:
  - Root-dir explorer: `Snacks.explorer({ cwd = require('config.root').get() })`
  - Cwd explorer: `Snacks.explorer()` (no change)

---

## 10) Confirm Extras Parity (from prior LazyExtras list)

Already implemented or equivalent present:
- ai.copilot, ai.copilot-chat → `lua/plugins/general.lua`
- coding.mini-surround → `lua/plugins/general.lua`
- coding.yanky → `lua/plugins/general.lua` (after dedupe)
- editor.dial, editor.inc-rename, editor.mini-move → `lua/plugins/general.lua`
- lang.* (docker, git, json, python, sql, terraform, toml, typescript, yaml) → in `lua/plugins/lsp.lua`, `lua/plugins/sql.lua`, `lua/plugins/python.lua`, `lua/plugins/git.lua`, and Treesitter ensure lists
- lsp.none-ls → `lua/plugins/lsp.lua`
- test.core → `lua/plugins/neotest.lua`
- ui.smear-cursor → `lua/plugins/core.lua`
- util.dot → `lua/plugins/dot.lua`
- util.octo → `lua/plugins/git.lua`
- vscode → to be added as in section 7

Confirm if any additional extras should be ported (e.g., util.project, util.startuptime, util.rest, util.gitui, ui.indentscope/animate). Add as needed.

---

## 11) Validation & Sanity Checks

- [ ] Start Neovim and check for startup errors.
- [ ] Open file types to validate autocmds:
  - Yank text → transient highlight shows
  - Resize the UI → splits equalize
  - Reopen a file → cursor restores to last position
  - JSON buffer → conceallevel is 0
  - Markdown/text → wrap+spell is enabled
  - Write into new nested dir → directories auto-created
- [ ] Verify keymaps:
  - Splits (`<leader>-`, `<leader>|`, `<leader>wd`), move lines, buffers, diagnostics, quickfix/location toggles
  - Snacks toggles under `<leader>u…`
  - Floating terminals (`<leader>ft`, `<leader>fT`, `<c-/>`)
- [ ] UI:
  - mini.icons is active (icons show even if devicons missing)
  - No bufferline present
  - Dracula applies and no other theme overrides it
- [ ] VSCode:
  - Launch in VSCode NVim extension with `vim.g.vscode = true`
  - Confirm keymaps/actions and disabled UI behave as expected

---

## 12) Notes & References

Key files to edit:
- `init.lua`
- `lua/config/options.lua`
- `lua/config/autocmds.lua`
- `lua/config/keymaps.lua`
- `lua/config/root.lua` (new)
- `lua/plugins/snacks/explorer.lua`
- `lua/plugins/snacks/nvim.lua`
- `lua/plugins/ui.lua`
- `lua/plugins/themes.lua`
- `lua/plugins/vscode.lua` (new)
- `lua/plugins/core.lua` (remove duplicates)

LazyVim references for parity comparison (do not import, only for reference):
- `tmp/LazyVim/lua/lazyvim/config/options.lua`
- `tmp/LazyVim/lua/lazyvim/config/autocmds.lua`
- `tmp/LazyVim/lua/lazyvim/config/keymaps.lua`
- `tmp/LazyVim/lua/lazyvim/plugins/ui.lua`
- `tmp/LazyVim/lua/lazyvim/plugins/extras/vscode.lua`

---

## 13) Owner Decisions (Resolved)

- Bufferline: No
- mini.icons: Yes (mock devicons via mini.icons)
- Snacks UI modules & toggles: Yes (enable default set)
- Colorscheme: Dracula as default; remove forced GitHub theme application
- VSCode support: Required (add dedicated plugin overrides and keymaps)

---

## 14) Future Enhancements (Optional)

- Add a simple statuscolumn (Snacks) if desired later.
- Add util.project/startuptime if you miss those Lazy Extras.
- Replace telescope with Snacks picker everywhere for consistency (if wanted).

