vim.opt.runtimepath:prepend(vim.fn.getcwd())
for _, language in ipairs({ 'plato', 'yaml', 'bash' }) do
  local path = language == 'plato' and '/parser.so' or '/parser/' .. language .. '.so'
  vim.treesitter.language.add(language, { path = vim.fn.getcwd() .. path })
end
require('plato.injections').setup()

local query = assert(vim.treesitter.query.get('plato', 'injections'))
local highlights = assert(vim.treesitter.query.get('plato', 'highlights'))

local function capture(node, buf)
  return { range = { node:range() }, text = vim.treesitter.get_node_text(node, buf) }
end

local function check(name, source, expected, exact)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, vim.fn.getcwd() .. '/' .. name)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(source, '\n', { plain = true }))
  local parser = vim.treesitter.get_parser(buf, 'plato')
  local trees = parser:parse()
  assert(not trees[1]:root():has_error(), name .. ': template parse error')
  local delimiters = 0
  local delimiter_captures = {}
  for id, node in highlights:iter_captures(trees[1]:root(), buf, 0, -1) do
    if highlights.captures[id] == 'punctuation.bracket' then
      local item = capture(node, buf)
      delimiter_captures[#delimiter_captures + 1] = item
      if item.text:find('{{{', 1, true) then
        delimiters = delimiters + 1
      end
    end
  end
  assert(delimiters > 0, name .. ': missing template delimiter highlight')
  local matches = 0
  local injection_captures = {}
  for _, match, metadata in query:iter_matches(trees[1]:root(), buf, 0, -1) do
    if metadata['injection.language'] then
      assert(metadata['injection.language'] == expected, name .. ': wrong host match')
      for id, nodes in pairs(match) do
        assert(query.captures[id] == 'injection.content')
        for _, node in ipairs(nodes) do
          injection_captures[#injection_captures + 1] = capture(node, buf)
        end
      end
      matches = matches + 1
    end
  end
  if exact then
    assert(vim.deep_equal(injection_captures, exact.injections),
      name .. ': injection captures: ' .. vim.inspect(injection_captures))
    assert(vim.deep_equal(delimiter_captures, exact.delimiters),
      name .. ': delimiter captures: ' .. vim.inspect(delimiter_captures))
  end
  assert((matches > 0) == (expected ~= nil), name .. ': unexpected host injection count ' .. matches)
  parser:parse(true)
  local children = parser:children()
  assert((next(children) ~= nil) == (expected ~= nil), name .. ': child parser selection failed')
  if expected then
    assert(children[expected] and vim.tbl_count(children) == 1, name .. ': incorrect child language')
  end
  return buf
end

check('sample.yaml', 'name: "{{{ .Name }}}"\nnote: |\n  {{{ .Message }}}', 'yaml')
check('sample.sh', '#!/bin/bash\necho "${HOME}" "{{{ .Name }}}"\ncat <<EOF\n{{{.Message}}}\nEOF', 'bash')
check('trim.yaml', 'value: "{{{- .Name -}}}"\nblock: |\n  before\n  {{{/* note */}}}\n  after', 'yaml', {
  injections = {
    { range = { 0, 0, 0, 8 }, text = 'value: "' },
    { range = { 0, 23, 3, 2 }, text = '"\nblock: |\n  before\n  ' },
    { range = { 3, 18, 5, 0 }, text = '\n  after' },
  },
  delimiters = {
    { range = { 0, 8, 0, 13 }, text = '{{{- ' },
    { range = { 0, 19, 0, 23 }, text = '-}}}' },
    { range = { 3, 2, 3, 5 }, text = '{{{' },
    { range = { 3, 15, 3, 18 }, text = '}}}' },
  },
})
check('heredoc.sh', '#!/bin/bash\nprintf "%s" "{{{- .Name -}}}"\ncat <<EOF\nbegin {{{ .Value }}} end\nEOF', 'bash', {
  injections = {
    { range = { 0, 0, 1, 13 }, text = '#!/bin/bash\nprintf "%s" "' },
    { range = { 1, 28, 3, 6 }, text = '"\ncat <<EOF\nbegin ' },
    { range = { 3, 20, 5, 0 }, text = ' end\nEOF' },
  },
  delimiters = {
    { range = { 1, 13, 1, 18 }, text = '{{{- ' },
    { range = { 1, 24, 1, 28 }, text = '-}}}' },
    { range = { 3, 6, 3, 9 }, text = '{{{' },
    { range = { 3, 17, 3, 20 }, text = '}}}' },
  },
})
check('dash.sh', 'echo "{{{ .A }}}-{{{ .B }}}"', 'bash', {
  injections = {
    { range = { 0, 0, 0, 6 }, text = 'echo "' },
    { range = { 0, 16, 0, 17 }, text = '-' },
    { range = { 0, 27, 1, 0 }, text = '"' },
  },
  delimiters = {
    { range = { 0, 6, 0, 9 }, text = '{{{' },
    { range = { 0, 13, 0, 16 }, text = '}}}' },
    { range = { 0, 17, 0, 20 }, text = '{{{' },
    { range = { 0, 24, 0, 27 }, text = '}}}' },
  },
})
check('sample.txt', 'hello {{{ .Name }}}')
check('later.sh', 'echo "{{{ .Name }}}"', 'bash')
check('later.yaml', 'name: {{{ .Name }}}', 'yaml')
check('later.yml', 'name: {{{ .Name }}}', 'yaml')
check('another.bash', 'echo {{{ .Name }}}', 'bash')
check('script.unknown', '#!/usr/bin/env bash\necho {{{ .Name }}}', 'bash')
check('script2.unknown', '#!/usr/bin/env -S bash -e\necho {{{ .Name }}}', 'bash')
local overridden = check('custom.txt', 'name: {{{ .Name }}}')
require('plato.injections').set_host(overridden, 'yaml')
check('another.txt', 'plain {{{ .Name }}}')
local tree = vim.treesitter.get_parser(overridden, 'plato')
tree:parse(true)
assert(next(tree:children()) ~= nil, 'per-buffer override did not activate')
local disabled = check('disabled.yaml', 'name: {{{ .Name }}}', 'yaml')
require('plato.injections').set_host(disabled, false)
local disabled_parser = vim.treesitter.get_parser(disabled, 'plato')
disabled_parser:parse(true)
assert(next(disabled_parser:children()) == nil, 'host=false should disable injection')
require('plato.injections').set_host(disabled, nil)
disabled_parser:parse(true)
assert(disabled_parser:children().yaml, 'clearing override should restore YAML')
local edited = check('edited.txt', '#!/bin/bash\necho {{{ .Name }}}', 'bash')
vim.api.nvim_buf_set_lines(edited, 0, -1, false, { 'plain {{{ .Name }}}' })
local edited_parser = vim.treesitter.get_parser(edited, 'plato')
edited_parser:parse(true)
assert(next(edited_parser:children()) == nil, 'editing shebang did not remove host injection')

for _, host in ipairs({ 'yaml', 'bash' }) do
  local alias = 'plato_' .. host
  vim.treesitter.language.add(alias, { path = vim.fn.getcwd() .. '/parser.so', symbol_name = 'plato' })
  vim.treesitter.query.set(alias, 'highlights', table.concat(vim.fn.readfile('queries/highlights.scm'), '\n'))
  vim.treesitter.query.set(alias, 'injections',
    ('((text) @injection.content\n (#set! injection.language "%s")\n (#set! injection.combined))'):format(host))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, vim.fn.getcwd() .. '/alias.' .. (host == 'yaml' and 'yaml' or 'sh'))
  vim.api.nvim_buf_set_lines(buf, 0, -1, false,
    { host == 'yaml' and 'name: {{{ .Name }}}' or 'echo "{{{ .A }}}-{{{ .B }}}"' })
  local alias_parser = vim.treesitter.get_parser(buf, alias)
  local trees = alias_parser:parse(true)
  assert(alias_parser:children()[host] and vim.tbl_count(alias_parser:children()) == 1,
    'alias injection failed for ' .. alias)
  if host == 'bash' then
    local captured = {}
    local alias_query = assert(vim.treesitter.query.get(alias, 'injections'))
    for _, node in alias_query:iter_captures(trees[1]:root(), buf, 0, -1) do
      captured[#captured + 1] = vim.treesitter.get_node_text(node, buf)
    end
    assert(vim.deep_equal(captured, { 'echo "', '"' }), 'alias query unexpectedly captured Bash hyphen')
  end
end
check('standalone-after-alias.sh', 'echo "{{{ .A }}}-{{{ .B }}}"', 'bash')
print('Neovim Plato/YAML/Bash injections OK')
