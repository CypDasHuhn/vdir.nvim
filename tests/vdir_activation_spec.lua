local helpers = require("_helpers")

describe("vdir activation", function()
	before_each(function()
		helpers.mock_cli()
		package.loaded["neo-tree.ui.renderer"] = {
			show_nodes = function() end,
		}
		package.loaded["vdir.init"] = nil
	end)

	after_each(function()
		helpers.restore_cli()
	end)

	describe("ensure_initialized", function()
		it("skips prompt when vdir is initialized (pwd succeeds)", function()
			local cli = require("vdir.cli")
			cli.run = function(args)
				if args[1] == "pwd" then
					return { stdout = "~", lines = { "~" } }, nil
				end
				if args[1] == "ls" then
					return { stdout = "", lines = {} }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			local select_called = false
			local saved_select = vim.ui.select
			vim.ui.select = function()
				select_called = true
			end

			local source = require("vdir.init")
			source.navigate({ path = "/tmp" })

			vim.ui.select = saved_select
			assert.is_false(select_called, "should not prompt when vdir is initialized")
		end)

		it("shows prompt when pwd fails with 'No vdir found'", function()
			local cli = require("vdir.cli")
			cli.run = function(args)
				if args[1] == "pwd" then
					return nil, "No vdir found"
				end
				if args[1] == "ls" then
					return { stdout = "", lines = {} }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			local prompt_shown = false
			local saved_select = vim.ui.select
			vim.ui.select = function(items, opts)
				prompt_shown = true
				assert.equals("Yes", items[1])
				assert.equals("No", items[2])
				assert.is_true(opts.prompt:match("Create") ~= nil)
			end

			local source = require("vdir.init")
			source.navigate({ path = "/tmp" })

			vim.ui.select = saved_select
			assert.is_true(prompt_shown, "should show create prompt when no vdir")
		end)

		it("choosing 'Yes' calls vdir init then loads tree", function()
			local cli = require("vdir.cli")
			local init_called = false
			local ls_called = false
			cli.run = function(args)
				if args[1] == "pwd" then
					return nil, "No vdir found"
				end
				if args[1] == "init" then
					init_called = true
					return { stdout = "vdir initialized", lines = { "vdir initialized" } }, nil
				end
				if args[1] == "ls" then
					ls_called = true
					return { stdout = "", lines = {} }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			local saved_select = vim.ui.select
			vim.ui.select = function(_, _, callback)
				callback("Yes")
			end

			local source = require("vdir.init")
			source.navigate({ path = "/tmp" })

			vim.ui.select = saved_select
			assert.is_true(init_called, "vdir init should be called when Yes is chosen")
			assert.is_true(ls_called, "tree should be loaded after init")
		end)

		it("choosing 'No' does NOT call vdir init", function()
			local cli = require("vdir.cli")
			local init_called = false
			cli.run = function(args)
				if args[1] == "pwd" then
					return nil, "No vdir found"
				end
				if args[1] == "init" then
					init_called = true
				end
				return { stdout = "", lines = {} }, nil
			end

			local saved_select = vim.ui.select
			vim.ui.select = function(_, _, callback)
				callback("No")
			end

			package.loaded["neo-tree.ui.renderer"] = {
				show_nodes = function() end,
			}

			package.loaded["vdir.init"] = nil
			local source = require("vdir.init")
			source.navigate({ path = "/tmp" })

			vim.ui.select = saved_select
			assert.is_false(init_called, "vdir init should NOT be called when No is chosen")
		end)

		it("shows message in panel when init fails", function()
			local cli = require("vdir.cli")
			cli.run = function(args)
				if args[1] == "pwd" then
					return nil, "No vdir found"
				end
				if args[1] == "init" then
					return nil, "Init failed: permission denied"
				end
				return { stdout = "", lines = {} }, nil
			end

			local saved_select = vim.ui.select
			vim.ui.select = function(_, _, callback)
				callback("Yes")
			end

			local rendered_message = nil
			package.loaded["neo-tree.ui.renderer"] = {
				show_nodes = function(nodes)
					if nodes[1] and nodes[1].type == "message" then
						rendered_message = nodes[1].name
					end
				end,
			}

			package.loaded["vdir.init"] = nil
			local source = require("vdir.init")
			source.navigate({ path = "/tmp" })

			vim.ui.select = saved_select
			assert.is_not_nil(rendered_message, "should render message when init fails")
			assert.is_true(rendered_message:match("Init failed") ~= nil)
		end)
	end)

	describe(":Vdir command", function()
		it("creates the :Vdir user command", function()
			local commands = {}
			local saved_create = vim.api.nvim_create_user_command
			vim.api.nvim_create_user_command = function(name, fn, opts)
				table.insert(commands, { name = name, has_fn = fn ~= nil })
			end

			package.loaded["vdir.cli"] = nil
			helpers.mock_cli()

			vim.cmd("runtime plugin/vdir.lua")

			local found = false
			for _, cmd in ipairs(commands) do
				if cmd.name == "Vdir" then
					found = true
					break
				end
			end

			vim.api.nvim_create_user_command = saved_create
			assert.is_true(found, ":Vdir command should be created")
		end)

		it("sets default keymap <leader>q", function()
			local maps = {}
			local saved_set = vim.keymap.set
			vim.keymap.set = function(mode, lhs, rhs, opts)
				table.insert(maps, { mode = mode, lhs = lhs, opts = opts })
			end

			package.loaded["vdir.cli"] = nil
			helpers.mock_cli()

			vim.cmd("runtime plugin/vdir.lua")

			local found = false
			for _, m in ipairs(maps) do
				if m.lhs == "<leader>q" then
					found = true
					break
				end
			end

			vim.keymap.set = saved_set
			assert.is_true(found, "<leader>q keymap should be set")
		end)
	end)
end)
