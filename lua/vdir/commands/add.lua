local ui = require("vdir.ui")
local query_editor = require("vdir.ui.query_editor")
local utils = require("vdir.commands.utils")

local M = {}

local function get_parent_marker(node)
	if not node then
		return "~"
	end

	local ctx, err = utils.get_node_context(node)
	if not ctx then
		return nil, err
	end

	if ctx.item_type == "root" or ctx.item_type == "folder" then
		return ctx.marker
	end

	return nil, "Select a folder to add items"
end

local function create_folder(state, marker, name)
	local result = utils.run_at_marker_or_notify(state, marker, { "mkdir", name })
	if not result then
		return
	end
	vim.notify(result.stdout ~= "" and result.stdout or "folder created", vim.log.levels.INFO)
	utils.refresh(state)
end

local function create_query(state, marker, name)
	local cwd = utils.get_cwd(state)

	query_editor.open({}, cwd, function(data)
		local compiler = data.compiler
		local args = data.args or ""

		-- Create query with compiler
		local mkq_cmd = { "mkq", name, compiler }
		if args ~= "" then
			table.insert(mkq_cmd, args)
		end

		local result = utils.run_at_marker_or_notify(state, marker, mkq_cmd)
		if not result then
			return
		end

		vim.notify(result.stdout ~= "" and result.stdout or "query created", vim.log.levels.INFO)
		utils.refresh(state)
	end)
end

function M.add(state)
	local node = state.tree:get_node()
	local marker, err = get_parent_marker(node)
	if not marker then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	ui.cursor_input("Name (end with / for folder)", "", function(value)
		if value == "" then
			return
		end

		if value:sub(-1) == "/" then
			create_folder(state, marker, value:sub(1, -2))
			return
		end

		create_query(state, marker, value)
	end)
end

function M.add_folder(state)
	local node = state.tree:get_node()
	local marker, err = get_parent_marker(node)
	if not marker then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	ui.cursor_input("Folder name", "", function(name)
		if name == "" then
			return
		end
		create_folder(state, marker, name)
	end)
end

local function create_reference(state, marker, path)
	local result = utils.run_at_marker_or_notify(state, marker, { "ln", path })
	if not result then
		return
	end
	vim.notify(result.stdout ~= "" and result.stdout or "reference created", vim.log.levels.INFO)
	utils.refresh(state)
end

function M.add_reference(state)
	local node = state.tree:get_node()
	local marker, err = get_parent_marker(node)
	if not marker then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	ui.path_input("Reference path", vim.fn.expand("%:p"), function(path)
		create_reference(state, marker, path)
	end)
end

return M
