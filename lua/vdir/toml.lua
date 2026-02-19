-- Simple TOML parser for vdir config format
local M = {}

---@param str string
---@return string
local function trim(str)
	return str:match("^%s*(.-)%s*$")
end

---@param line string
---@return string|nil
local function parse_table_header(line)
	return line:match("^%[([^%[%]]+)%]$")
end

---@param line string
---@return string|nil
local function parse_array_header(line)
	return line:match("^%[%[([^%[%]]+)%]%]$")
end

---@param value string
---@return string|boolean|number|table|nil
local function parse_value(value)
	value = trim(value)
	-- String
	if value:match('^"(.-)"$') then
		return value:match('^"(.-)"$')
	end
	-- Boolean
	if value == "true" then
		return true
	end
	if value == "false" then
		return false
	end
	-- Number
	local num = tonumber(value)
	if num then
		return num
	end
	-- Array of strings
	if value:match("^%[.*%]$") then
		local arr = {}
		for item in value:gmatch('"([^"]*)"') do
			table.insert(arr, item)
		end
		return arr
	end
	return value
end

---@param content string
---@return table
function M.parse(content)
	local result = {}
	local current_path = {}
	local current_obj = result

	for line in content:gmatch("[^\r\n]+") do
		line = trim(line)

		-- Skip comments and empty lines
		if line == "" or line:match("^#") then
			goto continue
		end

		-- Array of tables [[name]] or [[parent.child]]
		local array_header = parse_array_header(line)
		if array_header then
			local parts = {}
			for part in array_header:gmatch("[^.]+") do
				table.insert(parts, part)
			end

			-- Navigate/create path
			local target = result
			for i, part in ipairs(parts) do
				if i == #parts then
					-- Last part: create array and add new table
					target[part] = target[part] or {}
					local new_obj = {}
					table.insert(target[part], new_obj)
					current_obj = new_obj
				else
					-- Intermediate: navigate into last element of array
					target[part] = target[part] or {}
					local arr = target[part]
					if #arr == 0 then
						table.insert(arr, {})
					end
					target = arr[#arr]
				end
			end
			current_path = parts
			goto continue
		end

		-- Simple table [name]
		local table_header = parse_table_header(line)
		if table_header then
			result[table_header] = result[table_header] or {}
			current_obj = result[table_header]
			current_path = { table_header }
			goto continue
		end

		-- Key-value pair
		local key, value = line:match("^([%w_]+)%s*=%s*(.+)$")
		if key and value then
			current_obj[key] = parse_value(value)
		end

		::continue::
	end

	return result
end

---@param path string
---@return table|nil, string|nil
function M.parse_file(path)
	local file = io.open(path, "r")
	if not file then
		return nil, "Could not open file: " .. path
	end
	local content = file:read("*a")
	file:close()
	return M.parse(content), nil
end

return M
