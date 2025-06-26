describe("dependacheck", function()
  local dependacheck
  local original_curl_new
  
  before_each(function()
    -- Clear any existing modules
    package.loaded.dependacheck = nil
    package.loaded["dependacheck.util"] = nil
    
    -- Load the module fresh
    dependacheck = require("dependacheck")
    
    -- Mock plenary.job for API calls
    local Job = require("plenary.job")
    original_curl_new = Job.new
  end)
  
  after_each(function()
    -- Restore original Job.new
    if original_curl_new then
      require("plenary.job").new = original_curl_new
    end
    
    -- Clean up any test buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)
  
  describe("setup", function()
    it("creates the Dependacheck user command", function()
      dependacheck.setup()
      
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.Dependacheck)
    end)
    
    it("creates autocmds for Cargo.toml files", function()
      -- Clear any existing autocmds and commands first
      pcall(vim.api.nvim_del_augroup_by_name, "Dependacheck")
      pcall(vim.api.nvim_del_user_command, "Dependacheck")
      
      -- Reset the module to ensure clean state
      package.loaded.dependacheck = nil
      package.loaded["dependacheck.util"] = nil
      dependacheck = require("dependacheck")
      
      dependacheck.setup()
      
      -- Try both ways to get autocmds (API might differ between Neovim versions)
      local autocmds = vim.api.nvim_get_autocmds({
        group = "Dependacheck"
      })
      
      -- If empty, try with pattern
      if #autocmds == 0 then
        autocmds = vim.api.nvim_get_autocmds({
          pattern = "Cargo.toml"
        })
        -- Filter to only our group
        local filtered = {}
        for _, autocmd in ipairs(autocmds) do
          if autocmd.group_name == "Dependacheck" then
            table.insert(filtered, autocmd)
          end
        end
        autocmds = filtered
      end
      
      assert.is_true(#autocmds > 0, "No autocmds found for Dependacheck group")
      
      local has_bufread = false
      local has_bufwritepost = false
      
      for _, autocmd in ipairs(autocmds) do
        
        if autocmd.event == "BufRead" or autocmd.event == "BufReadPost" then
          has_bufread = true
        elseif autocmd.event == "BufWritePost" then
          has_bufwritepost = true
        end
        assert.equals("Cargo.toml", autocmd.pattern)
      end
      
      assert.is_true(has_bufread, "BufRead autocmd not found")
      assert.is_true(has_bufwritepost, "BufWritePost autocmd not found")
    end)
    
    it("accepts optional configuration", function()
      -- Simply test that setup accepts options without error
      local ok = pcall(function()
        dependacheck.setup({ custom_option = true })
      end)
      assert.is_true(ok, "Setup should accept custom options without error")
    end)
  end)
  
  describe("check_updates", function()
    local function create_cargo_toml(content)
      local bufnr = vim.api.nvim_create_buf(false, true)
      -- Use a unique name for each test buffer to avoid conflicts
      local unique_name = string.format("Cargo-%d.toml", bufnr)
      vim.api.nvim_buf_set_name(bufnr, unique_name)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))
      vim.api.nvim_set_current_buf(bufnr)
      return bufnr
    end
    
    local function mock_api_response(responses)
      local Job = require("plenary.job")
      Job.new = function(self, opts)
        local crate_name = opts.args[2]:match("/([^/]+)$")
        local mock_job = {
          start = function()
            vim.defer_fn(function()
              if responses[crate_name] then
                opts.on_exit({
                  result = function()
                    return {
                      string.format('{"crate":{"max_version":"%s"}}', responses[crate_name])
                    }
                  end
                }, 0)
              else
                opts.on_exit({ result = function() return {} end }, 1)
              end
            end, 10)
          end
        }
        return mock_job
      end
    end
    
    it("annotates dependencies with available updates", function(done)
      local content = [[
[dependencies]
serde = "1.0.180"
tokio = "1.32.0"
]]
      local bufnr = create_cargo_toml(content)
      
      mock_api_response({
        serde = "1.0.195",
        tokio = "1.35.1"
      })
      
      dependacheck.check_updates()
      
      -- Wait for async operations to complete
      vim.defer_fn(function()
        local ns = vim.api.nvim_create_namespace("Dependacheck")
        local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
        
        assert.equals(2, #extmarks)
        
        -- Check that extmarks are on the correct lines
        local serde_line = 1  -- 0-indexed
        local tokio_line = 2  -- 0-indexed
        
        local found_serde = false
        local found_tokio = false
        
        for _, extmark in ipairs(extmarks) do
          local line = extmark[2]
          local details = extmark[4]
          
          if line == serde_line then
            found_serde = true
            assert.is_not_nil(details.virt_text)
            assert.is_true(details.virt_text[1][1]:match("1%.0%.195"))
          elseif line == tokio_line then
            found_tokio = true
            assert.is_not_nil(details.virt_text)
            assert.is_true(details.virt_text[1][1]:match("1%.35%.1"))
          end
        end
        
        assert.is_true(found_serde)
        assert.is_true(found_tokio)
        
        done()
      end, 100)
    end)
    
    it("does not annotate up-to-date dependencies", function(done)
      local content = [[
[dependencies]
serde = "1.0.195"
]]
      local bufnr = create_cargo_toml(content)
      
      mock_api_response({
        serde = "1.0.195"
      })
      
      dependacheck.check_updates()
      
      vim.defer_fn(function()
        local ns = vim.api.nvim_create_namespace("Dependacheck")
        local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
        
        assert.equals(0, #extmarks)
        done()
      end, 100)
    end)
    
    it("handles table format dependencies", function(done)
      local content = [[
[dependencies]
tokio = { version = "1.32.0", features = ["full"] }
]]
      local bufnr = create_cargo_toml(content)
      
      mock_api_response({
        tokio = "1.35.1"
      })
      
      dependacheck.check_updates()
      
      vim.defer_fn(function()
        local ns = vim.api.nvim_create_namespace("Dependacheck")
        local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
        
        assert.equals(1, #extmarks)
        assert.equals(1, extmarks[1][2])  -- Line 1 (0-indexed)
        done()
      end, 100)
    end)
    
    it("clears previous annotations on re-check", function(done)
      local content = [[
[dependencies]
serde = "1.0.180"
]]
      local bufnr = create_cargo_toml(content)
      
      mock_api_response({
        serde = "1.0.195"
      })
      
      -- First check
      dependacheck.check_updates()
      
      vim.defer_fn(function()
        local ns = vim.api.nvim_create_namespace("Dependacheck")
        local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
        assert.equals(1, #extmarks)
        
        -- Update the buffer to have latest version
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          "[dependencies]",
          'serde = "1.0.195"'
        })
        
        -- Second check
        dependacheck.check_updates()
        
        vim.defer_fn(function()
          local extmarks2 = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
          assert.equals(0, #extmarks2)
          done()
        end, 100)
      end, 100)
    end)
    
    it("handles API failures gracefully", function(done)
      local content = [[
[dependencies]
nonexistent-crate = "0.1.0"
]]
      local bufnr = create_cargo_toml(content)
      
      mock_api_response({})  -- Empty responses = all fail
      
      dependacheck.check_updates()
      
      vim.defer_fn(function()
        local ns = vim.api.nvim_create_namespace("Dependacheck")
        local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
        
        -- Should not crash and should not add any annotations
        assert.equals(0, #extmarks)
        done()
      end, 100)
    end)
  end)
  
  describe("command integration", function()
    it("executes check_updates when :Dependacheck is called", function(done)
      dependacheck.setup()
      
      local check_called = false
      local original_check = dependacheck.check_updates
      dependacheck.check_updates = function()
        check_called = true
        original_check()
      end
      
      vim.cmd("Dependacheck")
      
      vim.defer_fn(function()
        assert.is_true(check_called)
        dependacheck.check_updates = original_check
        done()
      end, 50)
    end)
  end)
end)