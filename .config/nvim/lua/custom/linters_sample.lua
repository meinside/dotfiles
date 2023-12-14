-- .config/nvim/lua/custom/linters_sample.lua
--
-- sample linter list
--
-- (duplicate this file to: ~/.config/nvim/lua/custom/linters.lua
-- and edit it)
--
-- last update: 2023.12.14.

-- following linters will be configured automatically
-- in: .config/nvim/lua/plugins.lua
return {
  --clojure = { 'clj-kondo' },
  --cmake = { 'cmakelint' },
  --fennel = { 'fennel' },
  go = { 'golangcilint' },
  --janet = { 'janet' },
  --lua = { 'luacheck' },
  markdown = { 'vale' },
  --ruby = { 'rubocop' },
  sh = { 'shellcheck' },
}
