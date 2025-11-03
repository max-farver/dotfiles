local M = {}

M.diagnostics = {
  Error = "",
  Warn = "",
  Info = "",
  Hint = "",
}

M.git = {
  added = "+",
  modified = "~",
  removed = "-",
}

M.kinds = {
  Array = "󱃶",
  Boolean = "󰨙",
  Class = "󰠱",
  Color = "󰏘",
  Constant = "󰏿",
  Constructor = "󰈔",
  Copilot = "",
  Enum = "󱚣",
  EnumMember = "󰅱",
  Event = "",
  Field = "󰜢",
  File = "󰈔",
  Folder = "󰉋",
  Function = "󰊕",
  Interface = "󰜰",
  Key = "󰌋",
  Keyword = "󰌋",
  Method = "󰆧",
  Module = "󰅩",
  Namespace = "󰌗",
  Null = "󰟢",
  Number = "󰎠",
  Object = "󰅩",
  Operator = "󰆕",
  Package = "󰏗",
  Property = "󰖷",
  Reference = "󰬲",
  Snippet = "󱄽",
  String = "󱀍",
  Struct = "󰙅",
  Text = "󰉿",
  TypeParameter = "󰊄",
  Unit = "󰪚",
  Value = "󰎠",
  Variable = "󰀫",
}

M.dap = {
  Breakpoint = "",
  BreakpointCondition = "",
  BreakpointRejected = "",
  LogPoint = "",
  Stopped = { "", "DiagnosticWarn", "DiffAdd" },
}

return M
