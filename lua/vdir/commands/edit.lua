local ui = require("vdir.ui")
local query_editor = require("vdir.ui.query_editor")
local writer = require("vdir.writer")
local utils = require("vdir.commands.utils")

local M = {}

---Check if node is renameable (folder or query, not root or file)
---@param node_id string
---@return boolean is_valid
---@return string|nil error_message
---@return string|nil item_type
local function is_renameable(node_id)
	if not node_id then
		return false, "No node selected", nil
	end

	if node_id == "root" then
		return false, "Cannot rename Root", nil
	end

	-- Check if this is a file
	if node_id:match("_query_%d+_.+") then
		return false, "Cannot rename query result files", nil
	end

	-- Check if this is a query
	if node_id:match("_query_%d+$") then
		return true, nil, "query"
	end

	-- It's a folder
	return true, nil, "folder"
end

---Check if node is a query (for editing)
---@param node_id string
---@return boolean is_valid
---@return string|nil error_message
local function is_editable_query(node_id)
	if not node_id then
		return false, "No node selected"
	end

	if node_id == "root" then
		return false, "Cannot edit Root"
	end

	if node_id:match("_query_%d+_.+") then
		return false, "Cannot edit files"
	end

	if not node_id:match("_query_%d+$") then
		return false, "Select a query to edit"
	end

	return true, nil
end

---Convert filetypes string to glob
---@param filetypes_str string
---@return string|nil
local function filetypes_to_glob(filetypes_str)
	if not filetypes_str or filetypes_str == "" then
		return nil
	end
	-- Parse comma-separated
	local types = {}
	for t in filetypes_str:gmatch("[^,]+") do
		local trimmed = t:match("^%s*(.-)%s*$")
		if trimmed ~= "" then
			table.insert(types, trimmed)
		end
	end
	if #types == 0 then
		return nil
	end
	if #types == 1 then
		return "**/*." .. types[1]
	end
	return "**/*.{" .. table.concat(types, ",") .. "}"
end

---Rename command (for folders and queries)
---@param state table
function M.rename(state)
	local node = state.tree:get_node()
	if not node then
		return
	end

	local node_id = node:get_id()
	local node_name = node.name

	local valid, err, item_type = is_renameable(node_id)
	if not valid then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	local cfg, cfg_err = utils.get_config(state)
	if not cfg then
		vim.notify(cfg_err or "No config found", vim.log.levels.ERROR)
		return
	end

	local folder_path, query_idx = utils.parse_node_id(node_id)

	ui.cursor_input("Rename", node_name, function(new_name)
		if new_name == node_name then
			return
		end

		-- Check for duplicate
		local check_path = folder_path
		if item_type == "folder" then
			check_path = utils.get_parent_path(folder_path)
		end
		if utils.name_exists_at_parent(cfg, check_path, new_name) then
			vim.notify("An item with name '" .. new_name .. "' already exists", vim.log.levels.ERROR)
			return
		end

		if item_type == "query" then
			local folder = utils.get_folder_at_path(cfg, folder_path)
			if folder and folder.query and query_idx then
				folder.query[query_idx].name = new_name
			end
		elseif item_type == "folder" then
			local folder = utils.get_folder_at_path(cfg, folder_path)
			if folder then
				folder.name = new_name
			end
		end

		utils.save_and_refresh(state, cfg, item_type .. " renamed")
	end)
end

---Edit query command (opens the query editor)
---@param state table
function M.edit(state)
	local node = state.tree:get_node()
	if not node then
		return
	end

	local node_id = node:get_id()

	local valid, err = is_editable_query(node_id)
	if not valid then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	local cfg, cfg_err = utils.get_config(state)
	if not cfg then
		vim.notify(cfg_err or "No config found", vim.log.levels.ERROR)
		return
	end

	local folder_path, query_idx = utils.parse_node_id(node_id)
	local folder = utils.get_folder_at_path(cfg, folder_path)

	if not folder or not folder.query or not query_idx then
		vim.notify("Could not find query", vim.log.levels.ERROR)
		return
	end

	local query = folder.query[query_idx]
	local cwd = state.path or vim.fn.getcwd()

	query_editor.open(query, cwd, function(data)
		-- Update query
		query.pattern = data.pattern
		query.glob = filetypes_to_glob(data.filetypes)
		query.regex = data.regex

		-- Save
		local config_path = utils.get_config_path(state)
		if config_path then
			local ok, write_err = writer.write(cfg, config_path)
			if ok then
				vim.notify("Query updated", vim.log.levels.INFO)
				utils.refresh(state)
			else
				vim.notify(write_err or "Failed to save", vim.log.levels.ERROR)
			end
		end
	end)
end

-- Keep old view_query as alias for backward compat
M.view_query = M.edit

return M
