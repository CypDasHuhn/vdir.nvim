local M = {}
local unpack_fn = table.unpack or unpack

local function trim(str)
	return (str or ""):gsub("%s+$", "")
end

local function resolve_command()
	if type(vim.g.vdir_cli_cmd) == "string" and vim.g.vdir_cli_cmd ~= "" then
		return vim.g.vdir_cli_cmd
	end
	if vim.fn.executable("vdir_cli") == 1 then
		return "vdir_cli"
	end
	if vim.fn.executable("vdir") == 1 then
		return "vdir"
	end
	return nil
end

function M.run(args, opts)
	local cmd = resolve_command()
	if not cmd then
		return nil, "vdir CLI not found in PATH"
	end

	opts = opts or {}
	local result = vim.system(vim.list_extend({ cmd }, args), {
		cwd = opts.cwd,
		text = true,
	}):wait()

	local stdout = trim(result.stdout)
	local stderr = trim(result.stderr)
	local output = stdout ~= "" and stdout or stderr

	if result.code ~= 0 then
		return nil, output
	end

	return {
		code = result.code,
		stdout = output,
		stderr = stderr,
		lines = output == "" and {} or vim.split(output, "\n", { plain = true }),
	}, nil
end

function M.run_or_notify(args, opts)
	local result, err = M.run(args, opts)
	if not result then
		vim.notify(err or "vdir command failed", vim.log.levels.ERROR)
		return nil
	end
	return result
end

function M.get_marker(cwd)
	local result, err = M.run({ "pwd" }, { cwd = cwd })
	if not result then
		return nil, err
	end
	return result.stdout ~= "" and result.stdout or "~"
end

function M.with_marker(cwd, marker, fn)
	local original, err = M.get_marker(cwd)
	if not original then
		return nil, err
	end

	local switched = false
	if original ~= marker then
		local _, cd_err = M.run({ "cd", marker }, { cwd = cwd })
		if cd_err then
			return nil, cd_err
		end
		switched = true
	end

	local ok, payload = xpcall(function()
		return { fn() }
	end, debug.traceback)

	local restore_err = nil
	if switched then
		local _, err_restore = M.run({ "cd", original }, { cwd = cwd })
		restore_err = err_restore
	end

	if not ok then
		return nil, payload
	end
	if restore_err then
		return nil, restore_err
	end

	return unpack_fn(payload)
end

function M.parse_query_info(lines)
	local info = {
		expr = "",
		suppliers = {},
		supplier_order = {},
		legacy = {
			scope = nil,
			cmd = nil,
			shell_program = nil,
			shell_execute_arg = nil,
		},
	}

	local in_suppliers = false
	local current_supplier = nil

	for _, line in ipairs(lines) do
		local expr = line:match("^expr:%s*(.*)$")
		if expr then
			info.expr = expr == "(empty)" and "" or expr
		elseif line:match("^suppliers:%s*$") then
			in_suppliers = true
			current_supplier = nil
		elseif in_suppliers then
			local supplier_name = line:match("^  ([^:]+):%s*$")
			if supplier_name then
				current_supplier = supplier_name
				info.suppliers[current_supplier] = { name = current_supplier }
				table.insert(info.supplier_order, current_supplier)
			elseif current_supplier then
				local scope = line:match("^    scope:%s*(.*)$")
				if scope then
					info.suppliers[current_supplier].scope = scope
				end

				local shell_program = line:match("^    shell%.program:%s*(.*)$")
				if shell_program then
					info.suppliers[current_supplier].shell_program = shell_program
				end

				local shell_execute_arg = line:match("^    shell%.execute_arg:%s*(.*)$")
				if shell_execute_arg then
					info.suppliers[current_supplier].shell_execute_arg = shell_execute_arg
				end

				local cmd = line:match("^    cmd:%s*(.*)$")
				if cmd then
					info.suppliers[current_supplier].cmd = cmd == "(empty)" and "" or cmd
				end
			end
		else
			local scope = line:match("^scope:%s*(.*)$")
			if scope then
				info.legacy.scope = scope
			end

			local shell_program = line:match("^shell%.program:%s*(.*)$")
			if shell_program then
				info.legacy.shell_program = shell_program
			end

			local shell_execute_arg = line:match("^shell%.execute_arg:%s*(.*)$")
			if shell_execute_arg then
				info.legacy.shell_execute_arg = shell_execute_arg
			end

			local cmd = line:match("^cmd:%s*(.*)$")
			if cmd then
				info.legacy.cmd = cmd == "(empty)" and "" or cmd
			end
		end
	end

	info.supplier_count = #info.supplier_order
	if info.supplier_count > 0 then
		info.default_supplier = info.suppliers._default
	elseif info.legacy.cmd ~= nil or info.legacy.scope ~= nil then
		info.default_supplier = {
			name = "_default",
			scope = info.legacy.scope or ".",
			cmd = info.legacy.cmd or "",
			shell_program = info.legacy.shell_program,
			shell_execute_arg = info.legacy.shell_execute_arg,
		}
	else
		info.default_supplier = nil
	end

	return info
end

return M
