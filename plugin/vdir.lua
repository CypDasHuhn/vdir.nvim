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
	vdir = {},
})

vim.api.nvim_create_user_command("Vdir", function()
	require("neo-tree.command").execute({ source = "vdir", toggle = true })
end, {})

vim.keymap.set("n", "<leader>q", function()
	require("neo-tree.command").execute({ source = "vdir", toggle = true })
end, { desc = "Toggle Vdir" })
