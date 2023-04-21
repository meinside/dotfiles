-- .config/nvim/lua/locals/linters.sample.lua
--
-- sample linter list
--
-- (duplicate this file to: ~/.config/nvim/lua/locals/linters.lua
-- and edit it)
--
-- last update: 2023.04.21.

-- following linters will be configured automatically
-- in: .config/nvim/lua/plugins.lua
return {
  clojure = { 'clj-kondo' },
  cmake = { 'cmakelint' },
  fennel = { 'fennel' },
  go = { 'golangcilint' },
  janet = { 'janet' },
  lua = { 'luacheck' },
  markdown = { 'vale' },
  ruby = { 'rubocop' },
  sh = { 'shellcheck' },
}
