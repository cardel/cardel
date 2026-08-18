-- Linters (nvim-lint)
--
-- nvim-lint viene instalado de fabrica con LazyVim, pero lo que realmente
-- ejecuta sale de los extras habilitados. Sumando todos los de lazyvim.json, la
-- tabla efectiva era:
--
--   fish       -> fish              (del core; aqui se usa zsh, sobra)
--   cmake      -> cmakelint
--   dockerfile -> hadolint
--   markdown   -> markdownlint-cli2
--   terraform  -> terraform_validate
--
-- Ojo con dos casos que NO pasan por nvim-lint y por eso parecen faltar:
--   * Python: ruff corre como servidor LSP (extra lang.python), no como linter.
--   * Shell: bash-language-server invoca shellcheck internamente.
--
-- Lo de abajo cubre los huecos reales medidos sobre ~/repositorios.

return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        -- ~145 archivos .yaml/.yml y nada los revisaba: yaml-language-server
        -- solo valida contra el esquema (SchemaStore), no el estilo ni los
        -- errores de indentacion que no rompen el parseo.
        --
        -- actionlint va en la misma lista, no en un filetype aparte: Neovim
        -- 0.12 le pone filetype "yaml" a secas a los archivos de
        -- .github/workflows/ (comprobado), no "yaml.github" como asumen varias
        -- recetas que circulan. El filtro por ruta se hace con `condition`.
        yaml = { "yamllint", "actionlint" },

        -- shellcheck explicito ademas del que corre dentro de bashls: bashls
        -- solo lo aplica al archivo abierto y con su propia configuracion, y si
        -- alguna vez se desactiva ese servidor el linting desaparece sin aviso.
        sh = { "shellcheck" },
        bash = { "shellcheck" },
      },

      linters = {
        -- `condition` es una extension de LazyVim sobre nvim-lint (recibe
        -- ctx.filename / ctx.dirname). Sin esto actionlint se dispararia sobre
        -- cualquier YAML y llenaria el buffer de falsos positivos, porque asume
        -- que todo lo que ve es un workflow.
        actionlint = {
          condition = function(ctx)
            return ctx.filename:find("%.github[/\\]workflows[/\\]") ~= nil
          end,
        },
      },
    },
  },

  -- Herramientas en disco. mason no las instala por si solo: las declara quien
  -- las usa, y ningun extra habilitado declara estas dos.
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "yamllint", "actionlint" } },
  },
}
