local ui = require("vdir.ui")
local utils = require("vdir.commands.utils")

local M = {}

function M.delete(state)
	local node = state.tree:get_node()
	local ctx, err = utils.get_node_context(node)
	if not ctx then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	if ctx.item_type == "root" then
		vim.notify("Cannot delete Root", vim.log.levels.ERROR)
		return
	end

	local parent_marker = ctx.parent_marker
	local item_name = ctx.query_name or ctx.item_name or node.name
	if not parent_marker or not item_name then
		vim.notify("Could not determine delete target", vim.log.levels.ERROR)
		return
	end

	ui.cursor_input("Delete '" .. item_name .. "'? (y/n)", "", function(answer)
		if answer ~= "y" and answer ~= "Y" then
			return
		end

		local result = utils.run_at_marker_or_notify(state, parent_marker, {
			"rm",
			item_name,
		})
		if not result then
			return
		end

		vim.notify(result.stdout ~= "" and result.stdout or "item deleted", vim.log.levels.INFO)
		utils.refresh(state)
	end)
end

return M
