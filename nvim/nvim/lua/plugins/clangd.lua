-- C / C++ afinado para codigo de clase: clangd y depuracion
--
-- El extra lazyvim.plugins.extras.lang.clangd deja clangd con varias ayudas
-- pensadas para quien ya sabe C. Frente a un grupo estorban, porque el editor
-- dibuja texto que NO esta en el archivo y el estudiante no distingue que
-- escribio el y que puso el LSP. Los tres casos concretos:
--
-- 1) Inlay hints con el nombre del parametro. LazyVim los enciende para todos
--    los servidores (inlay_hints = { enabled = true, exclude = { "vue" } } en
--    lazyvim/plugins/lsp/init.lua) y clangd los emite en cada llamada:
--
--        printf(format: "%d\n", x);
--        memcpy(dest: a, src: b, n: 10);
--
--    Ese "format:" no es sintaxis de C, no esta en el buffer y no compila si lo
--    copian a mano. Es el origen del "aparecen cosas raras".
--
-- 2) --function-arg-placeholders (+ usePlaceholders). Al aceptar la completacion
--    de printf inserta la firma entera con placeholders que hay que ir tabulando.
--    Quien esta aprendiendo la sintaxis no necesita pelear con eso.
--
-- 3) --header-insertion=iwyu. Al aceptar una completacion clangd anade el
--    #include correspondiente arriba del archivo, solo. Aparece una linea que
--    nadie escribio, y ademas les quita justo el paso que se les esta enseniando.
--
-- Lo que NO se toca: --clang-tidy se queda. Sus chequeos por defecto son
-- clang-diagnostic-* y clang-analyzer-*, que son errores reales (uso de memoria
-- sin inicializar, fugas), no ruido de estilo. Para quitarlo, borra esa linea
-- del cmd de abajo.
--
-- Los hints siguen disponibles bajo demanda: <leader>uh los alterna en el buffer
-- actual. `exclude` solo evita que se enciendan solos al conectar el servidor.

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = {
        -- La lista va completa a proposito, con "vue" incluido: lazy.nvim
        -- reemplaza las listas al fusionar opts en vez de concatenarlas, asi que
        -- poner solo { "c", "cpp" } perderia el valor por defecto de LazyVim.
        --
        -- Los cinco filetypes son los que el propio extra declara en su
        -- `recommended`: c, cpp, objc, objcpp, cuda y proto.
        exclude = { "vue", "c", "cpp", "objc", "objcpp", "cuda", "proto" },
      },

      servers = {
        clangd = {
          -- Mismo motivo que arriba: `cmd` es una lista y se reemplaza entera,
          -- asi que hay que repetir los flags del extra que si queremos.
          -- Respecto al original se quita --function-arg-placeholders y
          -- --header-insertion pasa de iwyu a never.
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=never",
            "--completion-style=detailed",
            "--fallback-style=llvm",
          },

          init_options = {
            -- Completa el nombre de la funcion y para. Los parametros los
            -- escribe el estudiante.
            usePlaceholders = false,
            -- Coherente con --header-insertion=never: si no se va a anadir el
            -- #include solo, tampoco tiene sentido ofrecer simbolos de headers
            -- que el archivo todavia no incluye. Asi la lista de completacion
            -- refleja lo que de verdad esta disponible en ese punto.
            completeUnimported = false,
            clangdFileStatus = true,
          },
        },
      },
    },
  },

  -- Depuracion: codelldb con terminal propia
  --
  -- nvim no depura C con gdb: el extra lang.clangd registra el adaptador
  -- codelldb, que es LLDB. Y registra dos configuraciones, "Launch file" y
  -- "Attach to process", ninguna de las dos con `console`. Ahi esta la falla.
  -- Sin console, codelldb lanza el programa colgado del canal del protocolo:
  -- lo que imprime no aparece en ninguna parte y lo que lee con scanf o con
  -- cin no llega nunca. Un programa de clase que pide un dato se queda
  -- bloqueado antes del primer breakpoint, y lo que se ve es un depurador que
  -- arranco y no hace nada.
  --
  -- Medido con un programa de doce lineas (printf, scanf, breakpoint en la
  -- linea de despues): sin console no para nunca; con console =
  -- "integratedTerminal" nvim abre un buffer de terminal, sale el "dame un
  -- numero", se teclea el dato y para en el breakpoint.
  --
  -- Lo otro que estorbaba: <leader>dc ofrecia cuatro opciones. mason-nvim-dap
  -- trae handler automatico para codelldb y agrega las suyas, "LLDB: Launch" y
  -- "LLDB: Launch (args)", con list_extend, asi que se suman a las del extra en
  -- vez de reemplazarlas (automatic_setup.lua:13). Esas dos si llevan console,
  -- o sea que de las cuatro dos servian y dos no, sin nada en el nombre que
  -- las distinguiera. Abajo se reemplaza la lista entera por tres.
  --
  -- gdb nativo se probo y se descarto. GDB 18.1 habla DAP
  -- (`gdb --interpreter=dap`), para en los breakpoints y muestra las variables
  -- con sus nombres, pero su launch no implementa runInTerminal:
  -- /usr/share/gdb/python/gdb/dap/launch.py no acepta console ni terminal, el
  -- programa hereda el stdio de gdb, que es el canal del protocolo, y el stdin
  -- queda muerto otra vez. En los contenedores de la biblioteca estandar
  -- tampoco gana: con g++ -g, codelldb muestra v = size=5, s = "hola mundo",
  -- m = size=2, y gdb lo mismo con otras palabras.
  --
  -- Los proyectos con CMake no pasan por aqui: :CMakeDebug de cmake-tools
  -- compila, busca el binario del target y lanza su propia configuracion, que
  -- ya trae console = "integratedTerminal" (const.lua:35).
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = {
      handlers = {
        -- El handler por defecto hace dos cosas: registra el adaptador y
        -- agrega sus configuraciones. La primera interesa, porque apunta al
        -- binario de mason por ruta absoluta y no depende del PATH; la segunda
        -- es la que duplicaba la lista.
        codelldb = function(config)
          config.configurations = {}
          require("mason-nvim-dap").default_setup(config)
        end,
      },
    },
  },

  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")

      -- Un archivo, compilado con -g y sin optimizar, que es lo que son los
      -- programas de clase. Con -O0 explicito porque sin el gcc reordena y
      -- elimina lineas, y el breakpoint cae donde no se espera.
      --
      -- Si el programa son varios .cpp, gcc falla al enlazar y el error sale
      -- en la notificacion; eso se depura con la segunda configuracion, sobre
      -- el binario que ya hizo el make.
      local function compilar()
        vim.cmd("silent! update")
        local fuente = vim.api.nvim_buf_get_name(0)
        if fuente == "" then
          vim.notify("El buffer no tiene archivo.", vim.log.levels.ERROR, { title = "Depurar C/C++" })
          return dap.ABORT
        end
        local compilador = vim.fn.fnamemodify(fuente, ":e") == "c" and "gcc" or "g++"
        local destino = vim.fn.stdpath("cache") .. "/dap-c/" .. vim.fn.fnamemodify(fuente, ":t:r")
        vim.fn.mkdir(vim.fs.dirname(destino), "p")
        local salida = vim.fn.system({ compilador, "-g", "-O0", "-Wall", fuente, "-o", destino })
        if vim.v.shell_error ~= 0 then
          vim.notify(salida, vim.log.levels.ERROR, { title = compilador .. " fallo" })
          return dap.ABORT
        end
        return destino
      end

      -- La ruta se recuerda mientras dure la sesion de nvim. Depurar es
      -- arrancar y parar quince veces; teclear la ruta cada vez es la razon
      -- por la que uno deja de usar el depurador.
      local ultimo
      local function pedir_ejecutable()
        local raiz = vim.fs.root(0, { "Makefile", "CMakeLists.txt", ".git" }) or vim.fn.getcwd()
        local ruta = vim.fn.input({
          prompt = "Ejecutable: ",
          default = ultimo or (raiz .. "/"),
          completion = "file",
        })
        if ruta == "" then
          return dap.ABORT
        end
        ultimo = ruta
        return vim.fn.expand(ruta)
      end

      for _, lenguaje in ipairs({ "c", "cpp" }) do
        dap.configurations[lenguaje] = {
          {
            name = "Compilar este archivo y depurarlo",
            type = "codelldb",
            request = "launch",
            program = compilar,
            -- El programa corre desde la carpeta del archivo, no desde la del
            -- proyecto, para que un fopen("datos.txt") encuentre el archivo
            -- que esta al lado del .c.
            cwd = "${fileDirname}",
            console = "integratedTerminal",
            stopOnEntry = false,
            -- Vacio, no ausente: asi <leader>da (Run with Args) tiene algo que
            -- preguntar y los argumentos se pasan sin tocar esta lista.
            args = {},
          },
          {
            name = "Depurar un ejecutable ya compilado",
            type = "codelldb",
            request = "launch",
            program = pedir_ejecutable,
            cwd = "${workspaceFolder}",
            console = "integratedTerminal",
            stopOnEntry = false,
            args = {},
          },
          {
            name = "Enganchar a un proceso",
            type = "codelldb",
            request = "attach",
            pid = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
          },
        }
      end
    end,
  },
}
