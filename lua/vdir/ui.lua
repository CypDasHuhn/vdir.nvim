local NuiInput = require("nui.input")

local M = {}

---@class QueryData
---@field name string
---@field pattern string
---@field glob string|nil

---Create popup options for cursor-relative input (like neo-tree)
---@param title string
---@param width number
---@return table
local function popup_options(title, width)
	-- Adjust column if popup would extend past screen edge
	local col = 0
	local win_col = vim.api.nvim_win_get_position(0)[2]
	local popup_last_col = win_col + width + 2
	if popup_last_col >= vim.o.columns then
		col = vim.o.columns - popup_last_col
	end

	return {
		relative = "cursor",
		position = {
			row = 1,
			col = col,
		},
		size = width,
		border = {
			style = "rounded",
			text = {
				top = " " .. title .. " ",
				top_align = "left",
			},
		},
	}
end

---Show an input box under the cursor
---@param title string
---@param default_value string
---@param on_submit fun(value: string)
function M.cursor_input(title, default_value, on_submit)
	local width = math.max(#title + 4, 30)
	local opts = popup_options(title, width)

	local input = NuiInput(opts, {
		prompt = " ",
		default_value = default_value or "",
		on_submit = function(value)
			if value and value ~= "" then
				on_submit(value)
			end
		end,
	})

	input:mount()

	-- Close on escape
	input:map("n", "<Esc>", function()
		input:unmount()
	end, { noremap = true })

	input:map("i", "<Esc>", function()
		input:unmount()
	end, { noremap = true })

	-- Enter insert mode
	vim.cmd("startinsert!")
end

---Create a floating window
---@param lines string[]
---@param opts? {title?: string, width?: number, height?: number}
---@return number bufnr
---@return number winnr
local function create_float(lines, opts)
	opts = opts or {}
	local width = opts.width or 50
	local height = opts.height or #lines + 2

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	local winnr = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = "rounded",
		title = opts.title or "",
		title_pos = "center",
	})

	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })

	return bufnr, winnr
end

---Parse buffer content to query data
---@param bufnr number
---@return QueryData
local function parse_buffer(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local data = {}
	for _, line in ipairs(lines) do
		local key, value = line:match("^(%w+):%s*(.*)$")
		if key and value then
			if value ~= "" then
				data[key] = value
			end
		end
	end
	return data
end

---Show query viewer/editor
---@param query QueryData
---@param on_save fun(data: QueryData)|nil
function M.show_query(query, on_save)
	local lines = {
		"name: " .. (query.name or ""),
		"pattern: " .. (query.pattern or ""),
		"glob: " .. (query.glob or ""),
	}

	local bufnr, winnr = create_float(lines, { title = " Query ", width = 50, height = 5 })

	-- Close on q or Escape
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(winnr, true)
	end, { buffer = bufnr })

	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(winnr, true)
	end, { buffer = bufnr })

	-- Save on <CR> or <C-s>
	local function save()
		local data = parse_buffer(bufnr)
		vim.api.nvim_win_close(winnr, true)
		if on_save then
			on_save(data)
		end
	end

	vim.keymap.set("n", "<CR>", save, { buffer = bufnr })
	vim.keymap.set("n", "<C-s>", save, { buffer = bufnr })
	vim.keymap.set("i", "<C-s>", save, { buffer = bufnr })
end

return M
