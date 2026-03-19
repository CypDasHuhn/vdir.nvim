local Layout = require("nui.layout")
local Popup = require("nui.popup")
local cli = require("vdir.cli")

local M = {}

M.config = {
	debounce_ms = 300,
}

---Debounce helper
---@param fn function
---@param ms number
---@return function
local function debounce(fn, ms)
	local timer = vim.uv.new_timer()
	return function(...)
		local args = { ... }
		timer:stop()
		timer:start(ms, 0, vim.schedule_wrap(function()
			fn(unpack(args))
		end))
	end
end

---Get list of available compilers
---@return string[]
local function get_compilers()
	local result = cli.run({ "compiler", "list" })
	if not result then
		return {}
	end

	local compilers = {}
	for _, line in ipairs(result.lines) do
		-- Parse "  compiler_name (from container_path)"
		local name = line:match("^%s*(%S+)%s+%(from")
		if name then
			table.insert(compilers, name)
		end
	end
	return compilers
end

---Run compiler test and get preview
---@param compiler string
---@param args string
---@return string[]
local function run_preview(compiler, args)
	if compiler == "" then
		return { "(select a compiler)" }
	end

	local cmd_args = { "compiler", "test", compiler }
	if args and args ~= "" then
		table.insert(cmd_args, args)
	end

	local result = cli.run(cmd_args)
	if not result then
		return { "(compiler test failed)" }
	end

	-- Parse output - skip header lines, show shell commands
	local lines = {}
	local in_output = false
	for _, line in ipairs(result.lines) do
		if line:match("^Output:") then
			in_output = true
		elseif in_output then
			local trimmed = line:match("^%s*(.-)%s*$")
			if trimmed and trimmed ~= "" then
				table.insert(lines, trimmed)
			end
		end
	end

	if #lines == 0 then
		return { "(no output)" }
	end

	return lines
end

---Open the query editor for compiler-based queries
---@param query table { compiler: string|nil, args: string|nil }
---@param cwd string
---@param on_save fun(data: { compiler: string, args: string })
function M.open(query, cwd, on_save)
	local compilers = get_compilers()
	local compiler_idx = 1
	local current_compiler = query.compiler or ""
	local current_args = query.args or ""

	-- Find index of current compiler
	for i, c in ipairs(compilers) do
		if c == current_compiler then
			compiler_idx = i
			break
		end
	end

	if #compilers == 0 then
		vim.notify("No compilers available. Use 'vdir compiler add <path>' to add a container.", vim.log.levels.ERROR)
		return
	end

	local current_panel = 1 -- 1=compiler, 2=args
	local panels = {}

	-- Compiler panel (selection)
	panels.compiler = Popup({
		border = {
			style = "rounded",
			text = {
				top = " Compiler [" .. compiler_idx .. "/" .. #compilers .. "] ",
				top_align = "left",
				bottom = " <C-n>/<C-p> to change ",
				bottom_align = "center",
			},
		},
		focusable = true,
		buf_options = {
			modifiable = false,
			filetype = "vdir_compiler",
		},
	})

	-- Args panel
	panels.args = Popup({
		border = {
			style = "rounded",
			text = {
				top = " Arguments ",
				top_align = "left",
			},
		},
		focusable = true,
		buf_options = {
			modifiable = true,
			filetype = "vdir_args",
		},
	})

	-- Preview panel (read-only)
	panels.preview = Popup({
		border = {
			style = "rounded",
			text = {
				top = " Preview (shell commands) ",
				top_align = "left",
				bottom = " <CR> save | <Esc> cancel ",
				bottom_align = "center",
			},
		},
		focusable = false,
		buf_options = {
			modifiable = false,
			filetype = "vdir_preview",
		},
	})

	local layout = Layout(
		{
			position = "50%",
			size = {
				width = 70,
				height = 20,
			},
		},
		Layout.Box({
			Layout.Box(panels.compiler, { size = 3 }),
			Layout.Box(panels.args, { size = 3 }),
			Layout.Box(panels.preview, { grow = 1 }),
		}, { dir = "col" })
	)

	-- Update compiler display
	local function update_compiler_display()
		local comp = compilers[compiler_idx] or ""
		vim.api.nvim_set_option_value("modifiable", true, { buf = panels.compiler.bufnr })
		vim.api.nvim_buf_set_lines(panels.compiler.bufnr, 0, -1, false, { comp })
		vim.api.nvim_set_option_value("modifiable", false, { buf = panels.compiler.bufnr })
		panels.compiler.border:set_text("top", " Compiler [" .. compiler_idx .. "/" .. #compilers .. "] ", "left")
	end

	-- Update preview with debounce
	local update_preview = debounce(function()
		local comp = compilers[compiler_idx] or ""
		local args = vim.api.nvim_buf_get_lines(panels.args.bufnr, 0, 1, false)[1] or ""
		local results = run_preview(comp, args)

		vim.api.nvim_set_option_value("modifiable", true, { buf = panels.preview.bufnr })
		vim.api.nvim_buf_set_lines(panels.preview.bufnr, 0, -1, false, results)
		vim.api.nvim_set_option_value("modifiable", false, { buf = panels.preview.bufnr })

		local count = #results
		if results[1] and (results[1]:match("^%(") or results[1] == "") then
			count = 0
		end
		panels.preview.border:set_text("top", " Preview (" .. count .. " shell commands) ", "left")
	end, M.config.debounce_ms)

	-- Focus management
	local panel_order = { "compiler", "args" }

	local function focus_panel(idx)
		current_panel = idx
		local name = panel_order[idx]
		vim.api.nvim_set_current_win(panels[name].winid)
	end

	local function next_panel()
		local next_idx = current_panel % #panel_order + 1
		focus_panel(next_idx)
	end

	local function prev_panel()
		local prev_idx = (current_panel - 2) % #panel_order + 1
		focus_panel(prev_idx)
	end

	-- Compiler selection
	local function next_compiler()
		compiler_idx = compiler_idx % #compilers + 1
		update_compiler_display()
		update_preview()
	end

	local function prev_compiler()
		compiler_idx = (compiler_idx - 2) % #compilers + 1
		update_compiler_display()
		update_preview()
	end

	-- Save function
	local function save()
		local comp = compilers[compiler_idx] or ""
		if comp == "" then
			vim.notify("Select a compiler", vim.log.levels.ERROR)
			return
		end

		local args_lines = vim.api.nvim_buf_get_lines(panels.args.bufnr, 0, -1, false)
		local args = table.concat(args_lines, " "):match("^%s*(.-)%s*$") or ""

		vim.cmd("stopinsert")
		layout:unmount()
		on_save({
			compiler = comp,
			args = args,
		})
	end

	-- Close function
	local function close()
		vim.cmd("stopinsert")
		layout:unmount()
	end

	-- Mount layout
	layout:mount()

	-- Set initial content
	update_compiler_display()
	vim.api.nvim_buf_set_lines(panels.args.bufnr, 0, -1, false, { current_args })

	-- Initial preview
	update_preview()

	-- Setup keymaps for all focusable panels
	for _, name in ipairs(panel_order) do
		local popup = panels[name]
		local opts = { noremap = true, nowait = true }

		-- Navigation between panels
		vim.keymap.set({ "n", "i" }, "<Tab>", next_panel, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))
		vim.keymap.set({ "n", "i" }, "<S-Tab>", prev_panel, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))

		-- Close
		vim.keymap.set("n", "q", close, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))
		vim.keymap.set({ "n", "i" }, "<Esc>", close, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))

		-- Save
		vim.keymap.set({ "n", "i" }, "<CR>", save, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))
		vim.keymap.set({ "n", "i" }, "<C-s>", save, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))

		-- Compiler selection (works from any panel)
		vim.keymap.set({ "n", "i" }, "<C-n>", next_compiler, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))
		vim.keymap.set({ "n", "i" }, "<C-p>", prev_compiler, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))
	end

	-- Auto-update preview on args change
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = panels.args.bufnr,
		callback = update_preview,
	})

	-- Focus args panel and enter insert mode (compiler is read-only)
	focus_panel(2)
	vim.cmd("startinsert!")
end

return M
