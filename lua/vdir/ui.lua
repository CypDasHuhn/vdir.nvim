local NuiInput = require("nui.input")

local M = {}

---@class QueryData
---@field scope string|nil
---@field compiler string|nil
---@field args string|nil
---@field raw boolean|nil
---@field cmd_map table<string, string>|nil
---@field cmd_map_order string[]|nil

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
	local data = {
		cmd_map = {},
	}
	for _, line in ipairs(lines) do
		-- Check for cmd:<shell> format
		local shell_name, shell_cmd = line:match("^cmd:([%w_]+):%s*(.*)$")
		if shell_name and shell_cmd then
			data.cmd_map[shell_name] = shell_cmd
		else
			-- Regular key: value format
			local key, value = line:match("^([%w_]+):%s*(.*)$")
			if key and value then
				data[key] = value
			end
		end
	end
	return data
end

---Show query viewer/editor
---@param query QueryData
---@param on_save fun(data: QueryData)|nil
---@param opts? {title?: string}
function M.show_query(query, on_save, opts)
	opts = opts or {}
	local lines = {
		"scope: " .. (query.scope or "."),
		"",
		"# Shell commands (add cmd:<shell>: <command>)",
	}

	-- Add compiler info if present (read-only info)
	if query.compiler then
		table.insert(lines, "# compiler: " .. query.compiler .. (query.args and (" " .. query.args) or ""))
	end
	if query.raw then
		table.insert(lines, "# raw: true")
	end

	table.insert(lines, "")

	-- Add existing shell commands
	local cmd_map = query.cmd_map or {}
	local cmd_order = query.cmd_map_order or {}

	-- Use order if available, otherwise iterate
	if #cmd_order > 0 then
		for _, shell_name in ipairs(cmd_order) do
			local shell_cmd = cmd_map[shell_name]
			if shell_cmd then
				table.insert(lines, "cmd:" .. shell_name .. ": " .. shell_cmd)
			end
		end
	else
		for shell_name, shell_cmd in pairs(cmd_map) do
			table.insert(lines, "cmd:" .. shell_name .. ": " .. shell_cmd)
		end
	end

	-- Add placeholder if no commands
	if vim.tbl_isempty(cmd_map) then
		table.insert(lines, "cmd:bash: ")
	end

	local height = math.max(#lines + 2, 8)
	local bufnr, winnr = create_float(lines, {
		title = opts.title or " Query ",
		width = 80,
		height = height,
	})

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

	vim.cmd("startinsert!")
end

function M.path_complete(findstart, base)
	if findstart == 1 then
		local line = vim.fn.getline(".")
		local col = vim.fn.col(".") - 1
		local before = line:sub(1, col)
		local start = #before - (#before:match("[^%s]*$") or 0)
		return start > 0 and start or 0
	else
		return vim.fn.getcompletion(base, "file")
	end
end

function M.path_input(title, default_value, on_submit)
	local width = 60

	local input = NuiInput({
		relative = "editor",
		position = {
			row = math.floor(vim.o.lines / 2) - 1,
			col = math.floor((vim.o.columns - width) / 2),
		},
		size = width,
		border = {
			style = "rounded",
			text = {
				top = " " .. title .. " ",
				top_align = "left",
				bottom = " Tab to autocomplete | Enter=ok | Esc=cancel ",
				bottom_align = "center",
			},
		},
	}, {
		prompt = " ",
		default_value = default_value or "",
		on_submit = function(value)
			if value and value ~= "" then
				on_submit(value)
			end
		end,
	})

	input:mount()

	vim.bo[input.bufnr].completefunc = "v:lua.require'vdir.ui'.path_complete"

	input:map("n", "<Esc>", function()
		input:unmount()
	end, { noremap = true })

	input:map("i", "<Esc>", function()
		input:unmount()
	end, { noremap = true })

	input:map("i", "<Tab>", function()
		if vim.fn.pumvisible() == 1 then
			vim.api.nvim_feedkeys(vim.keycode("<C-n>"), "n", true)
		else
			vim.api.nvim_feedkeys(vim.keycode("<C-x><C-u>"), "n", true)
		end
	end, { noremap = true })

	vim.cmd("startinsert!")
end

return M
