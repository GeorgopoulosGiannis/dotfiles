-- `:checkhealth config`: verifies the Neovim version and external tools this config relies on.

local M = {}

local function check_version()
  local verstr = tostring(vim.version())
  if vim.version.ge(vim.version(), '0.12') then
    vim.health.ok(string.format("Neovim version is: '%s'", verstr))
  else
    vim.health.error(string.format("Neovim out of date: '%s'. This config needs >= 0.12 (vim.pack)", verstr))
  end
end

local function check_external_reqs()
  for _, exe in ipairs { 'git', 'make', 'unzip', 'rg' } do
    if vim.fn.executable(exe) == 1 then
      vim.health.ok(string.format("Found executable: '%s'", exe))
    else
      vim.health.warn(string.format("Could not find executable: '%s'", exe))
    end
  end
end

function M.check()
  vim.health.start 'config'
  vim.health.info('System Information: ' .. vim.inspect(vim.uv.os_uname()))
  check_version()
  check_external_reqs()
end

return M
