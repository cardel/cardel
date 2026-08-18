-- Depuracion (DAP)
--
-- El extra `dap.core` de LazyVim se habilita en lazyvim.json; este archivo solo
-- anade los adaptadores que ningun extra instala solos.
--
-- Por que importa: los extras de lenguaje de LazyVim traen su bloque de DAP
-- marcado como `optional = true`, o sea que se queda inerte mientras nvim-dap no
-- exista. Con `dap.core` activo, esos bloques se despiertan sin tocar nada mas:
--
--   lang.python -> nvim-dap-python  (<leader>dPt metodo, <leader>dPc clase)
--   lang.java   -> java-debug-adapter + java-test, y jdtls activa sus opciones
--                  dap / dap_main / test, que hasta ahora no hacian nada
--   test.core   -> neotest puede correr un test con strategy = "dap"
--
-- Teclas base del extra: <leader>db breakpoint, <leader>dc continuar,
-- <leader>di step into, <leader>do step over, <leader>du panel de dap-ui.

return {
  {
    "mfussenegger/nvim-dap",
    optional = true,
    dependencies = {
      {
        "jay-babu/mason-nvim-dap.nvim",
        opts = {
          -- mason-nvim-dap deja `ensure_installed` vacio a proposito y espera que
          -- cada quien ponga los suyos.
          --
          -- debugpy: lo pide nvim-dap-python (lang.python).
          -- bash-debug-adapter: no lo instala ningun extra, y aqui hay ~157
          --   scripts .sh. El handler automatico lo registra como adaptador
          --   "bashdb" en cuanto mason lo tiene en disco.
          --
          -- Los de Java (java-debug-adapter, java-test) NO van aqui: los declara
          -- el propio extra lang.java via mason.ensure_installed.
          ensure_installed = { "debugpy", "bash-debug-adapter" },
        },
      },
    },
  },

  -- Puente neotest <-> dap. neotest ya esta instalado por test.core, pero sin
  -- nvim-dap la estrategia "dap" no existia, asi que no habia atajo para
  -- depurar el test bajo el cursor.
  {
    "nvim-neotest/neotest",
    optional = true,
    -- stylua: ignore
    keys = {
      { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug Nearest" },
    },
  },
}
