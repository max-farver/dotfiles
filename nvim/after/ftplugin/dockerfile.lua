local helpers = _G.Config.ftplugin_helpers
local project = _G.Config.project

helpers.setup_lsps({
	dockerls = {},
	docker_compose_language_service = {},
})

vim.b.linters = project.get_linters("dockerfile") or { "hadolint" }
