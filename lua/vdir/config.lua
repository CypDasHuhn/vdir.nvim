local toml = require("vdir.toml")
local path = require("vdir.path")

local M = {}

---Create a new empty .vdir.toml file
---@param path string Directory where to create the file
---@return string|nil config_path, string|nil error
function M.create(path_str)
	local config_path = path.join(path_str, ".vdir.toml")
	local file = io.open(config_path, "w")
	if not file then
		return nil, "Could not create file: " .. config_path
	end
	file:close()
	return config_path, nil
end

---@class VdirQuery
---@field name string
---@field pattern string
---@field glob string|nil
---@field regex boolean|nil

---@class VdirFolder
---@field name string
---@field query VdirQuery[]
---@field folder VdirFolder[]|nil

---@class VdirConfig
---@field folder VdirFolder[]

---Find .vdir.toml in cwd or parents
---@param start_path string
---@return string|nil
function M.find_config(start_path)
	local current = start_path
	while current do
		local config_path = path.join(current, ".vdir.toml")
		if vim.fn.filereadable(config_path) == 1 then
			return config_path
		end
		local parent = vim.fn.fnamemodify(current, ":h")
		if parent == current then
			break
		end
		current = parent
	end
	return nil
end

---Load and parse config, creating a new one if not found
---@param cwd string
---@param create_if_missing boolean|nil If true, create .vdir.toml when not found (default: true)
---@return VdirConfig|nil, string|nil
function M.load(cwd, create_if_missing)
	if create_if_missing == nil then
		create_if_missing = true
	end

	local config_path = M.find_config(cwd)
	if not config_path then
		if not create_if_missing then
			return nil, "No .vdir.toml found"
		end
		-- Create a new .vdir.toml with default config
		local new_path, create_err = M.create(cwd)
		if not new_path then
			return nil, "Failed to create .vdir.toml: " .. (create_err or "unknown error")
		end
		config_path = new_path
		vim.notify("Created new .vdir.toml at " .. config_path, vim.log.levels.INFO)
	end

	local cfg, err = toml.parse_file(config_path)
	if not cfg then
		return nil, err
	end

	return cfg, nil
end

return M
