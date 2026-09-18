-- Scala (metals) y depuracion, sobre proyectos sbt y Gradle
--
-- El extra lazyvim.plugins.extras.lang.scala se habilita en lazyvim.json y trae
-- nvim-metals, el parser de treesitter y dos configuraciones de DAP
-- ("RunOrTest" y "Test Target"). Metals implementa el Debug Adapter por su
-- cuenta, asi que no hace falta ningun adaptador de mason: basta con
-- `require("metals").setup_dap()`, que el extra ya llama en su on_attach.
--
-- El servidor no esta en mason; lo baja este archivo con coursier la primera
-- vez que se abre un .scala (ver abajo). Queda en ~/.cache/nvim/nvim-metals/.
--
-- Los proyectos de aqui son sbt en su inmensa mayoria (304 .scala, casi todos
-- bajo un build.sbt: IdeaProjects/, clases/, FundProFunConc/), no Gradle. Eso
-- cambia el nombre del build target -- ver el attach al final.
--
-- Comprobado el 2026-09-17 con metals 1.6.9, Bloop 2.1.2, Scala 3.8.1 y 2.13.18
-- sobre ~/IdeaProjects/example: hover, importacion del build, breakpoint en la
-- linea 12, variables en Scopes (`i int = 1`), evaluacion de `i` en el REPL,
-- step over. Dos avisos en el log que no son de la config: para Scala 3.8.1 no
-- hay expression-compiler publicado (usa uno compatible) ni decodificador de
-- frames (un step over desde el cuerpo de un `for` cae en Range.foreach). Con
-- 2.13.18 no pasa.

return {
  {
    "scalameta/nvim-metals",
    -- 0) Lo que el extra apaga y aqui se enciende. `opts` del extra es una
    --    funcion que devuelve la config; lazy.nvim encadena la de aqui detras
    --    y le pasa ese resultado, asi que se retoca y se devuelve.
    opts = function(_, metals_config)
      -- El extra pone statusBarProvider = "off": metals no cuenta nada de lo
      -- que hace. Importar un build sbt tarda 20-30 s con sbt arrancando y
      -- compilando por debajo, y con "off" eso es silencio absoluto -- que es
      -- exactamente lo que se percibe como "no funciona". Con "on" nvim-metals
      -- escribe vim.g.metals_status ("Importing build", "Compiling root"...) y
      -- lualine lo muestra (spec de abajo).
      metals_config.init_options.statusBarProvider = "on"

      -- Los inlay hints de conversiones implicitas se apagan. Con ellos, cada
      -- `1 to 5` se pinta como `intWrapper(1) to 5`: es la tuberia de la
      -- biblioteca estandar, no algo que el estudiante haya escrito ni que
      -- vaya a escribir, y en una clase de programacion funcional confunde
      -- mas de lo que ensena. Los tipos inferidos (`.map[Unit]`) y los
      -- argumentos implicitos se quedan, que esos si son del programa.
      -- Decision de gusto, revertible; <leader>uh alterna todos los hints.
      metals_config.settings.showImplicitConversionsAndClasses = false

      -- Codelens: metals pinta "run | debug" encima de cada @main y
      -- "test | debug test" encima de cada suite, y con <leader>cc (LazyVim:
      -- vim.lsp.codelens.run) se ejecuta el que este bajo el cursor. LazyVim
      -- trae codelens.enabled = false para todos los servidores; aqui se
      -- refresca solo en buffers de Scala, sin encenderlo para jdtls y clangd.
      local on_attach_extra = metals_config.on_attach
      metals_config.on_attach = function(client, bufnr)
        if on_attach_extra then
          on_attach_extra(client, bufnr) -- setup_dap()
        end
        if client.server_capabilities.codeLensProvider then
          vim.lsp.codelens.refresh({ bufnr = bufnr })
          vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "BufWritePost" }, {
            buffer = bufnr,
            group = vim.api.nvim_create_augroup("metals-codelens-" .. bufnr, { clear = true }),
            callback = function()
              vim.lsp.codelens.refresh({ bufnr = bufnr })
            end,
          })
        end
      end
      return metals_config
    end,

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
      -- Bajar el servidor solo la primera vez.
      --
      -- Metals NO esta en mason: comprobado sobre el registro instalado, 590
      -- paquetes y ninguno de metals, scala ni bloop. Asi que no se puede
      -- declarar en ensure_installed como el resto de servidores, y en una
      -- maquina nueva Scala se queda sin LSP hasta que alguien se acuerda de
      -- ejecutar :MetalsInstall a mano -- que es justo lo que paso en el
      -- portatil, donde en ~/.cache/nvim/nvim-metals/ solo habia un log.
      --
      -- Quien si sabe instalarlo es el propio nvim-metals, con coursier. Esto
      -- lo dispara al abrir el primer archivo de Scala si el binario no esta,
      -- que es el equivalente a lo que hace mason con los demas.
      --
      -- EL ORDEN IMPORTA, y la primera version de esto lo tenia al reves.
      -- install() lee una cache interna de configuracion que solo rellena
      -- initialize_or_attach() (a traves de validate_config). Llamar a
      -- install() antes revienta en cada apertura de un .scala con
      --
      --   nvim-metals/lua/metals/install.lua:91:
      --   attempt to index local 'config' (a nil value)
      --
      -- y como el error sale en un autocmd de FileType, el usuario ve una
      -- pantalla roja con "-- More --" y ningun servidor: eso era "nvim no
      -- funciona con Scala". Medido el 2026-09-17 abriendo un .scala en un pty.
      -- Asi que primero initialize_or_attach (que con el binario ausente no
      -- arranca nada, solo valida y avisa) y despues install().
      --
      -- install() es asincrono y al terminar solo suelta un vim.notify que dice
      -- "Start/Restart the server": no engancha nada por si mismo. Por eso el
      -- temporizador de abajo espera al binario y entonces engancha los buffers
      -- de Scala que haya abiertos. No se usa install(true), la variante
      -- sincrona: bloquea nvim y tiene un tope fijo de 60 s, y la descarga
      -- tarda 23 s medidos con la red de aqui y la cache de coursier vacia --
      -- demasiado cerca del tope para una red peor.
      local metals_bin = vim.fn.stdpath("cache") .. "/nvim-metals/metals"
      local tipos = { "scala", "sbt" }
      local group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
      local instalando = false

      local function enganchar_buffers_scala()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(buf) and vim.tbl_contains(tipos, vim.bo[buf].filetype) then
            vim.api.nvim_buf_call(buf, function()
              require("metals").initialize_or_attach(metals_config)
            end)
          end
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = tipos,
        group = group,
        callback = function()
          local metals = require("metals")

          if vim.fn.executable(metals_bin) == 1 then
            metals.initialize_or_attach(metals_config)
            return
          end
          if instalando then
            return
          end
          instalando = true

          -- Esta llamada solo vale por su efecto secundario (rellenar la cache
          -- que install() lee). Con el binario ausente suelta el aviso
          -- "Welcome to nvim-metals! ... You can do this using :MetalsInstall",
          -- que nvim-metals parte en seis notificaciones, una por linea, y que
          -- contradice lo que se dice justo debajo. Se silencia SOLO durante
          -- esta llamada, que es sincrona; pcall garantiza restaurar vim.notify
          -- aunque reviente.
          local notify = vim.notify
          vim.notify = function(msg, nivel, o)
            if not tostring(msg):find("[nvim-metals]", 1, true) then
              notify(msg, nivel, o)
            end
          end
          local ok, err = pcall(metals.initialize_or_attach, metals_config)
          vim.notify = notify
          if not ok then
            error(err)
          end

          vim.notify(
            "Metals no esta instalado. Bajandolo con coursier: una sola vez, ~25 s.\n"
              .. "No hace falta :MetalsInstall; el servidor se engancha solo al terminar.",
            vim.log.levels.INFO,
            { title = "Scala" }
          )
          metals.install()

          local timer = vim.uv.new_timer()
          local intentos = 0
          timer:start(
            2000,
            2000,
            vim.schedule_wrap(function()
              intentos = intentos + 1
              if vim.fn.executable(metals_bin) == 1 then
                timer:stop()
                timer:close()
                enganchar_buffers_scala()
              elseif intentos >= 150 then -- 5 minutos
                timer:stop()
                timer:close()
                instalando = false
                vim.notify(
                  "Metals no aparecio en 5 minutos. Mirar :MetalsLogs o correr :MetalsInstall a mano.",
                  vim.log.levels.ERROR,
                  { title = "Scala" }
                )
              end
            end)
          )
        end,
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
      -- Arbol de metals: build targets, dependencias y -- porque el extra pone
      -- testUserInterface = "Test Explorer" -- las suites de test, para
      -- correrlas o depurarlas desde ahi.
      { "<leader>mt", function() require("metals.tvp").toggle_tree_view() end, desc = "Metals tree view" },
      { "<leader>mR", function() require("metals.tvp").reveal_in_tree() end, desc = "Metals reveal in tree" },
    },
  },

  -- Grupo de which-key para que <leader>m no salga como teclas sueltas.
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>m", group = "metals", icon = "" } } },
  },

  -- Estado de metals en la barra: "Importing build", "Compiling root",
  -- "Indexing"... Solo aparece cuando hay algo que decir.
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, {
        function()
          local partes = {}
          for _, v in ipairs({ vim.g.metals_bsp_status, vim.g.metals_status }) do
            if v and v ~= "" then
              partes[#partes + 1] = v
            end
          end
          return table.concat(partes, " ")
        end,
        cond = function()
          return (vim.g.metals_status or "") ~= "" or (vim.g.metals_bsp_status or "") ~= ""
        end,
        icon = "",
        color = function()
          return { fg = Snacks.util.color("Special") }
        end,
      })
    end,
  },

  -- 3) Una configuracion de "attach" para depurar lo que lanza sbt o Gradle.
  --
  -- Las dos del extra (RunOrTest, Test Target) las ejecuta metals a traves de su
  -- import de Bloop. Cuando eso no alcanza -- o cuando se quiere depurar
  -- exactamente lo que corre la herramienta de build, con su classpath y sus
  -- opciones de JVM -- se lanza el proceso suspendido en el puerto 5005 y se
  -- engancha el depurador:
  --
  --     sbt -jvm-debug 5005 run        (sbt; tambien "sbt -jvm-debug 5005 test")
  --     ./gradlew run --debug-jvm      (Gradle; idem con test)
  --
  -- y desde nvim <leader>dc -> "Attach (5005: sbt -jvm-debug / gradle --debug-jvm)".
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
        name = "Attach (5005: sbt -jvm-debug / gradle --debug-jvm)",
        hostName = "127.0.0.1",
        port = 5005,
        -- El nombre del build target lo pone Bloop y NO es el `name :=` del
        -- build: es el id del proyecto. En un build.sbt con
        -- `lazy val root = (project in file(".")).settings(name := "app")` el
        -- target es "root" (y "root-test" para los tests): medido, sbt genero
        -- .bloop/root.json y .bloop/root-test.json. En Gradle es el nombre del
        -- subproyecto ("app" con el settings.gradle de `gradle init`).
        --
        -- Con un target inexistente metals no resuelve el classpath y el attach
        -- falla sin decir por que. Asi que en vez de fijarlo se lee de .bloop/
        -- al lanzar: nvim-dap evalua los campos que son funciones en ese
        -- momento, dentro de una corrutina, lo que permite preguntar con
        -- vim.ui.select si hay mas de uno (mismo patron que dap.utils.pick_process).
        buildTarget = function()
          local raiz = vim.fs.root(0, { ".bloop", "build.sbt", "build.gradle", "build.gradle.kts" }) or vim.fn.getcwd()
          local targets = {}
          for nombre, tipo in vim.fs.dir(raiz .. "/.bloop") do
            local id = nombre:match("^(.+)%.json$")
            if
              tipo == "file"
              and id
              and id ~= "bloop.settings"
              and not id:match("%-build$")
              and not id:match("%-test$")
            then
              targets[#targets + 1] = id
            end
          end
          if #targets == 0 then
            vim.notify(
              "No hay .bloop/*.json en " .. raiz .. ": importa el build primero (<leader>mi).",
              vim.log.levels.ERROR,
              { title = "Scala" }
            )
            return dap.ABORT
          end
          if #targets == 1 then
            return targets[1]
          end
          local co, ismain = coroutine.running()
          local ui = require("dap.ui")
          local pick = (co and not ismain) and ui.pick_one or ui.pick_one_sync
          return pick(targets, "Build target: ", tostring) or dap.ABORT
        end,
      })
    end,
  },
}
