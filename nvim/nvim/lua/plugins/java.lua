-- Java (jdtls): los JDK de la maquina y los mismos hints que en C/C++
--
-- Dos cosas, una por cada problema medido.
--
-- 1) Los inlay hints de nombre de parametro, otra vez.
--
--    El extra lang.java configura jdtls con
--    settings.java.inlayHints.parameterNames.enabled = "all", asi que en Java
--    pasa exactamente lo mismo que pasaba en C:
--
--        calcular(base: x, tasa: y);
--
--    Ese "base:" no esta en el archivo. Aqui hay 2141 archivos .java, o sea que
--    es donde mas se nota.
--
--    Se apaga en el servidor, no en el cliente. Es mas preciso que meter "java"
--    en inlay_hints.exclude: jdtls deja de enviarlos, en vez de enviarlos para
--    que Neovim los ignore. Ademas evita que dos archivos de lua/plugins/ se
--    peleen por la lista `exclude`, que lazy.nvim reemplaza entera en vez de
--    concatenar -- ganaria el ultimo en orden alfabetico, que es justo el tipo
--    de bug que no se ve venir.
--
--    Siguen disponibles: <leader>uh los alterna en el buffer actual.
--
-- 2) Los JDK instalados.
--
--    En la maquina hay cuatro (8, 11, 17 y 21) y jdtls solo conoce el que
--    arranca su propio proceso. Sin esta lista, un proyecto cuyo pom.xml o
--    build.gradle apunte a otra version se compila contra el JDK equivocado, y
--    los errores que salen no son los que veria el estudiante al compilar.
--
--    Aqui conviven 40 pom.xml y 11 proyectos de Gradle de cursos distintos, asi
--    que declarar los cuatro es lo que hace que cada uno se resuelva solo. Los
--    nombres son los identificadores de entorno de Eclipse (JavaSE-XX); tienen
--    que ser exactos o jdtls los ignora en silencio.

return {
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = {
      settings = {
        java = {
          inlayHints = {
            parameterNames = { enabled = "none" },
          },
          configuration = {
            runtimes = {
              { name = "JavaSE-1.8", path = "/usr/lib/jvm/java-8-openjdk" },
              { name = "JavaSE-11", path = "/usr/lib/jvm/java-11-openjdk" },
              { name = "JavaSE-17", path = "/usr/lib/jvm/java-17-openjdk", default = true },
              { name = "JavaSE-21", path = "/usr/lib/jvm/java-21-openjdk" },
            },
          },
        },
      },
    },
  },
}
