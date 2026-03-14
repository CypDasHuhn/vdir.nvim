local ui = require("vdir.ui")
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
	ui.show_query({
		cmd = "",
		scope = ".",
		shell_program = "",
		shell_execute_arg = "",
	}, function(data)
		local cmd = vim.trim(data.cmd or "")
		if cmd == "" then
			vim.notify("Command cannot be empty", vim.log.levels.ERROR)
			return
		end

		local scope = vim.trim(data.scope or "")
		if scope == "" then
			scope = "."
		end

		local shell_program = vim.trim(data.shell_program or "")
		local shell_execute_arg = vim.trim(data.shell_execute_arg or "")
		local commands = {
			{ "mkq", name, cmd },
		}

		if scope ~= "." then
			table.insert(commands, { "set", name, "scope", scope })
		end

		if shell_program ~= "" then
			local shell_cmd = { "set", name, "shell", shell_program }
			if shell_execute_arg ~= "" then
				table.insert(shell_cmd, shell_execute_arg)
			end
			table.insert(commands, shell_cmd)
		end

		local result = utils.run_sequence_at_marker_or_notify(state, marker, commands)
		if not result then
			return
		end

		vim.notify(result.stdout ~= "" and result.stdout or "query created", vim.log.levels.INFO)
		utils.refresh(state)
	end, { title = " New Query " })
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

return M
