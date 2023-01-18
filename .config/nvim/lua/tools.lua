-- .config/nvim/lua/tools.lua
--
-- My neovim utility functions
--
-- last update: 2023.01.18.

-- Checks if given `path` is executable or not
local function executable(path)
  return vim.fn.executable(path) == 1
end

-- Checks if given `path` exists or not
local function exists(path)
   local f = io.open(path, 'r')
   return f ~= nil and io.close(f)
end

-- Runs given `command` and returns the result
local function shell_execute(command)
  local handle = io.popen(command)
---@diagnostic disable-next-line: need-check-nil
  local result = handle:read('*a')
---@diagnostic disable-next-line: need-check-nil
  handle:close()
  return result
end

-- Returns total memory (in kB)
local function total_memory()
  local meminfo = '/proc/meminfo'
  if exists(meminfo) then
    -- $ grep "MemTotal" /proc/meminfo | grep -oE '[0-9]+'
    local memory = shell_execute('grep "MemTotal" ' .. meminfo .. ' | grep -oE "[0-9]+"')
    memory = memory:gsub('%s+', '')
    if string.len(memory) > 0 then
      return tonumber(memory)
    end
  end
  return -1 -- when it has no proper `/proc/meminfo` file (eg. macOS machine)
end

-- Checks if this machine will work with low performance
-- (if it is not macOS and has < 4GB memory)
local function low_performance()
  local memory = total_memory()
  if memory < 0 or memory >= 4 * 1024 * 1024 then
    return false
  end
  vim.notify('Running on a machine with low performance.', vim.log.levels.WARN)
  return true
end

-- export things
return {
  -- functions for managing file system
  fs = {
    executable = executable,
    exists = exists,
  },

  -- functions for managing the machine
  machine = {
    low_perf = low_performance,
  },

  -- for debugging
  d = function(something)
    vim.notify(vim.inspect(something), vim.log.levels.DEBUG)
  end,
  i = function(something)
    vim.notify(vim.inspect(something), vim.log.levels.INFO)
  end,
}

