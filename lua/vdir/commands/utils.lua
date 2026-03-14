local manager = require("neo-tree.sources.manager")
local cli = require("vdir.cli")

local M = {}

function M.get_cwd(state)
	return state.path or vim.fn.getcwd()
end

function M.refresh(state)
	manager.refresh("vdir", state)
end

function M.get_node_context(node)
	if not node then
		return nil, "No node selected"
	end

	local extra = node.extra or {}
	if extra.is_root then
		return {
			item_type = "root",
			marker = "~",
		}
	end

	if extra.is_query_result then
		return nil, "Cannot modify query result files"
	end

	return extra, nil
end

function M.run_at_marker(state, marker, args)
	local cwd = M.get_cwd(state)
	return cli.with_marker(cwd, marker, function()
		return cli.run(args, { cwd = cwd })
	end)
end

function M.run_at_marker_or_notify(state, marker, args)
	local result, err = M.run_at_marker(state, marker, args)
	if not result then
		vim.notify(err or "vdir command failed", vim.log.levels.ERROR)
		return nil
	end
	return result
end

function M.run_sequence_at_marker(state, marker, command_list)
	local cwd = M.get_cwd(state)
	return cli.with_marker(cwd, marker, function()
		local last_result = nil
		for _, args in ipairs(command_list) do
			local result, err = cli.run(args, { cwd = cwd })
			if not result then
				return nil, err
			end
			last_result = result
		end
		return last_result
	end)
end

function M.run_sequence_at_marker_or_notify(state, marker, command_list)
	local result, err = M.run_sequence_at_marker(state, marker, command_list)
	if not result then
		vim.notify(err or "vdir command failed", vim.log.levels.ERROR)
		return nil
	end
	return result
end

function M.read_query_info(state, parent_marker, query_name)
	local result, err = M.run_at_marker(state, parent_marker, { "info", query_name })
	if not result then
		return nil, err
	end
	return cli.parse_query_info(result.lines), nil
end

return M
