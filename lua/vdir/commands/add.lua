local ui = require("vdir.ui")
local utils = require("vdir.commands.utils")

local M = {}

---Check if the current node is a valid parent for adding items
---@param node_id string
---@return boolean is_valid
---@return string|nil error_message
local function is_valid_parent(node_id)
	if not node_id then
		return false, "No node selected"
	end

	-- Root is always valid
	if node_id == "root" then
		return true, nil
	end

	-- Check if this is a file (contains _query_ and has a file path after it)
	if node_id:match("_query_%d+_.+") then
		return false, "Cannot add items to a file"
	end

	-- Check if this is a query node (ends with _query_N)
	if node_id:match("_query_%d+$") then
		return false, "Cannot add items to a query"
	end

	-- It's a folder
	return true, nil
end

---Add a folder at the given path
---@param cfg VdirConfig
---@param folder_path number[]
---@param name string
---@return boolean success
---@return string|nil error
local function add_folder_to_config(cfg, folder_path, name)
	if utils.name_exists_at_parent(cfg, folder_path, name) then
		return false, "An item with name '" .. name .. "' already exists"
	end

	if #folder_path == 0 then
		-- At root level
		table.insert(cfg.folder, { name = name, query = {}, folder = {} })
	else
		-- Inside a folder, add as subfolder
		local parent = utils.get_folder_at_path(cfg, folder_path)
		if parent then
			parent.folder = parent.folder or {}
			table.insert(parent.folder, { name = name, query = {}, folder = {} })
		end
	end
	return true, nil
end

---Add command: folder if ends with /, otherwise query
---@param state table
function M.add(state)
	local node = state.tree:get_node()
	local node_id = node and node:get_id() or "root"

	local valid, err = is_valid_parent(node_id)
	if not valid then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	local cfg, _ = utils.get_config(state)
	if not cfg then
		cfg = { folder = {} }
	end

	local folder_path, _ = utils.parse_node_id(node_id)

	ui.cursor_input("Name (end with / for folder)", "", function(value)
		if value:sub(-1) == "/" then
			-- Create folder
			local name = value:sub(1, -2)
			local ok, add_err = add_folder_to_config(cfg, folder_path, name)
			if not ok then
				vim.notify(add_err, vim.log.levels.ERROR)
				return
			end
			utils.save_and_refresh(state, cfg, "folder created")
		else
			-- Create query - need pattern
			if #folder_path == 0 then
				vim.notify("Select a folder first to add a query", vim.log.levels.WARN)
				return
			end

			local query_name = value
			if utils.name_exists_at_parent(cfg, folder_path, query_name) then
				vim.notify("An item with name '" .. query_name .. "' already exists", vim.log.levels.ERROR)
				return
			end

			ui.cursor_input("Pattern", "", function(pattern)
				ui.cursor_input("Glob (optional)", "", function(glob)
					local folder = utils.get_folder_at_path(cfg, folder_path)
					if not folder then
						vim.notify("Could not find folder", vim.log.levels.WARN)
						return
					end
					folder.query = folder.query or {}
					table.insert(folder.query, {
						name = query_name,
						pattern = pattern,
						glob = glob ~= "" and glob or nil,
					})
					utils.save_and_refresh(state, cfg, "query created")
				end)
			end)
		end
	end)
end

---Add folder command (always creates folder)
---@param state table
function M.add_folder(state)
	local node = state.tree:get_node()
	local node_id = node and node:get_id() or "root"

	local valid, err = is_valid_parent(node_id)
	if not valid then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	local cfg, _ = utils.get_config(state)
	if not cfg then
		cfg = { folder = {} }
	end

	local folder_path, _ = utils.parse_node_id(node_id)

	ui.cursor_input("Folder name", "", function(name)
		local ok, add_err = add_folder_to_config(cfg, folder_path, name)
		if not ok then
			vim.notify(add_err, vim.log.levels.ERROR)
			return
		end
		utils.save_and_refresh(state, cfg, "folder created")
	end)
end

return M
