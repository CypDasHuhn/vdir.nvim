local renderer = require("neo-tree.ui.renderer")

local M = {}

M.name = "vdir"
M.display_name = "Vdir"

M.navigate = function(state, path)
	if path == nil then
		path = vim.fn.getcwd()
	end
	state.path = path

	local items = {
		{
			id = "a",
			name = "a",
			type = "directory",
			children = {
				{ id = "a1", name = "a1", type = "file" },
				{ id = "a2", name = "a2", type = "file" },
				{ id = "a3", name = "a3", type = "file" },
			},
		},
		{
			id = "b",
			name = "b",
			type = "directory",
			children = {
				{ id = "b1", name = "b1", type = "file" },
				{ id = "b2", name = "b2", type = "file" },
			},
		},
	}

	renderer.show_nodes(items, state)
end

M.setup = function(config, global_config)
	-- Setup logic here
end

M.default_config = {
	window = {
		mappings = {},
	},
}

return M
