local config = require("vdir.config")
local writer = require("vdir.writer")
local manager = require("neo-tree.sources.manager")

local M = {}

---Get the config path and loaded config for current state
---@param state table
---@return VdirConfig|nil, string|nil
function M.get_config(state)
	local cwd = state.path or vim.fn.getcwd()
	return config.load(cwd)
end

---Get config file path
---@param state table
---@return string|nil
function M.get_config_path(state)
	local cwd = state.path or vim.fn.getcwd()
	return config.find_config(cwd)
end

---Parse node id to get folder path and query index
---@param node_id string
---@return number[] folder_path (list of folder indices)
---@return number|nil query_idx
function M.parse_node_id(node_id)
	if node_id == "root" then
		return {}, nil
	end

	local folder_path = {}
	local query_idx = nil

	-- Extract query index if present
	query_idx = node_id:match("_query_(%d+)")
	if query_idx then
		query_idx = tonumber(query_idx)
	end

	-- Extract all folder indices from the path
	-- Pattern: folder_1, folder_1_folder_2, etc.
	for idx in node_id:gmatch("folder_(%d+)") do
		table.insert(folder_path, tonumber(idx))
	end

	return folder_path, query_idx
end

---Get the folder at the given path
---@param cfg VdirConfig
---@param folder_path number[]
---@return VdirFolder|nil
function M.get_folder_at_path(cfg, folder_path)
	if #folder_path == 0 then
		return nil
	end

	local current = cfg.folder[folder_path[1]]
	for i = 2, #folder_path do
		if not current or not current.folder then
			return nil
		end
		current = current.folder[folder_path[i]]
	end
	return current
end

---Get parent folder path (all but last element)
---@param folder_path number[]
---@return number[]
function M.get_parent_path(folder_path)
	local parent = {}
	for i = 1, #folder_path - 1 do
		table.insert(parent, folder_path[i])
	end
	return parent
end

---Check if a name already exists at the given parent level
---@param cfg VdirConfig
---@param folder_path number[]
---@param name string
---@return boolean
function M.name_exists_at_parent(cfg, folder_path, name)
	if #folder_path == 0 then
		-- At root level, check top-level folders
		for _, folder in ipairs(cfg.folder or {}) do
			if folder.name == name then
				return true
			end
		end
		return false
	else
		-- Inside a folder, check subfolders and queries
		local parent = M.get_folder_at_path(cfg, folder_path)
		if not parent then
			return false
		end
		for _, subfolder in ipairs(parent.folder or {}) do
			if subfolder.name == name then
				return true
			end
		end
		for _, query in ipairs(parent.query or {}) do
			if query.name == name then
				return true
			end
		end
		return false
	end
end

---Save config and refresh
---@param state table
---@param cfg VdirConfig
---@param message string
function M.save_and_refresh(state, cfg, message)
	local config_path = M.get_config_path(state)
	if not config_path then
		config_path = (state.path or vim.fn.getcwd()) .. "/.vdir.toml"
	end

	local ok, write_err = writer.write(cfg, config_path)
	if ok then
		vim.notify(message, vim.log.levels.INFO)
		M.refresh(state)
	else
		vim.notify(write_err or "Failed to save", vim.log.levels.ERROR)
	end
end

---Refresh the vdir tree
---@param state table
function M.refresh(state)
	manager.refresh("vdir", state)
end

return M
