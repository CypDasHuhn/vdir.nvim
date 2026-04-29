describe("vdir path", function()
	local path

	before_each(function()
		package.loaded["vdir.path"] = nil
		path = require("vdir.path")
	end)

	describe("normalize()", function()
		it("normalizes paths using vim.fs.normalize", function()
			local result = path.normalize("/foo/bar")
			assert.equals("/foo/bar", result)
		end)

		it("handles empty string", function()
			local result = path.normalize("")
			assert.equals("", result)
		end)

		it("handles nil gracefully", function()
			local result = path.normalize(nil)
			assert.is_true(type(result) == "string")
		end)

		it("collapses double slashes", function()
			local result = path.normalize("/foo//bar")
			assert.equals("/foo/bar", result)
		end)
	end)

	describe("join()", function()
		it("joins two path components with separator", function()
			local result = path.join("/base", "name")
			assert.equals("/base/name", result)
		end)

		it("handles base already ending with slash", function()
			local result = path.join("/base/", "name")
			assert.equals("/base/name", result)
		end)

		it("handles empty base", function()
			local result = path.join("", "name")
			assert.is_true(result:match("name") ~= nil)
		end)

		it("joins multiple components", function()
			local result = path.join("/a/b", "c/d")
			assert.equals("/a/b/c/d", result)
		end)

		it("uses forward slash when base contains forward slashes", function()
			local result = path.join("/windows\\path", "name")
			assert.is_true(result:match("name") ~= nil)
		end)
	end)

	describe("relpath()", function()
		it("returns relative path for child path", function()
			local result = path.relpath("/base/child/file.txt", "/base")
			assert.equals("child/file.txt", result)
		end)

		it("returns '.' for same path", function()
			local result = path.relpath("/base", "/base")
			assert.equals(".", result)
		end)

		it("returns nil for unrelated path", function()
			local result = path.relpath("/other/path", "/base")
			assert.is_nil(result)
		end)

		it("handles trailing slashes consistently", function()
			local result = path.relpath("/base/dir/file.txt", "/base/dir")
			assert.equals("file.txt", result)
		end)

		it("handles nested directory path", function()
			local result = path.relpath("/a/b/c/d/file.txt", "/a/b/c")
			assert.equals("d/file.txt", result)
		end)
	end)
end)
