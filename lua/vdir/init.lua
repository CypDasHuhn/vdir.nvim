local renderer = require("neo-tree.ui.renderer")
local cli = require("vdir.cli")
local unpack_fn = table.unpack or unpack

local M = {}

M.name = "vdir"
M.display_name = "Vdir"

local function join_vdir_path(parent, name)
	if parent == "~" then
		return "~/" .. name
	end
	return parent .. "/" .. name
end

local function resolve_output_path(cwd, output)
	if output:match("^%a:[/\\]") or output:match("^/") then
		return output
	end
	return vim.fs.normalize(vim.fs.joinpath(cwd, output))
end

local function resolve_virtual_path(cwd, marker)
	if marker == "~" then
		return cwd
	end

	local relative = marker:gsub("^~/?", "")
	local parts = { cwd, ".vdir" }
	for _, segment in ipairs(vim.split(relative, "/", { plain = true, trimempty = true })) do
		table.insert(parts, segment)
	end

	return vim.fs.normalize(vim.fs.joinpath(unpack_fn(parts)))
end

local function make_root(cwd)
	return {
		id = "root",
		name = "Root",
		type = "directory",
		path = cwd,
		extra = {
			is_root = true,
			marker = "~",
		},
		children = {},
	}
end

local function parse_tree(lines, cwd)
	local root = make_root(cwd)
	local stack = {
		[0] = root,
	}

	for _, line in ipairs(lines) do
		local leading = line:match("^(%s*)") or ""
		local depth = math.floor(#leading / 2)
		local content = line:sub(#leading + 1)
		local parent = stack[depth] or root
		local parent_marker = (parent.extra and parent.extra.marker) or "~"

		local folder_name = content:match("^d (.+)/ %(%d+ items%)$")
		if folder_name then
			local marker = join_vdir_path(parent_marker, folder_name)
			local node = {
				id = "folder:" .. marker,
				name = folder_name,
				type = "directory",
				path = resolve_virtual_path(cwd, marker),
				extra = {
					item_type = "folder",
					marker = marker,
					parent_marker = parent_marker,
					item_name = folder_name,
				},
				children = {},
			}
			table.insert(parent.children, node)
			stack[depth + 1] = node
		else
			local query_name = content:match("^q (.+) %(%d+ suppliers%)$")
			if query_name then
				local node = {
					id = "query:" .. parent_marker .. "::" .. query_name,
					name = query_name,
					type = "directory",
					path = resolve_virtual_path(cwd, join_vdir_path(parent_marker, query_name)),
					extra = {
						item_type = "query",
						is_query = true,
						parent_marker = parent_marker,
						query_name = query_name,
					},
					children = {},
				}
				table.insert(parent.children, node)
				stack[depth + 1] = node
			else
				local ref_name, target, target_kind = content:match("^r (.-) %-> (.-) %[(.)%]$")
				if ref_name then
					table.insert(parent.children, {
						id = "ref:" .. parent_marker .. "::" .. ref_name,
						name = ref_name,
						type = target_kind == "d" and "directory" or "file",
						path = target,
						extra = {
							item_type = "reference",
							parent_marker = parent_marker,
							item_name = ref_name,
							target = target,
						},
					})
				else
					local result_path = content:match("^f (.+)$")
					if result_path and parent.extra and parent.extra.is_query then
						table.insert(parent.children, {
							id = "result:" .. parent.id .. "::" .. result_path,
							name = result_path,
							type = "file",
							path = resolve_output_path(cwd, result_path),
							extra = {
								is_query_result = true,
							},
						})
					end
				end
			end
		end
	end

	return { root }
end

local function load_tree(cwd)
	return cli.with_marker(cwd, "~", function()
		return cli.run({ "ls", "-lr" }, { cwd = cwd })
	end)
end

local function render_message(state, message)
	renderer.show_nodes({
		{
			id = "message",
			name = message,
			type = "message",
		},
	}, state)
end

local function ensure_initialized(state, path, on_ready)
	local result, err = cli.run({ "pwd" }, { cwd = path })
	if result then
		on_ready()
		return
	end

	if not err or not err:match("No vdir found") then
		render_message(state, err or "Failed to load vdir tree")
		return
	end

	vim.ui.select({ "Yes", "No" }, {
		prompt = "No vdir found here. Create one?",
	}, function(choice)
		if choice ~= "Yes" then
			render_message(state, "No vdir found")
			return
		end

		local init_result, init_err = cli.run({ "init" }, { cwd = path })
		if not init_result then
			render_message(state, init_err or "Failed to initialize vdir")
			return
		end

		on_ready()
	end)
end

M.navigate = function(state, path)
	if path == nil then
		path = vim.fn.getcwd()
	end
	state.path = path

	ensure_initialized(state, path, function()
		local result, err = load_tree(path)
		local items
		if result then
			items = parse_tree(result.lines, path)
		else
			items = {
				{
					id = "error",
					name = err or "Failed to load vdir tree",
					type = "file",
				},
			}
		end

		renderer.show_nodes(items, state)
	end)
end

M.setup = function(_, _)
end

local disabled_keys = {
	"<C-b>", "<C-f>", "<C-r>", "<C-x>",
	"A", "C", "D", "H", "P", "R", "S",
	"[g", "]g",
	"b", "c", "d", "f", "i", "l", "m", "o",
	"oc", "od", "og", "om", "on", "os", "ot",
	"p", "q", "r", "s", "t", "w", "x", "y", "z",
}

local mappings = {}
for _, key in ipairs(disabled_keys) do
	mappings[key] = "none"
end

mappings["a"] = "add"
mappings["A"] = "add_folder"
mappings["d"] = "delete"
mappings["e"] = "edit"
mappings["r"] = "rename"

M.default_config = {
	window = {
		mappings = mappings,
	},
	renderers = {
		directory = {
			{ "indent" },
			{ "icon" },
			{ "name" },
		},
		file = {
			{ "indent" },
			{ "icon" },
			{ "name" },
		},
		message = {
			{ "indent", with_markers = false },
			{ "name", highlight = "NeoTreeMessage" },
		},
	},
}

return M
