-- .config/nvim/lua/lsps.lua
--
-- LSP settings
--
-- NOTE: this will be sourced from: ~/.config/nvim/lua/plugins.lua
--
-- last update: 2024.08.02.

local M = {}

-- setup LSP settings
function M.setup(nvim_lsp, autoconfigurable_lsp_names)
  -- Register LSP handlers
  vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, { border = 'rounded' })
  vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = 'rounded' })

  local on_attach_lsp = function(client, bufnr) -- default setup for language servers
    -- Enable completion triggered by <c-x><c-o>
    vim.api.nvim_set_option_value('omnifunc', 'v:lua.vim.lsp.omnifunc', { buf = bufnr })

    -- See `:help vim.lsp.*` for documentation on any of the below functions
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, {
      remap = false,
      silent = true,
      desc = 'lsp: Declaration',
    })
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, {
      remap = false,
      silent = true,
      desc = 'lsp: Definition',
    })
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, {
      remap = false,
      silent = true,
      desc = 'lsp: Implementation',
    })
    vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, {
      remap = false,
      silent = true,
      desc = 'lsp: Type definition',
    })
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, {
      remap = false,
      silent = true,
      desc = 'lsp: Rename',
    })
    vim.keymap.set('n', '<leader>ca', '<cmd>lua require"actions-preview".code_actions()<CR>', {
      remap = false,
      silent = true,
      desc = 'lsp: Code action',
    })
    vim.keymap.set('n', '<leader>dl', '<cmd>lua vim.diagnostic.setloclist()<CR>', {
      remap = false,
      silent = true,
      desc = 'lsp: Diagnostics list',
    })
    vim.keymap.set('n', '<leader>fo', '<cmd>lua vim.lsp.buf.format {async = true}<CR>', {
      remap = false,
      silent = true,
      desc = 'lsp: Format',
    })
    vim.keymap.set('n', '<leader>li', '<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<CR>', {
      remap = false,
      silent = true,
      desc = 'lsp: Toggle inlay hint',
    })

    -- diagnostics configuration
    vim.diagnostic.config({
      underline = false,
      virtual_text = false,
      signs = true,
      severity_sort = true,
      update_in_insert = false,
      float = { border = 'rounded' },
    })
    vim.fn.sign_define('DiagnosticSignError', {
      text = '✗',
      texthl = 'DiagnosticSignError',
    })
    vim.fn.sign_define('DiagnosticSignWarn', {
      text = '!',
      texthl = 'DiagnosticSignWarn',
    })
    vim.fn.sign_define('DiagnosticSignInformation', {
      text = '',
      texthl = 'DiagnosticSignInfo',
    })
    vim.fn.sign_define('DiagnosticSignHint', {
      text = '',
      texthl = 'DiagnosticSignHint',
    })

    -- auto formatting on save
    if client.server_capabilities.document_formatting then
      vim.api.nvim_create_autocmd('BufWritePre', {
        callback = function() vim.lsp.buf.format { async = false } end,
      })
    end

    -- highlight current variable
    if client.server_capabilities.document_highlight then
      vim.api.nvim_set_hl(0, 'LspReferenceRead', { link = 'Visual' })
      vim.api.nvim_set_hl(0, 'LspReferenceText', { link = 'Visual' })
      vim.api.nvim_set_hl(0, 'LspReferenceWrite', { link = 'Visual' })
      vim.api.nvim_create_augroup('lsp_document_highlight', { clear = true })
      vim.api.nvim_create_autocmd('CursorHold', {
        group = 'lsp_document_highlight',
        callback = function() vim.lsp.buf.document_highlight() end,
      })
      vim.api.nvim_create_autocmd('CursorMoved', {
        group = 'lsp_document_highlight',
        callback = function() vim.lsp.buf.clear_references() end,
      })
    end

    -- navic
    if client.server_capabilities.documentSymbolProvider then
      require'nvim-navic'.attach(client, bufnr)
    end
  end
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities = require'cmp_nvim_lsp'.default_capabilities(capabilities)
  capabilities.textDocument.completion.completionItem.documentationFormat = { 'markdown', 'plaintext' }
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.preselectSupport = true
  capabilities.textDocument.completion.completionItem.insertReplaceSupport = true
  capabilities.textDocument.completion.completionItem.labelDetailsSupport = true
  capabilities.textDocument.completion.completionItem.deprecatedSupport = true
  capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
  capabilities.textDocument.completion.completionItem.tagSupport = { valueSet = { 1 } }
  capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = { 'documentation', 'detail', 'additionalTextEdits' },
  }
  local lsp_settings = {
    elixirls = {
      dialyzerEnabled = false,
      enableTestLenses = false,
    },
    gopls = {
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
    Lua = {
      runtime = { version = 'LuaJIT', path = (function()
        local runtime_paths = vim.split(package.path, ';')
        table.insert(runtime_paths, 'lua/?.lua')
        table.insert(runtime_paths, 'lua/?/init.lua')
        return runtime_paths
      end)() },
      diagnostics = { globals = { 'vim' } },
      workspace = {
        library = vim.api.nvim_get_runtime_file('', true),
        checkThirdParty = false,
      },
      telemetry = { enable = false },
    },
  }

  -------- automatic configuration with `lspconfig` --------
  for _, lsp in ipairs(autoconfigurable_lsp_names) do
    nvim_lsp[lsp].setup {
      on_attach = on_attach_lsp,
      capabilities = capabilities,
      settings = lsp_settings,
    }
  end

  -------- manual configurations here --------
  -- (rust)
  local mason_pkgs_dir = vim.env.HOME .. '/.local/share/nvim/mason/packages'
  require'rust-tools'.setup {
    tools = { hover_actions = { auto_focus = true } },
    server = {
      on_attach = on_attach_lsp,
      capabilities = capabilities,
      settings = {
        ['rust-analyzer'] = {
          checkOnSave = { enable = true, command = 'clippy' },
          cargo = { allFeatures = true },
        },
      },
    },
    dap = {
      -- install `codelldb` with :Mason
      -- :RustDebuggables for debugging
      adapter = require'rust-tools.dap'.get_codelldb_adapter(
      mason_pkgs_dir .. '/codelldb/extension/adapter/codelldb',
      mason_pkgs_dir .. '/codelldb/extension/lldb/lib/liblldb.so'
      ),
    },
  }
  vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = '*.rs',
    callback = function() vim.lsp.buf.format { async = false } end,
  })

end

return M

