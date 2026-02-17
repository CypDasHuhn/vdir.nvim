local common = require("neo-tree.sources.common.components")

local M = {}

-- Add any custom components here if needed

return vim.tbl_deep_extend("force", common, M)
