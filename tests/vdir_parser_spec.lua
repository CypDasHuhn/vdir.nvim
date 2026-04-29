local helpers = require("_helpers")

describe("vdir parser", function()
	local source

	before_each(function()
		package.loaded["neo-tree.ui.renderer"] = {
			show_nodes = function() end,
		}
		helpers.mock_cli()
		package.loaded["vdir.init"] = nil
		source = require("vdir.init")
	end)

	after_each(function()
		helpers.restore_cli()
	end)

	describe("parse_tree()", function()
		it("renders root node for empty output", function()
			local items = source.parse_tree({}, "/tmp")
			assert.equals(1, #items)
			local root = items[1]
			assert.equals("root", root.id)
			assert.equals("Root", root.name)
			assert.equals("directory", root.type)
			assert.is_true(root.extra.is_root)
			assert.equals("~", root.extra.marker)
			assert.equals(0, #root.children)
		end)

		it("renders an empty vdir with root and no children", function()
			local items = source.parse_tree({}, "/tmp")
			assert.equals(1, #items)
			assert.equals(0, #items[1].children)
		end)

		it("folders render as expandable directory nodes", function()
			local items = source.parse_tree(helpers.sample_ls_output(), "/tmp")
			local root = items[1]
			local projects = root.children[1]
			assert.equals("directory", projects.type)
			assert.equals("folder", projects.extra.item_type)
			assert.is_true(projects.children ~= nil)
		end)

		it("queries render as expandable directory nodes with is_query = true", function()
			local items = source.parse_tree(helpers.sample_ls_output(), "/tmp")
			local root = items[1]
			local projects = root.children[1]
			local todos = projects.children[2]
			assert.equals("directory", todos.type)
			assert.is_true(todos.extra.is_query)
			assert.equals("query", todos.extra.item_type)
		end)

		it("references pointing to files render as file nodes", function()
			local items = source.parse_tree(helpers.sample_ls_output(), "/tmp")
			local root = items[1]
			local readme = root.children[3]
			assert.equals("file", readme.type)
			assert.equals("reference", readme.extra.item_type)
			assert.equals("/home/user/README.md", readme.path)
		end)

		it("references pointing to directories render as directory nodes", function()
			local items = source.parse_tree(helpers.sample_ls_output(), "/tmp")
			local root = items[1]
			local dotfiles = root.children[2]
			assert.equals("directory", dotfiles.type)
			assert.equals("reference", dotfiles.extra.item_type)
			assert.equals("/home/user/.dotfiles", dotfiles.path)
		end)

		it("query results render as file nodes under their query node", function()
			local lines = {
				"q todos (1 suppliers)",
				"  f /home/user/work/main.rs",
				"  f /home/user/work/lib.rs",
			}
			local items = source.parse_tree(lines, "/tmp")
			local root = items[1]
			assert.equals(1, #root.children)
			local query = root.children[1]
			assert.equals(2, #query.children)
			for _, child in ipairs(query.children) do
				assert.equals("file", child.type)
				assert.is_true(child.extra.is_query_result)
			end
			assert.equals("/home/user/work/main.rs", query.children[1].path)
			assert.equals("/home/user/work/lib.rs", query.children[2].path)
		end)

		it("nested folders render at correct depth (2 spaces per level)", function()
			local lines = {
				"d Projects/ (2 items)",
				"  d Work/ (0 items)",
				"    d Deep/ (0 items)",
			}
			local items = source.parse_tree(lines, "/tmp")
			local root = items[1]
			assert.equals(1, #root.children)
			local projects = root.children[1]
			assert.equals("Projects", projects.name)
			assert.equals(1, #projects.children)
			local work = projects.children[1]
			assert.equals("Work", work.name)
			assert.equals(1, #work.children)
			local deep = work.children[1]
			assert.equals("Deep", deep.name)
			assert.equals(0, #deep.children)
		end)

		it("a query with no results has no child nodes", function()
			local lines = { "q emptyq (0 suppliers)" }
			local items = source.parse_tree(lines, "/tmp")
			local root = items[1]
			assert.equals(1, #root.children)
			local query = root.children[1]
			assert.equals("directory", query.type)
			assert.is_true(query.extra.is_query)
			assert.equals(0, #query.children)
		end)

		it("a folder with no children has an empty children table", function()
			local lines = { "d Empty/ (0 items)" }
			local items = source.parse_tree(lines, "/tmp")
			local root = items[1]
			assert.equals(1, #root.children)
			local folder = root.children[1]
			assert.equals("directory", folder.type)
			assert.equals("folder", folder.extra.item_type)
			assert.equals(0, #folder.children)
		end)

		it("parses the full sample ls output correctly", function()
			local items = source.parse_tree(helpers.sample_ls_output(), "/tmp")
			local root = items[1]
			assert.equals(3, #root.children)

			local projects = root.children[1]
			assert.equals("Projects", projects.name)
			assert.equals("directory", projects.type)
			assert.equals("folder", projects.extra.item_type)
			assert.equals(2, #projects.children)

			local work = projects.children[1]
			assert.equals("Work", work.name)
			assert.equals("directory", work.type)
			assert.equals("folder", work.extra.item_type)
			assert.equals(0, #work.children)

			local todos = projects.children[2]
			assert.equals("todos", todos.name)
			assert.equals("directory", todos.type)
			assert.equals("query", todos.extra.item_type)
			assert.is_true(todos.extra.is_query)
			assert.equals(2, #todos.children)
			assert.equals("/home/user/work/main.rs", todos.children[1].path)
			assert.equals("/home/user/work/lib.rs", todos.children[2].path)

			local dotfiles = root.children[2]
			assert.equals("dotfiles", dotfiles.name)
			assert.equals("directory", dotfiles.type)
			assert.equals("reference", dotfiles.extra.item_type)
			assert.equals("/home/user/.dotfiles", dotfiles.path)

			local readme = root.children[3]
			assert.equals("readme", readme.name)
			assert.equals("file", readme.type)
			assert.equals("reference", readme.extra.item_type)
			assert.equals("/home/user/README.md", readme.path)
		end)

		it("query results with absolute paths are not resolved", function()
			local lines = {
				"q myq (1 suppliers)",
				"  f /absolute/path.rs",
			}
			local items = source.parse_tree(lines, "/tmp/project")
			local root = items[1]
			local result = root.children[1].children[1]
			assert.equals("/absolute/path.rs", result.path)
		end)

		it("query results with relative paths are resolved against cwd", function()
			local lines = {
				"q myq (1 suppliers)",
				"  f relative/path.rs",
			}
			local items = source.parse_tree(lines, "/tmp/project")
			local root = items[1]
			local result = root.children[1].children[1]
			assert.is_true(result.path:match("/tmp/project/relative/path%.rs") ~= nil)
		end)

		it("folders get virtual path inside .vdir/ subdirectory", function()
			local lines = {
				"d Projects/ (1 items)",
				"  d Work/ (0 items)",
			}
			local items = source.parse_tree(lines, "/tmp")
			local root = items[1]
			local projects = root.children[1]
			assert.is_true(projects.path:match("/tmp/.vdir/Projects") ~= nil)
			local work = projects.children[1]
			assert.is_true(work.path:match("/tmp/.vdir/Projects/Work") ~= nil)
		end)

		it("references use the real filesystem path", function()
			local lines = { "r readme -> /real/path/file.txt [f]" }
			local items = source.parse_tree(lines, "/tmp")
			local root = items[1]
			local ref = root.children[1]
			assert.equals("/real/path/file.txt", ref.path)
		end)
	end)
end)
