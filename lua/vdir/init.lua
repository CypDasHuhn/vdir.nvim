local renderer = require("neo-tree.ui.renderer")
local config = require("vdir.config")
local grep = require("vdir.grep")

local M = {}

M.name = "vdir"
M.display_name = "Vdir"

---Build folder node recursively
---@param folder VdirFolder
---@param folder_id string
---@param cwd string
---@return table
local function build_folder_node(folder, folder_id, cwd)
	local folder_node = {
		id = folder_id,
		name = folder.name,
		type = "directory",
		children = {},
	}

	-- Add queries
	if folder.query then
		for query_idx, query in ipairs(folder.query) do
			local query_id = folder_id .. "_query_" .. query_idx
			local query_node = {
				id = query_id,
				name = query.name,
				type = "directory",
				extra = { is_query = true },
				children = {},
			}

			-- Run grep to find matching files
			local files = grep.find_files(query.pattern, query.glob, cwd, query.regex)

			for _, file in ipairs(files) do
				-- Make path relative to cwd for display
				local display_name = file
				if file:sub(1, #cwd) == cwd then
					display_name = file:sub(#cwd + 2)
				end

				table.insert(query_node.children, {
					id = query_id .. "_" .. file,
					name = display_name,
					type = "file",
					path = file, -- Store full path for opening
				})
			end

			table.insert(folder_node.children, query_node)
		end
	end

	-- Add subfolders
	if folder.folder then
		for subfolder_idx, subfolder in ipairs(folder.folder) do
			local subfolder_id = folder_id .. "_folder_" .. subfolder_idx
			local subfolder_node = build_folder_node(subfolder, subfolder_id, cwd)
			table.insert(folder_node.children, subfolder_node)
		end
	end

	return folder_node
end

---Build tree items from config
---@param vdir_config VdirConfig
---@param cwd string
---@return table[]
local function build_tree(vdir_config, cwd)
	local root = {
		id = "root",
		name = "Root",
		type = "directory",
		children = {},
	}

	if vdir_config.folder then
		for folder_idx, folder in ipairs(vdir_config.folder) do
			local folder_id = "folder_" .. folder_idx
			local folder_node = build_folder_node(folder, folder_id, cwd)
			table.insert(root.children, folder_node)
		end
	end

	return { root }
end

M.navigate = function(state, path)
	if path == nil then
		path = vim.fn.getcwd()
	end
	state.path = path

	local vdir_config, err = config.load(path)

	local items
	if vdir_config then
		items = build_tree(vdir_config, path)
	else
		-- Show error as a node
		items = {
			{
				id = "error",
				name = err or "Unknown error loading config",
				type = "file",
			},
		}
	end

	renderer.show_nodes(items, state)
end

M.setup = function(cfg, global_config)
	-- Setup logic here
end

-- region: disable filesystem bindings
local disabled_keys = {
	"<C-b>", "<C-f>", "<C-r>", "<C-x>",
	"A", "C", "D", "H", "P", "R", "S",
	"[g", "]g",
	"b", "c", "d", "f", "i", "l", "m", "o",
	"oc", "od", "og", "om", "on", "os", "ot",
	"p", "q", "r", "s", "t", "w", "x", "y", "z",
}

local mappings = {}
for _, key in ipairs(disabled_keys) do
	mappings[key] = "none"
end
-- endregion

mappings["a"] = "add"
mappings["A"] = "add_folder"
mappings["d"] = "delete"
mappings["e"] = "edit"
mappings["r"] = "rename"

M.default_config = {
	window = {
		mappings = mappings,
	},
}

return M
