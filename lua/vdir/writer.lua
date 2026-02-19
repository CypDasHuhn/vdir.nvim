local M = {}

---Serialize a folder recursively
---@param folder VdirFolder
---@param prefix string TOML path prefix (e.g., "folder" or "folder.folder")
---@param lines string[]
local function serialize_folder(folder, prefix, lines)
	table.insert(lines, string.format("[[%s]]", prefix))
	table.insert(lines, string.format('name = "%s"', folder.name))
	table.insert(lines, "")

	-- Serialize queries
	if folder.query then
		for _, query in ipairs(folder.query) do
			table.insert(lines, string.format("[[%s.query]]", prefix))
			table.insert(lines, string.format('name = "%s"', query.name))
			table.insert(lines, string.format('pattern = "%s"', query.pattern))
			if query.glob then
				table.insert(lines, string.format('glob = "%s"', query.glob))
			end
			if query.regex then
				table.insert(lines, "regex = true")
			end
			table.insert(lines, "")
		end
	end

	-- Serialize nested folders
	if folder.folder then
		for _, subfolder in ipairs(folder.folder) do
			serialize_folder(subfolder, prefix .. ".folder", lines)
		end
	end
end

---Serialize config back to TOML
---@param cfg VdirConfig
---@return string
function M.serialize(cfg)
	local lines = {}

	if cfg.folder then
		for _, folder in ipairs(cfg.folder) do
			serialize_folder(folder, "folder", lines)
		end
	end

	return table.concat(lines, "\n")
end

---Write config to file
---@param cfg VdirConfig
---@param path string
---@return boolean, string|nil
function M.write(cfg, path)
	local content = M.serialize(cfg)
	local file = io.open(path, "w")
	if not file then
		return false, "Could not open file for writing: " .. path
	end
	file:write(content)
	file:close()
	return true, nil
end

return M
