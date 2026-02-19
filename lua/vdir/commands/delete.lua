local ui = require("vdir.ui")
local utils = require("vdir.commands.utils")

local M = {}

---Check if the current node is deletable
---@param node_id string
---@return boolean is_valid
---@return string|nil error_message
---@return string|nil item_type ("folder" or "query")
local function is_deletable(node_id)
	if not node_id then
		return false, "No node selected", nil
	end

	if node_id == "root" then
		return false, "Cannot delete Root", nil
	end

	-- Check if this is a file (contains _query_ and has a file path after it)
	if node_id:match("_query_%d+_.+") then
		return false, "Cannot delete query result files", nil
	end

	-- Check if this is a query node (ends with _query_N)
	if node_id:match("_query_%d+$") then
		return true, nil, "query"
	end

	-- It's a folder
	return true, nil, "folder"
end

---Delete command
---@param state table
function M.delete(state)
	local node = state.tree:get_node()
	if not node then
		return
	end

	local node_id = node:get_id()
	local node_name = node.name

	local valid, err, item_type = is_deletable(node_id)
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

	ui.cursor_input("Delete '" .. node_name .. "'? (y/n)", "", function(answer)
		if answer ~= "y" and answer ~= "Y" then
			return
		end

		if item_type == "query" then
			-- Delete query from parent folder
			local folder = utils.get_folder_at_path(cfg, folder_path)
			if folder and folder.query and query_idx then
				table.remove(folder.query, query_idx)
			end
		elseif item_type == "folder" then
			-- Delete folder from parent
			local folder_idx = folder_path[#folder_path]
			local parent_path = utils.get_parent_path(folder_path)

			if #parent_path == 0 then
				-- Deleting from root level
				table.remove(cfg.folder, folder_idx)
			else
				-- Deleting from a parent folder
				local parent = utils.get_folder_at_path(cfg, parent_path)
				if parent and parent.folder then
					table.remove(parent.folder, folder_idx)
				end
			end
		end

		utils.save_and_refresh(state, cfg, item_type .. " deleted")
	end)
end

return M
