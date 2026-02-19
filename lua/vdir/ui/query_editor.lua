local Layout = require("nui.layout")
local Popup = require("nui.popup")
local grep = require("vdir.grep")

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

---Parse comma-separated values (respecting \,)
---@param str string
---@return string[]
local function parse_csv(str)
	local result = {}
	local current = ""
	local i = 1
	while i <= #str do
		local char = str:sub(i, i)
		if char == "\\" and str:sub(i + 1, i + 1) == "," then
			current = current .. ","
			i = i + 2
		elseif char == "," then
			local trimmed = current:match("^%s*(.-)%s*$")
			if trimmed ~= "" then
				table.insert(result, trimmed)
			end
			current = ""
			i = i + 1
		else
			current = current .. char
			i = i + 1
		end
	end
	local trimmed = current:match("^%s*(.-)%s*$")
	if trimmed ~= "" then
		table.insert(result, trimmed)
	end
	return result
end

---Convert filetypes to glob pattern
---@param filetypes_str string
---@return string|nil
local function filetypes_to_glob(filetypes_str)
	if not filetypes_str or filetypes_str == "" then
		return nil
	end
	local types = parse_csv(filetypes_str)
	if #types == 0 then
		return nil
	end
	if #types == 1 then
		return "**/*." .. types[1]
	end
	return "**/*.{" .. table.concat(types, ",") .. "}"
end

---Convert glob to filetypes string
---@param glob string|nil
---@return string
local function glob_to_filetypes(glob)
	if not glob then
		return ""
	end
	-- Parse **/*.{lua,ts,js} or **/*.lua
	local multi = glob:match("%*%*/%*%.{(.+)}")
	if multi then
		return multi:gsub(",", ", ")
	end
	local single = glob:match("%*%*/%*%.(.+)")
	if single then
		return single
	end
	return ""
end

---Run preview search
---@param patterns_str string
---@param filetypes_str string
---@param is_regex boolean
---@param cwd string
---@return string[]
local function run_preview(patterns_str, filetypes_str, is_regex, cwd)
	local patterns = parse_csv(patterns_str)
	if #patterns == 0 then
		return { "(no pattern)" }
	end

	local glob = filetypes_to_glob(filetypes_str)
	local all_files = {}
	local seen = {}

	for _, pattern in ipairs(patterns) do
		local files = grep.find_files(pattern, glob, cwd, is_regex)
		for _, file in ipairs(files) do
			if not seen[file] then
				seen[file] = true
				-- Make relative
				local display = file
				if file:sub(1, #cwd) == cwd then
					display = file:sub(#cwd + 2)
				end
				table.insert(all_files, display)
			end
		end
	end

	if #all_files == 0 then
		return { "(no matches)" }
	end

	table.sort(all_files)
	return all_files
end

---Open the query editor
---@param query table { pattern: string, glob: string|nil, regex: boolean|nil }
---@param cwd string
---@param on_save fun(data: { pattern: string, filetypes: string, regex: boolean })
function M.open(query, cwd, on_save)
	local is_regex = query.regex or false
	local pattern_str = query.pattern or ""
	local filetypes_str = glob_to_filetypes(query.glob)

	local current_panel = 1 -- 1=pattern, 2=filetypes, 3=preview (readonly)
	local panels = {}

	-- Pattern panel
	panels.pattern = Popup({
		border = {
			style = "rounded",
			text = {
				top = " Pattern [" .. (is_regex and "regex" or "literal") .. "] ",
				top_align = "left",
			},
		},
		focusable = true,
		buf_options = {
			modifiable = true,
			filetype = "vdir_pattern",
		},
	})

	-- Filetypes panel
	panels.filetypes = Popup({
		border = {
			style = "rounded",
			text = {
				top = " File Types ",
				top_align = "left",
			},
		},
		focusable = true,
		buf_options = {
			modifiable = true,
			filetype = "vdir_filetypes",
		},
	})

	-- Preview panel (read-only, not focusable)
	panels.preview = Popup({
		border = {
			style = "rounded",
			text = {
				top = " Preview ",
				top_align = "left",
				bottom = " <CR> save │ <Esc> cancel │ <C-r> toggle regex ",
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
				width = 60,
				height = 20,
			},
		},
		Layout.Box({
			Layout.Box(panels.pattern, { size = 3 }),
			Layout.Box(panels.filetypes, { size = 3 }),
			Layout.Box(panels.preview, { grow = 1 }),
		}, { dir = "col" })
	)

	-- Update preview with debounce
	local update_preview = debounce(function()
		local pat = vim.api.nvim_buf_get_lines(panels.pattern.bufnr, 0, 1, false)[1] or ""
		local ft = vim.api.nvim_buf_get_lines(panels.filetypes.bufnr, 0, 1, false)[1] or ""
		local results = run_preview(pat, ft, is_regex, cwd)

		vim.api.nvim_set_option_value("modifiable", true, { buf = panels.preview.bufnr })
		vim.api.nvim_buf_set_lines(panels.preview.bufnr, 0, -1, false, results)
		vim.api.nvim_set_option_value("modifiable", false, { buf = panels.preview.bufnr })

		-- Update preview title with count
		local count = #results
		if results[1] == "(no pattern)" or results[1] == "(no matches)" then
			count = 0
		end
		panels.preview.border:set_text("top", " Preview (" .. count .. " matches) ", "left")
	end, M.config.debounce_ms)

	-- Update mode indicator
	local function update_mode_indicator()
		panels.pattern.border:set_text("top", " Pattern [" .. (is_regex and "regex" or "literal") .. "] ", "left")
	end

	-- Focus management (only pattern and filetypes are focusable)
	local panel_order = { "pattern", "filetypes" }

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

	-- Save function
	local function save()
		-- Read all lines and join (in case of accidental newlines)
		local pat_lines = vim.api.nvim_buf_get_lines(panels.pattern.bufnr, 0, -1, false)
		local ft_lines = vim.api.nvim_buf_get_lines(panels.filetypes.bufnr, 0, -1, false)
		local pat = table.concat(pat_lines, " "):match("^%s*(.-)%s*$") or ""
		local ft = table.concat(ft_lines, " "):match("^%s*(.-)%s*$") or ""
		vim.cmd("stopinsert")
		layout:unmount()
		on_save({
			pattern = pat,
			filetypes = ft,
			regex = is_regex,
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
	vim.api.nvim_buf_set_lines(panels.pattern.bufnr, 0, -1, false, { pattern_str })
	vim.api.nvim_buf_set_lines(panels.filetypes.bufnr, 0, -1, false, { filetypes_str })

	-- Initial preview
	update_preview()

	-- Setup keymaps for focusable panels only
	for _, name in ipairs(panel_order) do
		local popup = panels[name]
		local opts = { noremap = true, nowait = true }

		-- Navigation
		vim.keymap.set({ "n", "i" }, "<Tab>", next_panel, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))
		vim.keymap.set({ "n", "i" }, "<S-Tab>", prev_panel, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))

		-- Close
		vim.keymap.set("n", "q", close, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))
		vim.keymap.set({ "n", "i" }, "<Esc>", close, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))

		-- Save (Enter works in both normal and insert mode)
		vim.keymap.set({ "n", "i" }, "<CR>", save, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))
		vim.keymap.set({ "n", "i" }, "<C-s>", save, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))

		-- Toggle regex mode
		vim.keymap.set({ "n", "i" }, "<C-r>", function()
			is_regex = not is_regex
			update_mode_indicator()
			update_preview()
		end, vim.tbl_extend("force", opts, { buffer = popup.bufnr }))
	end

	-- Auto-update preview on text change
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = panels.pattern.bufnr,
		callback = update_preview,
	})
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = panels.filetypes.bufnr,
		callback = update_preview,
	})

	-- Focus pattern panel and enter insert mode
	focus_panel(1)
	vim.cmd("startinsert!")
end

return M
