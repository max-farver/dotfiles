return {
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "markdownlint-cli2",
        "markdown-toc",
        "prettier",
        "sqlfluff",
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      vim.tbl_extend("keep", opts.servers, opts.servers, { marksman = {} })
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = vim.list_extend(opts.sources or {}, {
        nls.builtins.diagnostics.markdownlint_cli2,
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        ["markdown-toc"] = {
          condition = function(_, ctx)
            for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
              if line:find("<!%-%- toc %-%->") then
                return true
              end
            end
          end,
        },
        ["markdownlint-cli2"] = {
          condition = function(_, ctx)
            local diag = vim.tbl_filter(function(d)
              return d.source == "markdownlint"
            end, vim.diagnostic.get(ctx.buf))
            return #diag > 0
          end,
        },
        yamlfix = {
          env = {
            YAMLFIX_SEQUENCE_STYLE = "block_style",
            YAMLFIX_INDENT_MAPPING = "4",
            YAMLFIX_INDENT_OFFSET = "4",
            YAMLFIX_INDENT_SEQUENCE = "6",
            YAMLFIX_EXPLICIT_START = "false",
            YAMLFIX_LINE_LENGTH = "240",
            YAMLFIX_preserve_quotes = "true",
          },
        },
      },
      formatters_by_ft = {
        ["markdown"] = { "prettier", "markdownlint-cli2", "markdown-toc" },
        ["markdown.mdx"] = { "prettier", "markdownlint-cli2", "markdown-toc" },
        sql = { "sqlfluff" },
        yaml = { "yamlfix" },
      },
    },
  },
}
