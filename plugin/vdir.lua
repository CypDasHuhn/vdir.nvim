vim.api.nvim_create_user_command("Vdir", function()
	require("vdir").open()
end, {})
