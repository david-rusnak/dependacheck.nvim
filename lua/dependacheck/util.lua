local M = {}

local Job = require("plenary.job")

--- Parse [dependencies] from Cargo.toml
--- @param bufnr number Buffer handle
--- @return table mapping crate names to version strings
function M.parse_dependencies(bufnr)
  local deps = {}
  local current_section

  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    -- detect section headers
    local sec = line:match("^%s*%[([^%]]+)%]")
    if sec then
      current_section = sec
    elseif
      current_section == "dependencies"
      or current_section == "dev-dependencies"
      or current_section == "build-dependencies"
      or current_section == "workspace.dependencies"
    then
      -- 1) simple form: serde = "1.0.188"
      local name, version = line:match('^%s*([%w_-]+)%s*=%s*"([^"]+)"')
      if name and version then
        deps[name] = version
      else
        -- 2) table form: foo = { version = "0.3", features = [...] }
        local tbl_name, tbl_body = line:match("^%s*([%w_-]+)%s*=%s*{(.-)}")
        if tbl_name and tbl_body then
          local v = tbl_body:match('version%s*=%s*"([^"]+)"')
          if v then
            deps[tbl_name] = v
          end
        end
      end
    end
  end
  return deps
end

--- Fetch the latest version from crates.io
--- @param crate string Crate name
--- @param cb function Callback called with version or nil
function M.get_latest_version(crate, cb)
  local url = "https://crates.io/api/v1/crates/" .. crate
  Job:new({
    command = "curl",
    args = { "-s", url },
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        return cb(nil)
      end
      vim.schedule(function()
        local ok, data = pcall(vim.fn.json_decode, table.concat(j:result(), ""))
        if not ok or not data or not data.crate then
          return cb(nil)
        end
        cb(data.crate.max_version)
      end)
    end,
  }):start()
end

--- Compare two semver strings: returns 1 if a>b, -1 if a<b, 0 if equal
--- @param a string Version A
--- @param b string Version B
--- @return number
function M.semver_compare(a, b)
  local function split(ver)
    local t = {}
    for num in ver:gmatch("(%d+)") do
      table.insert(t, tonumber(num))
    end
    return t
  end
  local ta, tb = split(a), split(b)
  local len = math.max(#ta, #tb)
  for i = 1, len do
    local na = ta[i] or 0
    local nb = tb[i] or 0
    if na > nb then
      return 1
    end
    if na < nb then
      return -1
    end
  end
  return 0
end

return M
