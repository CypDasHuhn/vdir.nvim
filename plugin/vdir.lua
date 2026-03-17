local cli = require("vdir.cli")

local function ensure_vdir_source()
	local ok, nt = pcall(require, "neo-tree")
	if not ok then
		vim.notify("neo-tree.nvim is required for vdir.nvim", vim.log.levels.ERROR)
		return false
	end

	local cfg = nt.config
	local has_vdir = false

	if cfg and cfg.sources then
		for _, source in ipairs(cfg.sources) do
			if source == "vdir" then
				has_vdir = true
				break
			end
		end
	end

	if has_vdir then
		return true
	end

	-- If neo-tree isn't configured yet, apply a minimal default config with vdir.
	if not cfg then
		nt.setup({
			sources = { "filesystem", "buffers", "git_status", "vdir" },
			source_selector = {
				winbar = true,
				sources = {
					{ source = "filesystem" },
					{ source = "vdir" },
				},
			},
			window = {
				mappings = {
					["<Tab>"] = "next_source",
					["<S-Tab>"] = "prev_source",
				},
			},
		})
		return true
	end

	-- Merge vdir into existing config without overwriting user settings.
	local new_sources = vim.deepcopy(cfg.sources or {})
	table.insert(new_sources, "vdir")

	local merged = vim.tbl_deep_extend("force", {}, cfg, { sources = new_sources })

	if merged.source_selector and merged.source_selector.sources then
		local selector_has_vdir = false
		for _, item in ipairs(merged.source_selector.sources) do
			if item.source == "vdir" then
				selector_has_vdir = true
				break
			end
		end
		if not selector_has_vdir then
			table.insert(merged.source_selector.sources, { source = "vdir" })
		end
	end

	nt.setup(merged)
	return true
end

local function ensure_vdir_initialized(cwd, on_ready)
	local result, err = cli.run({ "pwd" }, { cwd = cwd })
	if result then
		on_ready()
		return
	end

	if not err or not err:match("No vdir found") then
		vim.notify(err or "Failed to inspect vdir state", vim.log.levels.ERROR)
		return
	end

	vim.ui.select({ "Yes", "No" }, {
		prompt = "No vdir found here. Create one?",
	}, function(choice)
		if choice ~= "Yes" then
			return
		end

		local init_result, init_err = cli.run({ "init" }, { cwd = cwd })
		if not init_result then
			vim.notify(init_err or "Failed to initialize vdir", vim.log.levels.ERROR)
			return
		end

		on_ready()
	end)
end

local function open_vdir()
	local cwd = vim.fn.getcwd()
	if ensure_vdir_source() then
		ensure_vdir_initialized(cwd, function()
			require("neo-tree.command").execute({ source = "vdir", toggle = true })
		end)
	end
end

vim.api.nvim_create_user_command("Vdir", open_vdir, {})

vim.keymap.set("n", "<leader>q", open_vdir, { desc = "Toggle Vdir" })
