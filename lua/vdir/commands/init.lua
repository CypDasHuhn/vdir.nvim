local cc = require("neo-tree.sources.common.commands")
local add = require("vdir.commands.add")
local delete = require("vdir.commands.delete")
local edit = require("vdir.commands.edit")
local utils = require("vdir.commands.utils")

local M = {}

-- Add commands
M.add = add.add
M.add_folder = add.add_folder

-- Delete commands
M.delete = delete.delete

-- Edit commands
M.edit = edit.edit
M.rename = edit.rename
M.view_query = edit.view_query -- backward compat

-- Utility commands
M.refresh = utils.refresh

-- Add common neo-tree commands
cc._add_common_commands(M)

return M
