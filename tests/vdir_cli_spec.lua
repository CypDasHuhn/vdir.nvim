local helpers = require("_helpers")

describe("vdir cli", function()
	local cli

	before_each(function()
		package.loaded["vdir.cli"] = nil
		cli = require("vdir.cli")
	end)

	after_each(function()
		helpers.restore_cli()
	end)

	describe("binary resolution", function()
		it("vim.g.vdir_cli_cmd overrides the default binary lookup", function()
			vim.g.vdir_cli_cmd = "/custom/path/vdir"
			local cmd = nil
			local ok = pcall(function()
				local result = cli.run({ "ls" })
				cmd = result
			end)
			vim.g.vdir_cli_cmd = nil
		end)

		it("returns nil with error when CLI not found", function()
			local saved_executable = vim.fn.executable
			vim.fn.executable = function()
				return 0
			end

			local result, err = cli.run({ "ls" })
			assert.is_nil(result)
			assert.equals("vdir CLI not found in PATH", err)

			vim.fn.executable = saved_executable
		end)
	end)

	describe("parse_query_info()", function()
		it("parses an empty query (no suppliers)", function()
			local info = cli.parse_query_info(helpers.sample_query_info_no_suppliers())
			assert.equals("", info.expr)
			assert.equals(0, info.supplier_count)
			assert.is_nil(info.default_supplier)
		end)

		it("parses a default supplier with compiler and args", function()
			local info = cli.parse_query_info(helpers.sample_query_info_default())
			assert.equals("", info.expr)
			assert.equals("rg", info.default_supplier.compiler)
			assert.equals("--fixed-strings 'TODO'", info.default_supplier.args)
			assert.equals(".", info.default_supplier.scope)
		end)

		it("parses a named supplier with raw command", function()
			local info = cli.parse_query_info(helpers.sample_query_info_named_suppliers())
			assert.equals(1, info.supplier_count)
			assert.is_nil(info.default_supplier)
			assert.is_not_nil(info.suppliers["custom_sh"])
			assert.is_true(info.suppliers["custom_sh"].raw)
			assert.equals("find . -name '*.rs'", info.suppliers["custom_sh"].cmd_map["bash"])
		end)

		it("parses multiple suppliers", function()
			local info = cli.parse_query_info(helpers.sample_query_info_multi_suppliers())
			assert.equals(2, info.supplier_count)
			assert.is_not_nil(info.default_supplier)
			assert.is_not_nil(info.suppliers["custom_sh"])
		end)

		it("handles supplier names correctly", function()
			local lines = {
				"suppliers:",
				"  _default:",
				"    scope: .",
				"    compiler: rg",
			}
			local info = cli.parse_query_info(lines)
			assert.equals(1, info.supplier_count)
			assert.equals("_default", info.supplier_order[1])
		end)
	end)

	describe("with_marker()", function()
		it("switches marker if different from current", function()
			local calls = {}
			local saved_run = cli.run
			cli.run = function(args, opts)
				table.insert(calls, { args = args, opts = opts })
				if args[1] == "pwd" then
					return { stdout = "~/original", lines = { "~/original" } }, nil
				end
				if args[1] == "cd" then
					return { stdout = "", lines = {} }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			local fn_called = false
			local result, err = cli.with_marker("/tmp", "~/target", function()
				fn_called = true
				return "ok", nil
			end)

			assert.is_true(fn_called)
			assert.equals("ok", result)

			local cd_calls = {}
			for _, c in ipairs(calls) do
				if c.args[1] == "cd" then
					table.insert(cd_calls, c.args[2])
				end
			end
			assert.equals("~/target", cd_calls[1])
			assert.equals("~/original", cd_calls[2])

			cli.run = saved_run
		end)

		it("skips switching if marker already matches", function()
			local calls = {}
			local saved_run = cli.run
			cli.run = function(args, opts)
				table.insert(calls, { args = args })
				if args[1] == "pwd" then
					return { stdout = "~/target", lines = { "~/target" } }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			local fn_called = false
			cli.with_marker("/tmp", "~/target", function()
				fn_called = true
				return "ok"
			end)

			assert.is_true(fn_called)
			for _, c in ipairs(calls) do
				assert.is_not_equal("cd", c.args[1])
			end

			cli.run = saved_run
		end)

		it("restores marker even if the function errors", function()
			local calls = {}
			local saved_run = cli.run
			cli.run = function(args)
				table.insert(calls, args[1])
				if args[1] == "pwd" then
					return { stdout = "~/original", lines = { "~/original" } }, nil
				end
				if args[1] == "cd" then
					return { stdout = "", lines = {} }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			local ok, err = pcall(function()
				cli.with_marker("/tmp", "~/target", function()
					error("function error")
				end)
			end)

			local cd_restore_count = 0
			for _, c in ipairs(calls) do
				if c == "cd" then
					cd_restore_count = cd_restore_count + 1
				end
			end
			assert.equals(2, cd_restore_count)

			cli.run = saved_run
		end)
	end)
end)
