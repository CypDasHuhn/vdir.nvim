local helpers = require("_helpers")

describe("vdir commands", function()
	local add_cmd, delete_cmd, edit_cmd

	before_each(function()
		helpers.mock_cli()
		package.loaded["neo-tree.sources.manager"] = {
			refresh = function() end,
		}
		package.loaded["neo-tree.ui.renderer"] = {
			show_nodes = function() end,
		}
		package.loaded["nui.input"] = {
			mount = function() end,
			map = function() end,
		}
		package.loaded["vdir.ui.query_editor"] = {
			open = function(_, _, on_save) on_save({ compiler = "rg", args = "--test" }) end,
		}
		package.loaded["vdir.ui"] = {
			cursor_input = function(title, default_value, on_submit)
				if title:match("Name") then
					on_submit("testitem/")
				elseif title:match("Folder") then
					on_submit("testfolder")
				elseif title:match("Delete") then
					on_submit("y")
				elseif title:match("Rename") then
					on_submit("newname")
				end
			end,
		}
		package.loaded["vdir.commands.add"] = nil
		package.loaded["vdir.commands.delete"] = nil
		package.loaded["vdir.commands.edit"] = nil
		package.loaded["vdir.commands.utils"] = nil
		add_cmd = require("vdir.commands.add")
		delete_cmd = require("vdir.commands.delete")
		edit_cmd = require("vdir.commands.edit")
	end)

	after_each(function()
		helpers.restore_cli()
	end)

	local function make_mock_tree_node(overrides)
		return vim.tbl_deep_extend("force", {
			name = "test",
			type = "file",
			extra = {},
		}, overrides or {})
	end

	local function make_mock_state(node)
		return {
			path = "/tmp/testdir",
			tree = {
				get_node = function()
					return node or make_mock_tree_node()
				end,
			},
		}
	end

	describe("a — Add item", function()
		it("errors when cursor is on a query node", function()
			local node = make_mock_tree_node({
				type = "directory",
				extra = { item_type = "query", marker = "~/myquery", is_query = true },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			add_cmd.add(state)
			assert.is_not_nil(notified)
			assert.is_true(notified.msg:match("[Ff]older") ~= nil)
		end)

		it("errors when cursor is on a reference node", function()
			local node = make_mock_tree_node({
				extra = { item_type = "reference" },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			add_cmd.add(state)
			assert.is_not_nil(notified)
		end)

		it("errors when cursor is on a query result node", function()
			local node = make_mock_tree_node({
				name = "/some/file.rs",
				type = "file",
				extra = { is_query_result = true },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			add_cmd.add(state)
			assert.is_not_nil(notified)
		end)

		it("creates a folder when name ends with /", function()
			local cli_run_called_with = nil
			local cli = require("vdir.cli")
			cli.run = function(args)
				if args[1] == "mkdir" then
					cli_run_called_with = args
				end
				if args[1] == "pwd" then
					return { stdout = "~", lines = { "~" } }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			local node = make_mock_tree_node({
				type = "directory",
				extra = { item_type = "folder", marker = "~" },
			})
			local state = make_mock_state(node)
			local refreshed = false
			package.loaded["neo-tree.sources.manager"] = {
				refresh = function() refreshed = true end,
			}

			add_cmd.add(state)
			assert.is_not_nil(cli_run_called_with)
			assert.equals("mkdir", cli_run_called_with[1])
			assert.equals("testitem", cli_run_called_with[2])
		end)

		it("creates a query when name does NOT end with /", function()
			local mkq_called_with = nil
			local cli = require("vdir.cli")
			cli.run = function(args)
				if args[1] == "mkq" then
					mkq_called_with = args
				end
				if args[1] == "pwd" then
					return { stdout = "~", lines = { "~" } }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			package.loaded["vdir.ui"] = {
				cursor_input = function(title, default_value, on_submit)
					on_submit("myquery")
				end,
			}
			package.loaded["vdir.ui.query_editor"] = {
				open = function(_, _, on_save) on_save({ compiler = "rg", args = "" }) end,
			}
			package.loaded["vdir.commands.add"] = nil
			add_cmd = require("vdir.commands.add")

			local node = make_mock_tree_node({
				type = "directory",
				extra = { item_type = "folder", marker = "~" },
			})
			local state = make_mock_state(node)

			add_cmd.add(state)
			assert.is_not_nil(mkq_called_with)
			assert.equals("mkq", mkq_called_with[1])
			assert.equals("myquery", mkq_called_with[2])
		end)
	end)

	describe("A — Add folder (explicit)", function()
		it("errors on query node", function()
			local node = make_mock_tree_node({
				type = "directory",
				extra = { item_type = "query", marker = "~/myquery" },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			add_cmd.add_folder(state)
			assert.is_not_nil(notified)
		end)

		it("errors on reference node", function()
			local node = make_mock_tree_node({
				extra = { item_type = "reference" },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			add_cmd.add_folder(state)
			assert.is_not_nil(notified)
		end)

		it("errors on query result node", function()
			local node = make_mock_tree_node({
				name = "/path/to/file.rs",
				type = "file",
				extra = { is_query_result = true },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			add_cmd.add_folder(state)
			assert.is_not_nil(notified)
		end)

		it("creates a folder on root node", function()
			local mkdir_called = false
			local cli = require("vdir.cli")
			cli.run = function(args)
				if args[1] == "mkdir" then
					mkdir_called = true
				end
				if args[1] == "pwd" then
					return { stdout = "~", lines = { "~" } }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			local node = make_mock_tree_node({
				type = "directory",
				extra = { is_root = true, marker = "~" },
			})
			local state = make_mock_state(node)
			local refreshed = false
			package.loaded["neo-tree.sources.manager"] = {
				refresh = function() refreshed = true end,
			}

			add_cmd.add_folder(state)
			assert.is_true(mkdir_called)
		end)
	end)

	describe("d — Delete", function()
		it("errors when deleting root node", function()
			local node = make_mock_tree_node({
				name = "Root",
				type = "directory",
				extra = { is_root = true },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			delete_cmd.delete(state)
			assert.is_not_nil(notified)
			assert.is_true(notified.msg:match("Root") ~= nil)
		end)

		it("errors when deleting query result node", function()
			local node = make_mock_tree_node({
				name = "/some/file.rs",
				type = "file",
				extra = { is_query_result = true },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			delete_cmd.delete(state)
			assert.is_not_nil(notified)
		end)

		it("calls vdir rm on a folder node", function()
			local rm_called = false
			local cli = require("vdir.cli")
			cli.run = function(args)
				if args[1] == "pwd" then
					return { stdout = "~", lines = { "~" } }, nil
				end
				if args[1] == "rm" then
					rm_called = true
				end
				return { stdout = "", lines = {} }, nil
			end

			local node = make_mock_tree_node({
				name = "myfolder",
				type = "directory",
				extra = { item_type = "folder", parent_marker = "~", item_name = "myfolder" },
			})
			local state = make_mock_state(node)
			local refreshed = false
			package.loaded["neo-tree.sources.manager"] = {
				refresh = function() refreshed = true end,
			}

			delete_cmd.delete(state)
			assert.is_true(rm_called)
		end)
	end)

	describe("r — Rename", function()
		it("errors when renaming root node", function()
			local node = make_mock_tree_node({
				type = "directory",
				extra = { is_root = true },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			edit_cmd.rename(state)
			assert.is_not_nil(notified)
			assert.is_true(notified.msg:match("Root") ~= nil)
		end)

		it("errors when renaming query result node", function()
			local node = make_mock_tree_node({
				name = "/some/file.rs",
				type = "file",
				extra = { is_query_result = true },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			edit_cmd.rename(state)
			assert.is_not_nil(notified)
		end)
	end)

	describe("e — Edit query", function()
		it("errors when cursor is on a folder node", function()
			local node = make_mock_tree_node({
				type = "directory",
				extra = { item_type = "folder", marker = "~/myfolder" },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			edit_cmd.edit(state)
			assert.is_not_nil(notified)
		end)

		it("errors when cursor is on a reference node", function()
			local node = make_mock_tree_node({
				extra = { item_type = "reference" },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			edit_cmd.edit(state)
			assert.is_not_nil(notified)
		end)

		it("errors when cursor is on a query result node", function()
			local node = make_mock_tree_node({
				type = "file",
				extra = { is_query_result = true },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			edit_cmd.edit(state)
			assert.is_not_nil(notified)
		end)

		it("errors when query has multiple named suppliers", function()
			local cli = require("vdir.cli")
			cli.run = function(args)
				if args[1] == "pwd" then
					return { stdout = "~", lines = { "~" } }, nil
				end
				if args[1] == "info" then
					return { stdout = table.concat(helpers.sample_query_info_multi_suppliers(), "\n"), lines = helpers.sample_query_info_multi_suppliers() }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			local node = make_mock_tree_node({
				type = "directory",
				extra = { item_type = "query", is_query = true, parent_marker = "~", query_name = "myquery" },
			})
			local state = make_mock_state(node)
			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			edit_cmd.edit(state)
			assert.is_not_nil(notified)
		end)
	end)

	describe("get_node_context()", function()
		local utils

		before_each(function()
			package.loaded["vdir.commands.utils"] = nil
			utils = require("vdir.commands.utils")
		end)

		it("returns error for nil node", function()
			local ctx, err = utils.get_node_context(nil)
			assert.is_nil(ctx)
			assert.equals("No node selected", err)
		end)

		it("returns root context for root node", function()
			local ctx, err = utils.get_node_context({
				extra = { is_root = true },
			})
			assert.is_not_nil(ctx)
			assert.equals("root", ctx.item_type)
			assert.equals("~", ctx.marker)
		end)

		it("returns error for query result nodes", function()
			local ctx, err = utils.get_node_context({
				extra = { is_query_result = true },
			})
			assert.is_nil(ctx)
		end)

		it("returns extra table for regular nodes", function()
			local extra = { item_type = "folder", marker = "~/myfolder" }
			local ctx, err = utils.get_node_context({
				extra = extra,
			})
			assert.is_not_nil(ctx)
			assert.equals(extra, ctx)
		end)
	end)
end)
