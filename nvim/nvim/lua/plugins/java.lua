-- Java (jdtls): con que JVM corre, contra que JDK analiza, y sin inlay hints
--
-- Tres cosas, y conviene no confundir las dos primeras porque suenan igual:
--
--   * con que JVM se ejecuta el propio servidor  -> `cmd`, abajo
--   * contra que JDK se analizan TUS proyectos   -> `configuration.runtimes`
--
-- 1) La JVM del servidor.
--
--    jdtls se negaba a arrancar:
--
--        Client jdtls stopped with code 1
--        Exception: jdtls requires at least Java 21
--
--    El lanzador de mason (packages/jdtls/bin/jdtls.py, get_java_executable)
--    resuelve la JVM mirando JAVA_HOME y si no el `java` del PATH, y aborta si
--    es menor que 21. Aqui el default del sistema es la 17 y JAVA_HOME no esta
--    definida, asi que moria siempre.
--
--    Se le pasa --java-executable en vez de tocar nada global. Cambiar el
--    default con archlinux-java, o exportar JAVA_HOME=21, afectaria tambien a
--    Gradle, Maven y a lo que compilen los estudiantes desde la terminal; esto
--    solo afecta al proceso del servidor.
--
--    La ruta se busca en vez de escribirla fija: asi el dia que llegue la 22 o
--    la 25 sigue funcionando, y en una maquina sin ningun JDK >= 21 no se anade
--    la opcion y el error vuelve a ser el de arriba, que al menos se entiende.
--
-- 2) Los JDK contra los que se analiza.
--
--    jdtls solo conoce la JVM con la que arranca -- ahora la 21 -- asi que sin
--    esta lista todo proyecto se analizaria contra 21, aunque su pom.xml o su
--    build.gradle pidan otra. Aqui conviven 40 pom.xml y 11 proyectos de Gradle
--    de cursos distintos, y los errores que ve el estudiante al compilar tienen
--    que ser los mismos que salen en el editor.
--
--    java-8-openjdk NO esta en la lista: en esta maquina no trae javac, es solo
--    el JRE. jdtls descarta en silencio un runtime sin JDK completo, asi que
--    ponerlo solo servia para creer que estaba cubierto. Si algun dia hace falta
--    Java 8 de verdad, hay que instalar jdk8-openjdk.
--
--    Los nombres son los identificadores de entorno de Eclipse (JavaSE-XX) y
--    tienen que ser exactos o se ignoran sin avisar.
--
-- 3) Los inlay hints de nombre de parametro.
--
--    El extra lang.java configura jdtls con
--    settings.java.inlayHints.parameterNames.enabled = "all", asi que pasa lo
--    mismo que pasaba en C con printf(format: ...):
--
--        calcular(base: x, tasa: y);
--
--    Ese "base:" no esta en el archivo. Con 2141 archivos .java es donde mas se
--    nota. Se apaga en el servidor y no metiendo "java" en inlay_hints.exclude:
--    jdtls deja de enviarlos en vez de mandarlos para que Neovim los tire, y de
--    paso se evita que dos archivos de lua/plugins/ se disputen la lista
--    `exclude`, que lazy.nvim reemplaza entera en vez de concatenar -- ganaria
--    el ultimo por orden alfabetico. Siguen a mano con <leader>uh.

-- Devuelve el java de mayor version >= 21 que haya instalado, o nil.
local function java_para_el_servidor()
  local mejor, mejor_version = nil, 0
  for _, ruta in ipairs(vim.fn.glob("/usr/lib/jvm/java-*-openjdk/bin/java", false, true)) do
    local version = tonumber(ruta:match("java%-(%d+)%-openjdk"))
    if version and version >= 21 and version > mejor_version then
      mejor, mejor_version = ruta, version
    end
  end
  return mejor
end

return {
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    -- Forma de funcion porque hay que ANADIR a `cmd`, no reemplazarlo: el extra
    -- lo construye con la ruta de jdtls y, si encuentra el jar de lombok, un
    -- --jvm-arg. Pasar una tabla aqui borraria las dos cosas, ya que lazy.nvim
    -- reemplaza las listas al fusionar opts.
    opts = function(_, opts)
      local java = java_para_el_servidor()
      if java then
        table.insert(opts.cmd, "--java-executable=" .. java)
      end

      opts.settings = vim.tbl_deep_extend("force", opts.settings or {}, {
        java = {
          inlayHints = {
            parameterNames = { enabled = "none" },
          },
          configuration = {
            runtimes = {
              { name = "JavaSE-11", path = "/usr/lib/jvm/java-11-openjdk" },
              { name = "JavaSE-17", path = "/usr/lib/jvm/java-17-openjdk", default = true },
              { name = "JavaSE-21", path = "/usr/lib/jvm/java-21-openjdk" },
            },
          },
        },
      })

      return opts
    end,
  },
}
