-- .config/nvim/lua/tools.lua
--
-- My neovim tools
--
-- last update: 2023.01.17.

local function file_exists(path)
   local f = io.open(path, 'r')
   return f ~= nil and io.close(f)
end

local function shell_execute(command)
  local handle = io.popen(command)
---@diagnostic disable-next-line: need-check-nil
  local result = handle:read('*a')
---@diagnostic disable-next-line: need-check-nil
  handle:close()
  return result
end

-- Returns total memory (in kB)
local function physical_memory()
  local meminfo = '/proc/meminfo'
  if file_exists(meminfo) then
    -- $ grep "MemTotal" /proc/meminfo | grep -oE '[0-9]+'
    local memory = shell_execute('grep "MemTotal" ' .. meminfo .. ' | grep -oE "[0-9]+"')
    memory = memory:gsub('%s+', '')
    if string.len(memory) > 0 then
      return tonumber(memory)
    end
  end
  return -1 -- when it has no proper `/proc/meminfo` file (eg. macOS machine)
end

-- export things
return {
  -- if it is not macOS, or has > 4GB physical memory,
  is_low_perf_machine = function()
    local memory = physical_memory()
    if memory < 0 or memory > 4 * 1024 * 1024 then
      return false
    end
    vim.notify('Running on a machine with low performance.', vim.log.levels.WARN)
    return true
  end,
}

