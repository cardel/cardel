-- Completado: lista de lo que existe, no texto que se adelanta
--
-- Objetivo: que sugiera como un IDE -- los metodos y campos que el servidor de
-- lenguaje sabe que existen en ese punto -- y que no escriba nada que no se haya
-- elegido a mano.
--
-- Los tres comportamientos de LazyVim que rompian eso:
--
--   a) preselect = PreselectMode.Item. El primer resultado queda seleccionado
--      solo. Como <CR> se mapea con `select = true`, pulsar Enter para bajar de
--      linea aceptaba esa primera entrada. Esto es lo que hace que "escriba
--      cosas solo".
--
--   b) completeopt sin `noselect` (LazyVim usa "menu,menuone,noinsert"), que es
--      la mitad de vim del mismo problema.
--
--   c) ghost_text. Dibuja el item seleccionado en gris despues del cursor, asi
--      que el buffer aparenta tener texto que todavia no existe. Frente a un
--      grupo es justo lo que no se quiere: no se distingue lo escrito de lo
--      sugerido.
--
-- Lo que NO se toca: el menu sigue apareciendo solo al escribir y al poner un
-- punto. Eso es lo util y es lo que hace un IDE. Lo que cambia es que no elige
-- por ti.
--
-- El completador elegido es nvim-cmp (extra coding.nvim-cmp), en las dos
-- maquinas. El bloque de blink.cmp se queda como equivalente por si se vuelve al
-- de fabrica de LazyVim: lleva `optional = true`, asi que mientras blink no este
-- instalado es inerte y no lo arrastra. Lo mismo vale para el bloque de
-- nvim-cmp, que solo se aplica si el extra esta habilitado.

return {
  -- nvim-cmp (extra coding.nvim-cmp)
  {
    "hrsh7th/nvim-cmp",
    optional = true,
    -- Forma de funcion en vez de tabla: el extra define su `opts` como funcion y
    -- construye el mapping con cmp.mapping.preset.insert(). Asi se recibe ya
    -- resuelto y se cambian solo las claves que interesan, sin rehacer el resto
    -- del preset.
    opts = function(_, opts)
      local cmp = require("cmp")

      opts.preselect = cmp.PreselectMode.None
      opts.completion = vim.tbl_extend("force", opts.completion or {}, {
        completeopt = "menu,menuone,noinsert,noselect",
      })
      opts.experimental = vim.tbl_extend("force", opts.experimental or {}, {
        ghost_text = false,
      })

      -- Enter solo confirma si hay algo seleccionado a mano (con <C-n>/<C-p> o
      -- <Tab>). Sin seleccion, <CR> vuelve a ser un salto de linea normal.
      -- <C-y> se queda como estaba: confirma la primera entrada directamente,
      -- para quien ya sepa lo que quiere.
      opts.mapping = vim.tbl_extend("force", opts.mapping or {}, {
        ["<CR>"] = LazyVim.cmp.confirm({ select = false }),
      })

      return opts
    end,
  },

  -- blink.cmp (completador por defecto de LazyVim)
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      completion = {
        ghost_text = { enabled = false },
        -- Equivalente en blink de preselect + noselect: la lista se muestra sin
        -- nada marcado. auto_insert = true hace que, al moverse por ella con las
        -- flechas, se vaya viendo el resultado en el buffer, que es el
        -- comportamiento de un IDE al recorrer la lista de metodos.
        list = { selection = { preselect = false, auto_insert = true } },
      },
    },
  },

  -- Copilot bajo demanda
  --
  -- Con vim.g.ai_cmp = false (config/options.lua) el extra ai.copilot deja de
  -- meter entradas en el menu y activa su propio canal:
  -- `suggestion.enabled = not vim.g.ai_cmp`. Pero lo deja con
  -- auto_trigger = true, o sea proponiendo lineas enteras en gris segun se
  -- escribe -- se cambia una forma de texto adelantado por otra.
  --
  -- Con auto_trigger = false no aparece nada hasta pedirlo:
  --   <M-]>  pedir sugerencia / siguiente
  --   <M-[>  anterior
  --   <Tab>  aceptar la visible (via LazyVim.cmp.actions.ai_accept)
  {
    "zbirenbaum/copilot.lua",
    optional = true,
    opts = {
      suggestion = { auto_trigger = false },
    },
  },
}
