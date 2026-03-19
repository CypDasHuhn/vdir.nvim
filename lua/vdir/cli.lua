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
	}

	local in_suppliers = false
	local in_cmd_map = false
	local current_supplier = nil

	for _, line in ipairs(lines) do
		local expr = line:match("^expr:%s*(.*)$")
		if expr then
			info.expr = expr == "(empty)" and "" or expr
		elseif line:match("^suppliers:%s*$") then
			in_suppliers = true
			in_cmd_map = false
			current_supplier = nil
		elseif in_suppliers then
			-- Supplier name (2 spaces indent)
			local supplier_name = line:match("^  ([^:]+):%s*$")
			if supplier_name then
				current_supplier = supplier_name
				info.suppliers[current_supplier] = {
					name = current_supplier,
					cmd_map = {},
					cmd_map_order = {},
				}
				table.insert(info.supplier_order, current_supplier)
				in_cmd_map = false
			elseif current_supplier then
				-- Supplier properties (4 spaces indent)
				local scope = line:match("^    scope:%s*(.*)$")
				if scope then
					info.suppliers[current_supplier].scope = scope
					in_cmd_map = false
				end

				local compiler = line:match("^    compiler:%s*(.*)$")
				if compiler then
					info.suppliers[current_supplier].compiler = compiler
					in_cmd_map = false
				end

				local args = line:match("^    args:%s*(.*)$")
				if args then
					info.suppliers[current_supplier].args = args
					in_cmd_map = false
				end

				local raw = line:match("^    raw:%s*(.*)$")
				if raw then
					info.suppliers[current_supplier].raw = raw == "true"
					in_cmd_map = false
				end

				if line:match("^    cmd:%s*$") then
					-- Start of cmd map (empty after colon)
					in_cmd_map = true
				elseif in_cmd_map then
					-- Shell command entry (6 spaces indent)
					local shell_name, shell_cmd = line:match("^      ([^:]+):%s*(.*)$")
					if shell_name and shell_cmd then
						info.suppliers[current_supplier].cmd_map[shell_name] = shell_cmd
						table.insert(info.suppliers[current_supplier].cmd_map_order, shell_name)
					else
						-- No longer in cmd map if line doesn't match
						in_cmd_map = false
					end
				end
			end
		end
	end

	info.supplier_count = #info.supplier_order
	if info.supplier_count > 0 then
		info.default_supplier = info.suppliers._default
	else
		info.default_supplier = nil
	end

	return info
end

return M
