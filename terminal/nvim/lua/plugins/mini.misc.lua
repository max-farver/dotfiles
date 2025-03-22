return {
  "echasnovski/mini.misc",
  init = function()
    local MiniMisc = require("mini.misc")
    MiniMisc.setup({ make_global = { "put", "put_text", "stat_summary", "bench_time" } })
    MiniMisc.setup_auto_root()
    MiniMisc.setup_termbg_sync()
  end,
}
