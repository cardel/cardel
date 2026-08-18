-- Gramatica y ortografia en espanol (LTeX)
--
-- Este es el hueco mas grande de la configuracion frente a lo que realmente se
-- escribe aqui: contando ~/repositorios hay ~611 .md, ~166 .tex y ~49 .bib, casi
-- todo en espanol, y Neovim no revisaba ni una palabra. texlab y marksman ven
-- estructura, no idioma; markdownlint-cli2 revisa estilo de Markdown, no prosa.
--
-- Zed ya hace esto (zed/settings.json -> lsp.ltex.settings.ltex.language = "es").
-- Esto replica el mismo servidor con la misma configuracion, en la variante
-- mantenida: ltex-ls-plus, porque el ltex-ls original lleva anos sin releases.
--
-- Coste: es un servidor Java (hay OpenJDK 21 en la maquina) y arranca
-- LanguageTool, o sea ~500 MB de RSS y unos segundos hasta el primer
-- diagnostico. Si molesta, basta con borrar este archivo o poner
-- `ltex_plus = false` en la tabla de servidores.

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ltex_plus = {
          -- Los filetypes por defecto del server incluyen html, xhtml, mail y
          -- text; se recortan a lo que de verdad se edita para no levantar el
          -- proceso al abrir cualquier .txt.
          filetypes = { "bib", "gitcommit", "markdown", "plaintex", "tex" },
          settings = {
            ltex = {
              language = "es",

              -- Sin esto LanguageTool marca cada identificador, cada comando de
              -- LaTeX y cada bloque de codigo. El diccionario y las listas de
              -- excepciones se guardan por idioma; se pueden ir llenando a mano
              -- o desde las code actions del propio servidor.
              dictionary = { es = {} },
              disabledRules = { es = {} },
              hiddenFalsePositives = { es = {} },

              -- Reglas de estilo de LanguageTool ademas de las de correccion.
              -- "picky" incluye sugerencias opinables; se deja fuera.
              additionalRules = { enablePickyRules = false },
            },
          },
        },
      },
    },
  },
}
