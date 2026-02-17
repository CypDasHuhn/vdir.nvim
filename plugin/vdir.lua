require("neo-tree").setup({
	sources = { "filesystem", "vdir" },
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

vim.api.nvim_create_user_command("Vdir", function()
	require("neo-tree.command").execute({ source = "vdir", toggle = true })
end, {})
