# monkey-patched lua plugins here

For monkey-patching lua plugins, put lua files in this directory with content like:

```lua
return {
    "some/lua-plugin/that-needs-monkey-patch.nvim",
    init = function()
	-- do some monkey-patching here
    end,
}
```

