return {
  {
    "luukvbaal/statuscol.nvim",
    event = "VeryLazy",
    enabled = not vim.g.vscode,
    opts = function()
      local builtin = require("statuscol.builtin")
      return {
        -- place relative numbers to the right of the absolute number
        relculright = true,
        -- automatically set the 'statuscolumn' option
        setopt = true,
        -- basic layout: signs | line numbers | folds
        segments = {
          -- signs (diagnostics, gitsigns, etc.)
          { text = { "%s" }, click = "v:lua.ScSa" },
          -- line numbers (smart relative/absolute)
          { text = { builtin.lnumfunc }, click = "v:lua.ScLa" },
          -- fold column indicator
          { text = { " ", builtin.foldfunc }, click = "v:lua.ScFa" },
        },
      }
    end,
    config = function(_, opts)
      require("statuscol").setup(opts)
    end,
  },
}

