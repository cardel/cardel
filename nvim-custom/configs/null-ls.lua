local null_ls = require "null-ls"

local b = null_ls.builtins
local lint = null_ls.builtins.diagnostics

local sources = {

  -- webdev stuff
  b.formatting.deno_fmt, -- choosed deno for ts/js files cuz its very fast!
  b.formatting.prettier.with { filetypes = { "html", "markdown", "css" } }, -- so prettier works only on these filetypes

  -- Lua
  b.formatting.stylua,

  -- cpp
  b.formatting.clang_format,

  --py
  --b.formatting.autoflake,
  --b.formatting.isort,
  b.formatting.autopep8,
  --shell
  b.formatting.beautysh,

  --java
  --b.formatting.google_java_format,
  --dprint
  --
  b.formatting.dprint,

  --bibtex
  --b.formatting.bibtex_tidy,

  --markdown
  b.formatting.mdformat,

  --sql
  b.formatting.sql_formatter,

  --scala
  --b.formatting.semgrep,
  lint.checkstyle,
  lint.semgrep, -- for scala
  lint.actionlint, -- for github actions
  --lint.flake8, -- for python
  --lint.pylint, -- for python
  lint.shellcheck, -- for shell
  lint.sqlfluff, -- for sql
  lint.vint, -- for vim
  lint.gitlint, -- for git commit messages
  lint.markdownlint, -- for markdown
  lint.standardrb, -- for ruby
}
null_ls.setup {
  debug = true,
  sources = sources,
}
