local M = {}

---@class Query
---@field name string
---@field pattern string
---@field glob string|nil

---Run grep and return list of matching files
---@param pattern string
---@param glob string|nil
---@param cwd string
---@param is_regex boolean|nil If false, use fixed-string matching (default: false)
---@return string[]
function M.find_files(pattern, glob, cwd, is_regex)
	local cmd = { "rg", "--files-with-matches", "--no-heading" }

	-- Default to literal matching unless regex mode is enabled
	if not is_regex then
		table.insert(cmd, "--fixed-strings")
	end

	if glob then
		table.insert(cmd, "--glob")
		table.insert(cmd, glob)
	end

	table.insert(cmd, "--")
	table.insert(cmd, pattern)
	table.insert(cmd, cwd)

	local result = vim.fn.systemlist(cmd)

	-- Filter out errors and empty lines, sort by name
	local files = {}
	for _, file in ipairs(result) do
		if file ~= "" and not file:match("^rg:") then
			table.insert(files, file)
		end
	end

	table.sort(files)
	return files
end

return M
