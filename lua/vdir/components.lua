local common = require("neo-tree.sources.common.components")
local highlights = require("neo-tree.ui.highlights")

local M = {}

M.icon = function(config, node, state)
	local icon = config.default or " "
	local padding = config.padding or " "
	local highlight = config.highlight or highlights.FILE_ICON

	if node.type == "directory" then
		highlight = highlights.DIRECTORY_ICON

		-- Check if this is a query with no results
		if node.extra and node.extra.is_query then
			local children = node.children or {}
			if #children == 0 then
				-- Empty query - use empty folder icon
				icon = ""
				return {
					text = icon .. padding,
					highlight = highlights.DIM_TEXT,
				}
			end
		end

		if node:is_expanded() then
			icon = config.folder_open or ""
		else
			icon = config.folder_closed or ""
		end
	elseif node.type == "file" then
		local success, web_devicons = pcall(require, "nvim-web-devicons")
		if success then
			local devicon, hl = web_devicons.get_icon(node.name, node.ext)
			icon = devicon or icon
			highlight = hl or highlight
		end
	end

	return {
		text = icon .. padding,
		highlight = highlight,
	}
end

return vim.tbl_deep_extend("force", common, M)
