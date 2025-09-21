local sql_ft = { "sql", "mysql", "plsql" }

return {
  {
    "tpope/vim-dadbod",
    cmd = "DB",
  },
  {
    "kristijanhusak/vim-dadbod-completion",
    dependencies = "tpope/vim-dadbod",
    ft = sql_ft,
  },
  {
    "kristijanhusak/vim-dadbod-ui",
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    dependencies = "tpope/vim-dadbod",
    -- keymaps defined in config/keymaps.lua
    init = function()
      local data_path = vim.fn.stdpath("data")
      vim.g.db_ui_auto_execute_table_helpers = 1
      vim.g.db_ui_save_location = data_path .. "/dadbod_ui"
      vim.g.db_ui_show_database_icon = true
      vim.g.db_ui_tmp_query_location = data_path .. "/dadbod_ui/tmp"
      vim.g.db_ui_use_nerd_fonts = true
      vim.g.db_ui_use_nvim_notify = true
      vim.g.db_ui_execute_on_save = false
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        for _, lang in ipairs({ "sql" }) do
          if not vim.tbl_contains(opts.ensure_installed, lang) then
            table.insert(opts.ensure_installed, lang)
          end
        end
      end
    end,
  },
  {
    "williamboman/mason.nvim",
    enabled = not require("config.os").is_linux,
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      for _, tool in ipairs({ "sqlfluff" }) do
        if not vim.tbl_contains(opts.ensure_installed, tool) then
          table.insert(opts.ensure_installed, tool)
        end
      end
    end,
  },
}
