-- Racket
--
-- No existe extra de LazyVim para Racket, pero aqui hay ~78 archivos .rkt (los
-- talleres de FLP) y el toolchain ya esta en la maquina (/usr/bin/racket).
--
-- Lo unico que hay que instalar aparte:
--
--   raco pkg install racket-langserver
--
-- No esta en mason -- el registro no lo empaqueta -- asi que va por raco. Si no
-- esta instalado, lspconfig no arranca el servidor y el resto (treesitter,
-- paredit) sigue funcionando igual.

return {
  -- El parser y las queries de racket existen en la rama main de
  -- nvim-treesitter (tier 2). LazyVim declara `opts_extend` sobre
  -- ensure_installed, asi que esta lista se suma a la suya en vez de pisarla.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "racket" } },
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- cmd = { "racket", "--lib", "racket-langserver" }
        racket_langserver = {},
      },
    },
  },

  -- nvim-paredit ya viene instalado por el extra lang.clojure, pero ese extra lo
  -- configura con `opts = {}`, o sea con los filetypes por defecto:
  -- clojure, fennel, scheme, lisp, janet. Racket no esta, pese a ser el lisp que
  -- mas se edita aqui.
  --
  -- La lista va completa a proposito: paredit la lee tal cual (config.filetypes)
  -- y lazy.nvim reemplaza las listas al fusionar opts, no las concatena, asi que
  -- poner solo { "racket" } dejaria fuera a los demas.
  {
    "julienvincent/nvim-paredit",
    optional = true,
    opts = {
      filetypes = { "clojure", "fennel", "scheme", "lisp", "janet", "racket" },
    },
  },
}
