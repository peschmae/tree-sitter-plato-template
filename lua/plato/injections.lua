local M = {}
local overrides = {}
local initialized = false

local function host(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local override = overrides[bufnr]
  if override ~= nil then
    return override or nil
  end
  local lower = name:lower()
  if lower:match('%.ya?ml$') then
    return 'yaml'
  end
  if lower:match('%.sh$') or lower:match('%.bash$') then
    return 'bash'
  end
  local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
  local interpreter = first:match('^#!%s*(%S+)')
  local env_arg = first:match('^#!%s*%S-/env%s+%-S%s+(%S+)') or first:match('^#!%s*%S-/env%s+(%S+)')
  if interpreter and (interpreter:match('/bash$') or interpreter:match('/sh$')) then
    return 'bash'
  end
  if env_arg == 'bash' or env_arg == 'sh' then
    return 'bash'
  end
end

function M.set_host(bufnr, language)
  assert(language == nil or language == 'yaml' or language == 'bash' or language == false, 'unsupported host')
  overrides[bufnr] = language
  local parser = vim.treesitter.get_parser(bufnr, 'plato', { error = false })
  if parser then
    parser:invalidate(true)
  end
end

function M.setup()
  if initialized then
    return
  end
  for _, name in ipairs({ 'highlights', 'injections' }) do
    local paths = vim.api.nvim_get_runtime_file('queries/' .. name .. '.scm', false)
    assert(#paths > 0, 'missing Plato query: ' .. name)
    vim.treesitter.query.set('plato', name, table.concat(vim.fn.readfile(paths[1]), '\n'))
  end
  vim.treesitter.query.add_predicate('plato-host?', function(_, _, bufnr, predicate)
    return type(bufnr) == 'number' and vim.api.nvim_buf_is_valid(bufnr) and host(bufnr) == predicate[3]
  end, { force = true })
  vim.api.nvim_create_autocmd('BufDelete', {
    callback = function(event)
      overrides[event.buf] = nil
    end,
  })
  initialized = true
end

return M
