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

vim.api.nvim_create_user_command("Vdir", function()
	if ensure_vdir_source() then
		require("neo-tree.command").execute({ source = "vdir", toggle = true })
	end
end, {})

vim.keymap.set("n", "<leader>q", function()
	if ensure_vdir_source() then
		require("neo-tree.command").execute({ source = "vdir", toggle = true })
	end
end, { desc = "Toggle Vdir" })
