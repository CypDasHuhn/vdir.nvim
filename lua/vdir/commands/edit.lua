local ui = require("vdir.ui")
local query_editor = require("vdir.ui.query_editor")
local utils = require("vdir.commands.utils")

local M = {}

local function get_editable_supplier(info)
	if not info then
		return nil, "Could not read query info"
	end

	if info.supplier_count == 0 then
		return {
			scope = ".",
			cmd_map = {},
			cmd_map_order = {},
		}, nil
	end

	if info.default_supplier then
		return {
			scope = info.default_supplier.scope or ".",
			compiler = info.default_supplier.compiler,
			args = info.default_supplier.args,
			raw = info.default_supplier.raw,
			cmd_map = info.default_supplier.cmd_map or {},
			cmd_map_order = info.default_supplier.cmd_map_order or {},
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

	local cwd = utils.get_cwd(state)

	query_editor.open({
		compiler = query_data.compiler or "",
		args = query_data.args or "",
	}, cwd, function(data)
		local compiler = data.compiler
		local args = data.args or ""

		-- Delete and recreate the query with new compiler/args
		local commands = {
			{ "rm", ctx.query_name },
		}

		local mkq_cmd = { "mkq", ctx.query_name, compiler }
		if args ~= "" then
			table.insert(mkq_cmd, args)
		end
		table.insert(commands, mkq_cmd)

		local result = utils.run_sequence_at_marker_or_notify(state, ctx.parent_marker, commands)
		if not result then
			return
		end

		vim.notify(result.stdout ~= "" and result.stdout or "query updated", vim.log.levels.INFO)
		utils.refresh(state)
	end)
end

M.view_query = M.edit

return M
