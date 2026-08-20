-- C / C++ (clangd) afinado para codigo de clase
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
}
