describe("util", function()
  local util = require("dependacheck.util")
  
  describe("parse_dependencies", function()
    local function create_test_buffer(content)
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))
      return bufnr
    end
    
    it("parses simple dependencies", function()
      local content = [[
[dependencies]
serde = "1.0.188"
tokio = "1.32.0"
]]
      local bufnr = create_test_buffer(content)
      local deps = util.parse_dependencies(bufnr)
      
      assert.equals("1.0.188", deps.serde)
      assert.equals("1.32.0", deps.tokio)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    
    it("parses table format dependencies", function()
      local content = [[
[dependencies]
tokio = { version = "1.32.0", features = ["full"] }
clap = { version = "4.0", default-features = false }
]]
      local bufnr = create_test_buffer(content)
      local deps = util.parse_dependencies(bufnr)
      
      assert.equals("1.32.0", deps.tokio)
      assert.equals("4.0", deps.clap)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    
    it("parses dev-dependencies", function()
      local content = [[
[dev-dependencies]
mockito = "0.31"
criterion = "0.5"
]]
      local bufnr = create_test_buffer(content)
      local deps = util.parse_dependencies(bufnr)
      
      assert.equals("0.31", deps.mockito)
      assert.equals("0.5", deps.criterion)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    
    it("parses build-dependencies", function()
      local content = [[
[build-dependencies]
cc = "1.0"
bindgen = "0.65"
]]
      local bufnr = create_test_buffer(content)
      local deps = util.parse_dependencies(bufnr)
      
      assert.equals("1.0", deps.cc)
      assert.equals("0.65", deps.bindgen)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    
    it("parses workspace.dependencies", function()
      local content = [[
[workspace.dependencies]
serde = "1.0"
tokio = "1.32"
]]
      local bufnr = create_test_buffer(content)
      local deps = util.parse_dependencies(bufnr)
      
      assert.equals("1.0", deps.serde)
      assert.equals("1.32", deps.tokio)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    
    it("handles mixed formats and sections", function()
      local content = [[
[dependencies]
serde = "1.0.188"
tokio = { version = "1.32.0", features = ["full"] }

[dev-dependencies]
mockito = "0.31"

[build-dependencies]
cc = { version = "1.0", features = ["parallel"] }
]]
      local bufnr = create_test_buffer(content)
      local deps = util.parse_dependencies(bufnr)
      
      assert.equals("1.0.188", deps.serde)
      assert.equals("1.32.0", deps.tokio)
      assert.equals("0.31", deps.mockito)
      assert.equals("1.0", deps.cc)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    
    it("ignores non-dependency sections", function()
      local content = [[
[package]
name = "test"
version = "0.1.0"

[dependencies]
serde = "1.0"

[features]
default = ["full"]
]]
      local bufnr = create_test_buffer(content)
      local deps = util.parse_dependencies(bufnr)
      
      assert.equals("1.0", deps.serde)
      assert.is_nil(deps.name)
      assert.is_nil(deps.version)
      assert.is_nil(deps.default)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    
    it("handles empty sections", function()
      local content = [[
[dependencies]

[dev-dependencies]
]]
      local bufnr = create_test_buffer(content)
      local deps = util.parse_dependencies(bufnr)
      
      assert.same({}, deps)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    
    it("handles crate names with hyphens and underscores", function()
      local content = [[
[dependencies]
serde_json = "1.0"
async-trait = "0.1"
tokio-util = { version = "0.7" }
]]
      local bufnr = create_test_buffer(content)
      local deps = util.parse_dependencies(bufnr)
      
      assert.equals("1.0", deps.serde_json)
      assert.equals("0.1", deps["async-trait"])
      assert.equals("0.7", deps["tokio-util"])
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
  
  describe("semver_compare", function()
    it("compares equal versions", function()
      assert.equals(0, util.semver_compare("1.0.0", "1.0.0"))
      assert.equals(0, util.semver_compare("2.5.3", "2.5.3"))
    end)
    
    it("compares patch versions", function()
      assert.equals(1, util.semver_compare("1.0.1", "1.0.0"))
      assert.equals(-1, util.semver_compare("1.0.0", "1.0.1"))
      assert.equals(1, util.semver_compare("2.5.10", "2.5.9"))
    end)
    
    it("compares minor versions", function()
      assert.equals(1, util.semver_compare("1.1.0", "1.0.0"))
      assert.equals(-1, util.semver_compare("1.0.0", "1.1.0"))
      assert.equals(1, util.semver_compare("2.10.0", "2.9.0"))
    end)
    
    it("compares major versions", function()
      assert.equals(1, util.semver_compare("2.0.0", "1.0.0"))
      assert.equals(-1, util.semver_compare("1.0.0", "2.0.0"))
      assert.equals(1, util.semver_compare("10.0.0", "9.99.99"))
    end)
    
    it("handles partial versions", function()
      assert.equals(0, util.semver_compare("1.0", "1.0.0"))
      assert.equals(0, util.semver_compare("1.0.0", "1.0"))
      assert.equals(1, util.semver_compare("1.1", "1.0.9"))
      assert.equals(-1, util.semver_compare("1.0", "1.0.1"))
    end)
    
    it("handles single digit versions", function()
      assert.equals(0, util.semver_compare("1", "1.0.0"))
      assert.equals(1, util.semver_compare("2", "1.9.9"))
      assert.equals(-1, util.semver_compare("1", "2"))
    end)
    
    it("handles versions with pre-release tags", function()
      -- The current implementation extracts ALL numeric parts
      -- So "1.0.0-rc1" becomes [1, 0, 0, 1] vs "1.0.0" becomes [1, 0, 0]
      assert.equals(1, util.semver_compare("1.0.0-rc1", "1.0.0"))  -- rc1 has extra "1"
      -- "1.0.0-alpha" and "1.0.0-beta" both have no numbers after hyphen
      assert.equals(0, util.semver_compare("1.0.0-alpha", "1.0.0-beta"))
      -- But if the numeric parts differ, that takes precedence
      assert.equals(1, util.semver_compare("1.0.1-alpha", "1.0.0"))
    end)
  end)
  
  describe("get_latest_version", function()
    it("handles successful API response", function(done)
      -- Mock the Job module
      local Job = require("plenary.job")
      local original_new = Job.new
      
      Job.new = function(self, opts)
        -- Create a mock job object
        local mock_job = {
          start = function()
            -- Simulate successful API response
            vim.defer_fn(function()
              opts.on_exit({
                result = function()
                  return {
                    '{"crate":{"max_version":"1.0.195"}}'
                  }
                end
              }, 0)
            end, 10)
          end
        }
        return mock_job
      end
      
      util.get_latest_version("serde", function(version)
        assert.equals("1.0.195", version)
        Job.new = original_new
        done()
      end)
    end)
    
    it("handles network failure", function(done)
      local Job = require("plenary.job")
      local original_new = Job.new
      
      Job.new = function(self, opts)
        local mock_job = {
          start = function()
            vim.defer_fn(function()
              opts.on_exit({ result = function() return {} end }, 1)
            end, 10)
          end
        }
        return mock_job
      end
      
      util.get_latest_version("serde", function(version)
        assert.is_nil(version)
        Job.new = original_new
        done()
      end)
    end)
    
    it("handles malformed JSON response", function(done)
      local Job = require("plenary.job")
      local original_new = Job.new
      
      Job.new = function(self, opts)
        local mock_job = {
          start = function()
            vim.defer_fn(function()
              opts.on_exit({
                result = function()
                  return { "not valid json" }
                end
              }, 0)
            end, 10)
          end
        }
        return mock_job
      end
      
      util.get_latest_version("serde", function(version)
        assert.is_nil(version)
        Job.new = original_new
        done()
      end)
    end)
    
    it("handles missing crate data", function(done)
      local Job = require("plenary.job")
      local original_new = Job.new
      
      Job.new = function(self, opts)
        local mock_job = {
          start = function()
            vim.defer_fn(function()
              opts.on_exit({
                result = function()
                  return { '{"error":"Not found"}' }
                end
              }, 0)
            end, 10)
          end
        }
        return mock_job
      end
      
      util.get_latest_version("nonexistent-crate", function(version)
        assert.is_nil(version)
        Job.new = original_new
        done()
      end)
    end)
  end)
end)