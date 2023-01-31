-- .config/nvim/lua/tools.lua
--
-- My neovim utility functions
--
-- last update: 2023.01.31.

-- Checks if given `path` is executable or not
local function is_executable(path)
  return vim.fn.executable(path) == 1
end

-- Checks if given `path` exists or not
local function file_exists(path)
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

-- Check if given `port` is opened or not
local function is_port_opened(port)
  if is_executable('lsof') then
    local listen = shell_execute('lsof -i:' .. tostring(port) .. ' | grep LISTEN')
    return string.len(listen) > 0
  end
  return false
end

-- Returns total memory (in kB)
local function total_memory()
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
    executable = is_executable,
    exists = file_exists,
  },

  -- functions for managing the machine
  system = {
    low_perf = low_performance,
    port_opened = is_port_opened,
  },

  -- functions for manaing shell/commands
  shell = {
    execute = shell_execute,
  },

  -- for debugging
  d = function(something)
    vim.notify(vim.inspect(something), vim.log.levels.DEBUG)
  end,
  e = function(something)
    vim.notify(vim.inspect(something), vim.log.levels.ERROR)
  end,
  i = function(something)
    vim.notify(vim.inspect(something), vim.log.levels.INFO)
  end,
}

