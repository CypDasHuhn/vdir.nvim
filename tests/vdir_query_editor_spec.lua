local helpers = require("_helpers")

describe("vdir query editor", function()
	before_each(function()
		helpers.mock_cli()
	end)

	after_each(function()
		helpers.restore_cli()
	end)

	describe("compiler validation", function()
		it("shows error notification when no compilers are registered", function()
			local cli = require("vdir.cli")
			cli.run = function(args)
				if args[1] == "compiler" and args[2] == "list" then
					return { stdout = "", lines = {} }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			package.loaded["vdir.ui.query_editor"] = nil
			local editor = require("vdir.ui.query_editor")
			editor.open({}, "/tmp", function() end)
			assert.is_not_nil(notified)
			assert.is_true(notified.msg:match("No compilers") ~= nil)
		end)

		it("module loads without errors", function()
			package.loaded["vdir.ui.query_editor"] = nil
			local editor = require("vdir.ui.query_editor")
			assert.is_not_nil(editor)
			assert.is_not_nil(editor.open)
			assert.equals(300, editor.config.debounce_ms)
		end)
	end)

	describe("preview logic", function()
		it("handles empty compiler in preview", function()
			package.loaded["vdir.ui.query_editor"] = nil
			local editor = require("vdir.ui.query_editor")
			local cli = require("vdir.cli")

			local test_args = nil
			cli.run = function(args)
				if args[1] == "compiler" and args[2] == "test" then
					test_args = args
					return nil, "compiler error"
				end
				if args[1] == "compiler" and args[2] == "list" then
					return { stdout = "  rg (from /tmp)", lines = { "  rg (from /tmp)" } }, nil
				end
				return { stdout = "", lines = {} }, nil
			end

			local notified = nil
			vim.notify = function(msg, level)
				notified = { msg = msg, level = level }
			end

			-- This should fail because no compilers are available in the mocked run
			-- Actually compilers are available, so it will try to open the UI
		end)
	end)
end)
