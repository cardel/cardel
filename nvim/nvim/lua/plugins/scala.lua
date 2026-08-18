-- Scala (metals) y depuracion sobre proyectos Gradle
--
-- El extra lazyvim.plugins.extras.lang.scala se habilita en lazyvim.json y trae
-- nvim-metals, el parser de treesitter y dos configuraciones de DAP
-- ("RunOrTest" y "Test Target"). Metals implementa el Debug Adapter por su
-- cuenta, asi que no hace falta ningun adaptador de mason: basta con
-- `require("metals").setup_dap()`, que el extra ya llama en su on_attach.
--
-- El servidor si hay que bajarlo una vez, con :MetalsInstall (usa coursier, que
-- ya esta en la maquina). Queda en ~/.cache/nvim/nvim-metals/metals.
--
-- Aqui se corrigen dos cosas del extra y se anade una tercera.

return {
  {
    "scalameta/nvim-metals",
    -- 1) El extra ata metals a los filetypes scala, sbt Y java. En esta maquina
    --    eso es un choque: hay ~1607 archivos .java y el extra lang.java ya
    --    levanta jdtls sobre ellos. Al abrir un .java arrancaban los dos
    --    servidores y metals se ponia a pedir permiso para importar el build.
    --
    --    `ft` no se puede recortar desde aqui (lazy.nvim concatena las listas de
    --    ft/event/cmd/keys entre specs, no las reemplaza), pero `config` si se
    --    reemplaza. Es la misma funcion del extra con el patron limitado a
    --    Scala; metals se carga igual al abrir un .java, pero ya no se engancha.
    config = function(_, metals_config)
      local group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "scala", "sbt" },
        callback = function()
          require("metals").initialize_or_attach(metals_config)
        end,
        group = group,
      })
    end,

    -- stylua: ignore
    keys = {
      -- 2) El extra mapea <leader>me a require("telescope").extensions.metals,
      --    pero aqui no hay telescope: LazyVim usa snacks.picker desde la v15.
      --    Ese atajo reventaba con "module 'telescope' not found".
      --    metals.commands() hace lo mismo con vim.ui.select, que snacks toma.
      { "<leader>me", function() require("metals").commands() end, desc = "Metals commands" },
      { "<leader>mi", function() require("metals").import_build() end, desc = "Metals import build" },
      { "<leader>mD", function() require("metals").run_doctor() end, desc = "Metals doctor" },
      { "<leader>mL", function() require("metals").toggle_logs() end, desc = "Metals logs" },
    },
  },

  -- 3) Una configuracion de "attach" para depurar lo que lanza Gradle.
  --
  -- Las dos del extra (RunOrTest, Test Target) las ejecuta metals a traves de su
  -- import de Bloop. Cuando eso no alcanza -- o cuando se quiere depurar
  -- exactamente lo que corre la tarea de Gradle, con su classpath y sus jvmArgs
  -- del build.gradle -- se lanza el proceso suspendido y se engancha el
  -- depurador:
  --
  --     ./gradlew test --debug-jvm      (queda esperando en el puerto 5005)
  --     ./gradlew run  --debug-jvm
  --
  -- y desde nvim <leader>dc -> "Attach (gradle --debug-jvm)".
  --
  -- El extra lang.java ya declara el equivalente para Java ("Debug (Attach) -
  -- Remote", mismo puerto), asi que esto solo cubre el lado Scala.
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")
      dap.configurations.scala = dap.configurations.scala or {}
      table.insert(dap.configurations.scala, {
        type = "scala",
        request = "attach",
        name = "Attach (gradle --debug-jvm)",
        hostName = "127.0.0.1",
        port = 5005,
        buildTarget = "root",
      })
    end,
  },
}
