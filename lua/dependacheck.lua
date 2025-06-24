-- ~/.config/nvim/lua/dependacheck/init.lua
local M = {}
local util = require("util")

-- create a namespace for virtual text
local ns = vim.api.nvim_create_namespace("Dependacheck")

local function clear_annotations(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

--- Setup function: registers command and autocmds
--- @param opts table? Optional config table
function M.setup(opts)
  opts = opts or {}
  print("Dependacheck setup called with options:", opts)

  -- user command to force a check
  vim.api.nvim_create_user_command("Dependacheck", function()
    M.check_updates()
  end, {})

  -- autocmd group for Cargo.toml
  vim.api.nvim_create_augroup("Dependacheck", { clear = true })
  vim.api.nvim_create_autocmd({ "BufRead", "BufWritePost" }, {
    group = "Dependacheck",
    pattern = "Cargo.toml",
    callback = function()
      M.check_updates()
    end,
  })
end

--- Checks each dependency and annotates if an update is available
function M.check_updates()
  local bufnr = vim.api.nvim_get_current_buf()
  clear_annotations(bufnr)

  local deps = util.parse_dependencies(bufnr)
  for name, cur_version in pairs(deps) do
    util.get_latest_version(name, function(latest)
      if latest and util.semver_compare(latest, cur_version) == 1 then
        -- find the line number of this dependency
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        for i, line in ipairs(lines) do
          if line:match('^%s*"' .. name .. '"%s*=') or line:match("^%s*" .. name .. "%s*=") then
            vim.schedule(function()
              vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
                virt_text = { { " " .. latest .. "  🆙", "ErrorMsg" } },
                virt_text_pos = "eol",
              })
            end)
            break
          end
        end
      end
    end)
  end
end

return M
