return {
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    event = { { event = "BufReadCmd", pattern = "octo://*" } },
    opts = {
      enable_builtin = true,
      -- default_to_projects_v2 = true,
      default_merge_method = "squash",
      picker = "telescope",
      suppress_missing_scope = {
        projects_v2 = true,
      },
    },
    keys = {
      { "<leader>gi", "<cmd>Octo issue list<CR>", desc = "List Issues (Octo)" },
      { "<leader>gI", "<cmd>Octo issue search<CR>", desc = "Search Issues (Octo)" },
      { "<leader>gp", "<cmd>Octo pr list<CR>", desc = "List PRs (Octo)" },
      { "<leader>gP", "<cmd>Octo pr search<CR>", desc = "Search PRs (Octo)" },
      { "<leader>gr", "<cmd>Octo repo list<CR>", desc = "List Repos (Octo)" },
      { "<leader>gS", "<cmd>Octo search<CR>", desc = "Search (Octo)" },

      { "<localleader>a", "", desc = "+assignee (Octo)", ft = "octo" },
      { "<localleader>c", "", desc = "+comment/code (Octo)", ft = "octo" },
      { "<localleader>l", "", desc = "+label (Octo)", ft = "octo" },
      { "<localleader>i", "", desc = "+issue (Octo)", ft = "octo" },
      { "<localleader>r", "", desc = "+react (Octo)", ft = "octo" },
      { "<localleader>p", "", desc = "+pr (Octo)", ft = "octo" },
      { "<localleader>pr", "", desc = "+rebase (Octo)", ft = "octo" },
      { "<localleader>ps", "", desc = "+squash (Octo)", ft = "octo" },
      { "<localleader>v", "", desc = "+review (Octo)", ft = "octo" },
      { "<localleader>g", "", desc = "+goto_issue (Octo)", ft = "octo" },
      { "@", "@<C-x><C-o>", mode = "i", ft = "octo", silent = true },
      { "#", "#<C-x><C-o>", mode = "i", ft = "octo", silent = true },
    },
  },

  -- setting the picker
  {
    "pwntester/octo.nvim",
    opts = function(_, opts)
      vim.treesitter.language.register("markdown", "octo")
      if LazyVim.has_extra("editor.telescope") then
        opts.picker = "telescope"
      elseif LazyVim.has_extra("editor.fzf") then
        opts.picker = "fzf-lua"
      elseif LazyVim.has_extra("editor.snacks_picker") then
        opts.picker = "snacks"
      else
        LazyVim.error("`octo.nvim` requires `telescope.nvim` or `fzf-lua` or `snacks.nvim`")
      end

      -- Keep some empty windows in sessions
      vim.api.nvim_create_autocmd("ExitPre", {
        group = vim.api.nvim_create_augroup("octo_exit_pre", { clear = true }),
        callback = function(ev)
          local keep = { "octo" }
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.tbl_contains(keep, vim.bo[buf].filetype) then
              vim.bo[buf].buftype = "" -- set buftype to empty to keep the window
            end
          end
        end,
      })
    end,
  },
}
