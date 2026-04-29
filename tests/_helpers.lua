local _saved_cli = nil
local _saved_select = nil

local M = {}

function M.sample_ls_output()
	return {
		"d Projects/ (2 items)",
		"  d Work/ (0 items)",
		"  q todos (1 suppliers)",
		"    f /home/user/work/main.rs",
		"    f /home/user/work/lib.rs",
		"r dotfiles -> /home/user/.dotfiles [d]",
		"r readme -> /home/user/README.md [f]",
	}
end

function M.sample_output_with_hidden()
	return {
		"d Visible/ (1 items)",
		"  r .secret -> /tmp/secret [f]",
		"d .hidden/ (0 items)",
	}
end

function M.sample_empty_output()
	return {}
end

function M.sample_query_info_default()
	return {
		"expr: (empty)",
		"suppliers:",
		"  _default:",
		"    scope: .",
		"    compiler: rg",
		"    args: --fixed-strings 'TODO'",
	}
end

function M.sample_query_info_no_suppliers()
	return {
		"expr: (empty)",
		"suppliers:",
	}
end

function M.sample_query_info_named_suppliers()
	return {
		"expr: (empty)",
		"suppliers:",
		"  custom_sh:",
		"    scope: .",
		"    raw: true",
		"    cmd:",
		"      bash: find . -name '*.rs'",
	}
end

function M.sample_query_info_multi_suppliers()
	return {
		"expr: (empty)",
		"suppliers:",
		"  _default:",
		"    scope: .",
		"    compiler: rg",
		"  custom_sh:",
		"    scope: .",
		"    raw: true",
		"    cmd:",
		"      bash: find . -name '*.rs'",
	}
end

function M.mock_cli(overrides)
	local saved = require("vdir.cli")
	_saved_cli = saved

	local mock = vim.deepcopy(overrides or {})

	local stub = {
		run = mock.run or function(args, _)
			if args[1] == "pwd" then
				return { stdout = "~", lines = { "~" } }, nil
			end
			if args[1] == "ls" and args[2] == "-lr" then
				return { stdout = table.concat(M.sample_ls_output(), "\n"), lines = M.sample_ls_output() }, nil
			end
			if args[1] == "init" then
				return { stdout = "vdir initialized", lines = { "vdir initialized" } }, nil
			end
			if args[1] == "mkdir" then
				return { stdout = "folder created", lines = { "folder created" } }, nil
			end
			if args[1] == "rm" then
				return { stdout = "item deleted", lines = { "item deleted" } }, nil
			end
		if args[1] == "mv" then
			return { stdout = "item renamed", lines = { "item renamed" } }, nil
		end
		if args[1] == "ln" then
			return { stdout = "reference created", lines = { "reference created" } }, nil
		end
			if args[1] == "mkq" then
				return { stdout = "query created", lines = { "query created" } }, nil
			end
			if args[1] == "cd" then
				return { stdout = "", lines = {} }, nil
			end
			if args[1] == "info" then
				return { stdout = table.concat(M.sample_query_info_default(), "\n"), lines = M.sample_query_info_default() }, nil
			end
			if args[1] == "compiler" and args[2] == "list" then
				return { stdout = "  rg (from /tmp)", lines = { "  rg (from /tmp)" } }, nil
			end
			if args[1] == "compiler" and args[2] == "test" then
				return { stdout = "Compiler: rg\nOutput:\n  rg 'TODO' .\n  rg 'FIXME' .", lines = {
					"Compiler: rg", "Output:", "  rg 'TODO' .", "  rg 'FIXME' .",
				} }, nil
			end
			return { stdout = "", lines = {} }, nil
		end,

		run_or_notify = mock.run_or_notify or function(args, opts)
			return stub.run(args, opts)
		end,

		get_marker = mock.get_marker or function(_)
			return "~", nil
		end,

		with_marker = mock.with_marker or function(_, _marker, fn)
			return fn()
		end,

		parse_query_info = mock.parse_query_info or saved.parse_query_info,
	}

	package.loaded["vdir.cli"] = stub
	return stub
end

function M.restore_cli()
	if _saved_cli then
		package.loaded["vdir.cli"] = _saved_cli
		_saved_cli = nil
	end
end

function M.mock_vim_ui_select(option_index)
	local saved_select = vim.ui.select
	_saved_select = saved_select

	vim.ui.select = function(items, opts, callback)
		if option_index == "no_selection" then
			callback(nil)
		elseif option_index == "last" then
			callback(items[#items])
		else
			callback(items[option_index or 1])
		end
	end

	return function()
		vim.ui.select = saved_select
	end
end

function M.restore_vim_ui_select()
	if _saved_select then
		vim.ui.select = _saved_select
		_saved_select = nil
	end
end

return M
