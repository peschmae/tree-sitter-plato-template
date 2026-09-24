# tree-sitter-plato

Plato's default `{{{` / `}}}` Go-template syntax, based on
[ngalaiko/tree-sitter-go-template](https://github.com/ngalaiko/tree-sitter-go-template)
(MIT; see `LICENSE`). The grammar is named `plato`, exports
`tree_sitter_plato`, and is generated with Tree-sitter CLI **0.25.8**
(parser ABI **15**). The checked-in C parser can be built without regenerating.
The previous Helm dialect and double-brace parser are not part of this fork.
Single and double opening braces are literal text.

## Native parser artifacts

The workflow builds and tests the checked-in source on pinned Node **22.16.0**,
Go **1.24.6**, and Tree-sitter CLI **0.25.8** (locked by `npm ci`). Its runner
matrix packages `tree-sitter-plato-linux-{amd64,arm64}.so` on Ubuntu 24.04
and `tree-sitter-plato-macos-{amd64,arm64}.dylib` on macOS 15. These are
per-runner **workflow artifacts**, not published releases. Windows `.dll`
packaging is not supported.

Run `sh scripts/package-parser.sh` from any directory for the current
supported platform. It builds from `src/parser.c` without regenerating the
grammar, checks the exported `tree_sitter_plato` symbol and ABI **15**, and
writes the shared library and `dist/SHA256SUMS`. Verify after downloading
an artifact from a workflow run:

```sh
cd dist
sha256sum -c SHA256SUMS    # Linux
# shasum -a 256 -c SHA256SUMS    # macOS
```

The checksum file contains a SHA-256 digest and the artifact's basename, so
the library and checksum must stay together. Only the native parser is
packaged; install YAML/Bash host parsers and queries separately. The checked-in
generated C and JSON files remain tracked, while `dist/` and local native
binaries are ignored. Pass the downloaded library's absolute path to
`vim.treesitter.language.add('plato', { path = artifact_path })`; aliases must
also specify `symbol_name = 'plato'`. ABI 15 loads in the tested Neovim 0.12 and
Tree-sitter 0.25 bindings; consumers must check their own runtime's parser
ABI compatibility. Ubuntu and macOS runner image tags do not freeze their
compiler/linker revisions, so compare an artifact against **its own**
checksum rather than assuming identical bytes across workflow runs. Linux
artifacts are built on Ubuntu 24.04; older libc distributions and older
macOS releases are not guaranteed compatible.

## Build and verify

From this directory:

```sh
npm ci                        # requires a C++ compiler for the Node binding
npm run build                  # regenerate parser and build the Node binding
npm test                       # Tree-sitter corpus, Go ABI/queries, Go template corpus
go test -v ./bindings/go        # also inventories sibling Plato fixtures if present
```

If only the CLI is needed and the Node binding cannot build, use
`npm ci --ignore-scripts`, then
`(cd node_modules/tree-sitter-cli && node install.js)` to install its
prebuilt CLI, followed by `./node_modules/.bin/tree-sitter test` and
`go test ./...`. The fixture test reads `../plato/_fixtures/input` without
rendering, decrypting, modifying, or logging file contents. It skips binary
`.gem` files, `.sops_enc`, symbolic links, `.symlink` markers, and their companion files; when
the reference checkout is absent it skips the inventory test. **Do not run
Plato render tests against the reference checkout.**

For the local Neovim smoke test (requires Neovim 0.12+, a C compiler and npm
dev dependencies; the `.so` files are local artifacts, not portable releases):

```sh
mkdir -p parser
cc -std=c11 -fPIC -shared -Isrc src/parser.c -o parser.so
cc -std=c11 -fPIC -shared -Inode_modules/tree-sitter-bash/src \
  node_modules/tree-sitter-bash/src/parser.c node_modules/tree-sitter-bash/src/scanner.c -o parser/bash.so
cc -std=c11 -fPIC -shared -Inode_modules/@tree-sitter-grammars/tree-sitter-yaml/src \
  node_modules/@tree-sitter-grammars/tree-sitter-yaml/src/parser.c \
  node_modules/@tree-sitter-grammars/tree-sitter-yaml/src/scanner.c -o parser/yaml.so
nvim --headless -u NONE -l test/nvim.lua
```

## Neovim host injections

Install compatible `yaml` and `bash` Neovim Tree-sitter parsers separately.
Put this repository on `runtimepath`, load a native `plato` parser, and call
`require('plato.injections').setup()` **before** attaching the Plato parser.
For example, after building `parser.so` as above:

```lua
vim.opt.runtimepath:prepend('/absolute/path/to/tree-sitter-plato')
vim.treesitter.language.add('plato', {
  path = '/absolute/path/to/tree-sitter-plato/parser.so',
})
require('plato.injections').setup()
```

Set `plato` as the filetype for relevant template buffers in your editor
configuration. The setup loads the checked-in highlight and injection queries
and registers a buffer-sensitive predicate: `.yaml`/`.yml` inject YAML,
`.sh`/`.bash` or a Bash/sh shebang inject Bash, and unknown paths inject
neither. Shell shebangs take effect only if no recognized extension matches.
Use `require('plato.injections').set_host(bufnr, 'yaml')`, `'bash'`, or `false`
to override a buffer (`nil` clears the override). Open YAML and Bash buffers
in either order: the injection query remains the same for all buffers.
No YAML or Bash content is injected into template actions. Bash includes
literal hyphen nodes; YAML retains the upstream `yaml_no_injection_text`
workaround for adjacent action separators.

`test/nvim.lua` asserts exact literal and delimiter capture ranges for quoted
trimmed substitutions, a YAML block scalar and comment, a Bash heredoc, and
the hyphen between adjacent Bash actions. It also checks that separately
registered parser aliases do not interfere with the shared `plato` query.
The drop-in Neovim integration in the sibling workspace uses the `plato`
language and this module directly; aliases must supply their own injection
query, including `yaml_no_injection_text` for Bash separators.

Injections parse **literal fragments**, not rendered output. Expressions
inside quotes, block scalars, heredocs, whitespace trimming, or generated
subtrees may leave an incomplete host syntax tree; do not treat its diagnostic
positions as validated rendered YAML/Bash. This parser recognizes only
Plato's *default* delimiters. Callers must detect configured custom delimiters
and report them as unsupported instead of silently applying this grammar.
