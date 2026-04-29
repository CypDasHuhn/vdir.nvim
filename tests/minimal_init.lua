local project_dir = "/home/cyp/repos/vdir.nvim"
local tests_dir = project_dir .. "/tests"

package.path = tests_dir .. "/?.lua;" .. tests_dir .. "/?/init.lua;" .. package.path

vim.opt.rtp:prepend("/home/cyp/.local/share/nvim/lazy/plenary.nvim")
vim.opt.rtp:prepend("/home/cyp/.local/share/nvim/lazy/neo-tree.nvim")
vim.opt.rtp:prepend("/home/cyp/.local/share/nvim/lazy/nui.nvim")
vim.opt.rtp:append(project_dir)

vim.cmd("runtime! plugin/**/*.lua")
vim.cmd("runtime! plugin/**/*.vim")
