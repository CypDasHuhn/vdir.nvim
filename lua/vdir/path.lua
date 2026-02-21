local M = {}

local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
local sep = package.config:sub(1, 1)

---@param p string
---@return string
function M.normalize(p)
	if vim.fs and vim.fs.normalize then
		return vim.fs.normalize(p)
	end
	return (p or ""):gsub("\\", "/")
end

---@param base string
---@param name string
---@return string
function M.join(base, name)
	if base:sub(-1) == "/" or base:sub(-1) == "\\" then
		return base .. name
	end
	local join_sep = sep
	if base:find("/", 1, true) and not base:find("\\", 1, true) then
		join_sep = "/"
	end
	return base .. join_sep .. name
end

---@param absolute_path string
---@param base_path string
---@return string|nil
function M.relpath(absolute_path, base_path)
	local norm_path = M.normalize(absolute_path)
	local norm_base = M.normalize(base_path)

	local lhs = norm_path
	local rhs = norm_base
	if is_windows then
		lhs = lhs:lower()
		rhs = rhs:lower()
	end

	if lhs:sub(1, #rhs) ~= rhs then
		return nil
	end

	local boundary = norm_path:sub(#norm_base + 1, #norm_base + 1)
	if boundary == "" then
		return "."
	end
	if boundary == "/" then
		return norm_path:sub(#norm_base + 2)
	end
	return nil
end

return M
