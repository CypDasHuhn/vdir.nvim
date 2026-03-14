local ui = require("vdir.ui")
local utils = require("vdir.commands.utils")

local M = {}

local function get_editable_supplier(info)
	if not info then
		return nil, "Could not read query info"
	end

	if info.supplier_count == 0 then
		return {
			cmd = "",
			scope = ".",
			shell_program = "",
			shell_execute_arg = "",
		}, nil
	end

	if info.default_supplier then
		return {
			cmd = info.default_supplier.cmd or "",
			scope = info.default_supplier.scope or ".",
			shell_program = info.default_supplier.shell_program or "",
			shell_execute_arg = info.default_supplier.shell_execute_arg or "",
		}, nil
	end

	if info.supplier_count == 1 then
		return nil, "Query uses a named supplier and cannot be edited here yet"
	end

	return nil, "Query uses multiple suppliers and cannot be edited here yet"
end

function M.rename(state)
	local node = state.tree:get_node()
	local ctx, err = utils.get_node_context(node)
	if not ctx then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	if ctx.item_type == "root" then
		vim.notify("Cannot rename Root", vim.log.levels.ERROR)
		return
	end

	local current_name = ctx.query_name or ctx.item_name or node.name
	local parent_marker = ctx.parent_marker
	if not parent_marker then
		vim.notify("Could not determine parent folder", vim.log.levels.ERROR)
		return
	end

	ui.cursor_input("Rename", current_name, function(new_name)
		if new_name == "" or new_name == current_name then
			return
		end

		local result = utils.run_at_marker_or_notify(state, parent_marker, {
			"mv",
			current_name,
			new_name,
		})
		if not result then
			return
		end

		vim.notify(result.stdout ~= "" and result.stdout or "item renamed", vim.log.levels.INFO)
		utils.refresh(state)
	end)
end

function M.edit(state)
	local node = state.tree:get_node()
	local ctx, err = utils.get_node_context(node)
	if not ctx then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	if ctx.item_type ~= "query" then
		vim.notify("Select a query to edit", vim.log.levels.ERROR)
		return
	end

	local info, info_err = utils.read_query_info(state, ctx.parent_marker, ctx.query_name)
	if not info then
		vim.notify(info_err or "Could not read query info", vim.log.levels.ERROR)
		return
	end

	local query_data, query_err = get_editable_supplier(info)
	if not query_data then
		vim.notify(query_err, vim.log.levels.ERROR)
		return
	end

	ui.show_query(query_data, function(data)
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
			{ "set", ctx.query_name, "cmd", cmd },
			{ "set", ctx.query_name, "scope", scope },
		}

		if shell_program == "" then
			table.insert(commands, { "set", ctx.query_name, "shell", "clear" })
		else
			local shell_cmd = { "set", ctx.query_name, "shell", shell_program }
			if shell_execute_arg ~= "" then
				table.insert(shell_cmd, shell_execute_arg)
			end
			table.insert(commands, shell_cmd)
		end

		local result = utils.run_sequence_at_marker_or_notify(state, ctx.parent_marker, commands)
		if not result then
			return
		end

		vim.notify(result.stdout ~= "" and result.stdout or "query updated", vim.log.levels.INFO)
		utils.refresh(state)
	end, { title = " Edit Query " })
end

M.view_query = M.edit

return M
