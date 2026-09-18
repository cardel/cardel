# Neovim / LazyVim

Configuración de [LazyVim](https://www.lazyvim.org) sobre Neovim 0.12.

```sh
./install.sh
```

Enlaza `nvim/` en `~/.config/nvim`, enlaza `yamllint/config` en
`~/.config/yamllint/config`, instala los plugins que falten respetando
`lazy-lock.json` y descarga las herramientas de mason. Si ya existe una
configuración real (no un enlace), la respalda con marca de tiempo antes de
tocarla.

Dos servidores quedan fuera porque mason no los empaqueta:

```sh
raco pkg install racket-langserver     # Racket
# Scala: metals se baja solo al abrir el primer .scala (necesita coursier)
```

## Requisitos de la máquina

mason no trae compiladores ni runtimes: descarga o compila usando lo que ya haya
en el sistema. De los 35 paquetes que instala esta configuración, 11 vienen de
npm, 5 de PyPI, 2 son extensiones de VS Code (Java) y el resto son binarios de
GitHub. O sea:

| Necesario | Para qué |
|---|---|
| `neovim` ≥ 0.11, `git`, `curl`, `unzip`, `tar` | lo básico de lazy.nvim y mason |
| `nodejs` + `npm` | 11 servidores: json, yaml, bash, docker, ansible, elm, pyright, markdownlint… |
| `python` + `pip` | debugpy, yamllint, ansible-lint, cmakelang |
| `jdk` (≥ 17) | jdtls y sus adaptadores de depuración |
| `racket` (opcional) | solo si se va a usar `racket-langserver` |
| `coursier` | baja metals la primera vez que se abre un `.scala`; no es paquete de pacman, ver `paquetes.txt` |
| `sbt` | metals importa los builds sbt con `sbt bloopInstall` |

Si falta alguno, `install.sh` **no se detiene**: instala todo lo demás y lista al
final lo que falló, con el nombre del paquete. Ese es el sentido de
`mason-bootstrap.lua` — que un servidor roto se vea el día de la instalación y
no dentro de un mes, la primera vez que se abra un archivo de ese tipo. Fue así
como apareció el problema de `erlang-ls`, que se compila con `rebar3`.

## Replicar esto en otra máquina

```sh
git clone <este repo> && cd cardel/nvim && ./install.sh
```

Eso reproduce el entorno **exacto**, no uno parecido. Verificado clonando el
repo en un `XDG_CONFIG_HOME`/`XDG_DATA_HOME` limpios: 60 plugins en el mismo
commit que aquí, `lazy-lock.json` idéntico byte a byte, y los mismos 35 paquetes
de mason. Poco más de un minuto.

Dos cosas que conviene saber antes:

- **`install.sh` reemplaza la configuración que haya**, no la fusiona. Si en la
  otra máquina ya hay un LazyVim con retoques propios, se los lleva por delante
  (los respalda en `~/.config/nvim.bak.<fecha>`, pero respaldar no es fusionar).
  Para conservarlos hay que sacarlos a mano del respaldo y meterlos en
  `lua/plugins/`.
- **`~/.config/nvim` queda como enlace a este repo.** A partir de ahí, cualquier
  `:Lazy update` en cualquiera de las dos máquinas modifica `lazy-lock.json`
  dentro del repo. Es lo que se quiere —así es como se propaga una actualización
  al portátil— pero hay que commitear y hacer push, o las máquinas divergen.

### Por qué install.sh hace copia del lockfile

Parece un rodeo innecesario y no lo es. En una máquina limpia, el primer
arranque de Neovim **destruye `lazy-lock.json`** antes de que nadie pueda
usarlo.

La spec de LazyVim se importa desde el propio plugin LazyVim, así que lazy.nvim
no puede conocer la lista completa hasta haberlo clonado: instala en varias
rondas (`while M.install_missing() do`, en `lazy/core/loader.lua`). Cada ronda
termina llamando a `Lock.update()`, que **vacía la tabla del lockfile en memoria**
y la reescribe con lo que ya hay en disco. En la segunda ronda ya no queda
entrada para los plugins que faltan, y el checkout se va al HEAD de la rama.

Medido: de 60 plugins, 25 quedaron en el commit fijado —los de la primera ronda,
LazyVim incluido— y 35 en HEAD, con el lockfile reescrito. El resultado es
coherente consigo mismo, así que no salta ningún error: simplemente la otra
máquina acaba con versiones distintas.

Ni `:Lazy! install` ni pasarle `lockfile = true` a la API de lua lo evitan,
porque el daño ocurre durante el arranque, antes de que se ejecute cualquier
`-c`. Lo que sí funciona —y es lo que hace `install.sh`— es guardar el archivo
antes, devolverlo después y correr `:Lazy! restore`, que sí lo respeta. Con eso
el resultado es idéntico byte a byte.

## Qué se versiona y qué no

| Ruta | Versionado | Por qué |
|---|---|---|
| `nvim/lua/`, `init.lua`, `lazyvim.json` | sí | es la configuración |
| `nvim/lazy-lock.json` | sí | fija el commit exacto de cada plugin |
| `~/.local/share/nvim/lazy` | no | se reconstruye desde el lockfile |
| `~/.local/share/nvim/mason` | no | se reconstruye desde `mason.ensure_installed` |

`lazy-lock.json` cambia cada vez que se corre `:Lazy update`. Es normal:
commitearlo es lo que hace que el portátil y este PC queden idénticos.

## Diagnóstico de partida

Hasta ahora la configuración era el *starter* de LazyVim sin una sola línea
propia: `lua/config/options.lua`, `keymaps.lua` y `autocmds.lua` eran los
comentarios de plantilla, y `lua/plugins/example.lua` seguía desactivado con su
`if true then return {} end`. Toda la personalización eran los 22 extras de
`lazyvim.json`. Además `~/.config/nvim` no era un repo git, así que no había
forma de replicarla en otra máquina.

Contando archivos en `~/repositorios`, lo que de verdad se edita aquí es:

| Lenguaje | Archivos | Extra | Estado antes |
|---|---:|---|---|
| Markdown | 611 | `lang.markdown` | marksman + markdownlint-cli2 |
| Python | 287 | `lang.python` | pyright + ruff (LSP) |
| Shell | 157 | núcleo | bashls (con shellcheck dentro) + shfmt |
| LaTeX | 166 | `lang.tex` | texlab + vimtex |
| MiniZinc | 147 | — | nada |
| YAML | 145 | `lang.yaml` | solo esquemas, **sin linter** |
| JSON | 118 | `lang.json` | SchemaStore |
| Java | 1607 | `lang.java` | jdtls, **sin depuración ni tests** |
| Scala | 362 | — | **nada** |
| Workflows GH | 107 | — | **sin actionlint** |
| CMake | 104 | `lang.cmake` | neocmakelsp + cmakelint |
| Docker | 84 | `lang.docker` | hadolint |
| Racket | 78 | — | nada |
| BibTeX | 49 | `lang.tex` | texlab |
| TOML | 26 | — | **nada** |

### 1. DAP: no existía

`lazyvim.plugins.extras.dap.core` no estaba habilitado, así que `nvim-dap` no
estaba instalado. El detalle importante es que los extras de lenguaje declaran su
bloque de depuración con `optional = true`, o sea que **se quedan inertes
mientras nvim-dap no exista**. Estaba pagando el precio sin recibir nada:

- `lang.python` tiene lista la integración con `nvim-dap-python`
  (`<leader>dPt` método, `<leader>dPc` clase) — no hacía nada.
- `lang.java` declara `java-debug-adapter` y `java-test`, y `nvim-jdtls` pasa
  `dap = {...}`, `dap_main = {}`, `test = true` a jdtls — no hacía nada.
- `test.core` instala neotest, que sabe correr un test con `strategy = "dap"` —
  no había forma de invocarlo.

Habilitar `dap.core` despierta los tres de golpe. Se confirmó tras el cambio:
mason instaló `java-debug-adapter` y `java-test` por su cuenta, y
`dap.configurations` quedó con entradas para `java`, `lua`, `python` y `sh`.

### 2. Linters: nvim-lint estaba, pero casi vacío

Sumando todos los extras, la tabla efectiva era:

```
fish       -> fish                (del núcleo; aquí se usa zsh)
cmake      -> cmakelint
dockerfile -> hadolint
markdown   -> markdownlint-cli2
terraform  -> terraform_validate
```

Dos casos parecen faltar y no faltan: **Python** pasa por `ruff` como servidor
LSP, no por nvim-lint, y **shell** por el shellcheck que `bash-language-server`
invoca internamente.

Los huecos reales eran YAML (145 archivos sin revisar) y los workflows de GitHub
(107, donde `yaml-language-server` valida el esquema pero no entiende `${{ }}`
ni los `runs-on`). Al conectar actionlint, lo primero que reportó fueron dos
acciones obsoletas en `notasUniversidad/.github/workflows/pages.yml`.

### 3. Scala: 362 archivos sin nada

En el PC de mesa, todos dentro de proyectos **Gradle** (`settings.gradle` + el
plugin `scala`, Scala 2.13, ScalaTest). En el portátil es al revés: 304 `.scala`
y casi todos bajo un `build.sbt` (`IdeaProjects/`, `clases/`, `FundProFunConc/`,
Scala 3.8.1 y 2.13.18), con 21 `settings.gradle` además. La configuración cubre
los dos.

El extra `lang.scala` trae nvim-metals, y Metals **implementa el Debug Adapter
por su cuenta**: no hace falta ningún adaptador de mason, basta
`require("metals").setup_dap()` — que el extra ya llama. Con eso quedan las
configuraciones `RunOrTest` y `Test Target`.

Dos cosas del extra no servían tal cual aquí; ver `lua/plugins/scala.lua`.

#### Y después, "nvim no funciona con Scala" (2026-09-17)

Abrir cualquier `.scala` en el portátil daba una pantalla roja con `-- More --`
y ningún servidor. Reproducido en un pty:

```
FileType Autocommands for "scala": Lua callback:
  nvim-metals/lua/metals/install.lua:91: attempt to index local 'config' (a nil value)
  in function 'install'   <- lua/plugins/scala.lua:53
```

Era nuestro propio auto-instalador. `require("metals").install()` lee una caché
interna de configuración que solo rellena `initialize_or_attach()` (vía
`validate_config`), y `scala.lua` registraba el autocmd de instalación **antes**
que el de attach; los autocmds del mismo evento corren en orden de registro, así
que `install()` llegaba con la caché vacía y reventaba en cada apertura. Encima
el error salía en el propio FileType, y como metals nunca se había bajado en esa
máquina (`~/.cache/nvim/nvim-metals/` sólo tenía un log), no había LSP ni con
`:MetalsInstall` a mano.

El orden correcto es el que nvim-metals espera de un humano: attach (que con el
binario ausente no arranca nada, sólo valida y avisa) y luego install. La
instalación es asíncrona y al terminar nvim-metals sólo dice "Start/Restart the
server", no engancha nada; un temporizador espera al binario y engancha los
buffers de Scala abiertos. No se usa la variante síncrona `install(true)`:
bloquea nvim y tiene un tope fijo de 60 s, y la bajada tarda 23 s medidos con
la caché de coursier vacía. El aviso "Welcome… use `:MetalsInstall`" que suelta
la primera llamada —seis notificaciones, una por línea— se silencia sólo durante
esa llamada, porque contradice al aviso nuestro que sale justo después.

Medido de punta a punta: metals 1.6.9 se baja y engancha solo en 8-23 s;
hover devuelve tipos reales; `RunOrTest` con un breakpoint para en la línea,
Scopes muestra `n int = 5, acc int = 1`, el REPL evalúa, step over avanza. En
Scala **3.8.1** el log avisa que no hay expression-compiler ni decodificador de
frames publicados para esa versión (usa uno compatible; un step over desde el
cuerpo de un `for` cae en `Range.foreach`). En **2.13.18**, la de las clases,
cero avisos.

Tres cosas más que salieron de mirarlo funcionar:

- **El build target de Bloop es el id del proyecto sbt, no su `name :=`.** Con
  `lazy val root = (project in file(".")).settings(name := "app")` sbt genera
  `.bloop/root.json` y `root-test.json`. El *attach* del `scala.lua` anterior
  fijaba `buildTarget = "app"` (el subproyecto de `gradle init`) y habría
  fallado en todos los proyectos sbt sin decir por qué. Ahora lo lee de
  `.bloop/` al lanzar, y pregunta si hay varios.
- **El extra pone `statusBarProvider = "off"`**, y con eso importar un build
  (sbt arrancando, 20-30 s) es silencio absoluto: lo que se percibe como
  "colgado". Con `"on"`, nvim-metals escribe `vim.g.metals_status` y lualine
  lo muestra (`Importing build`, `Compiling root`, `Indexing complete!`).
- **Codelens**: metals pinta `run | debug` sobre cada `@main` y `test | debug
  test` sobre cada suite; `<leader>cc` ejecuta el del cursor. LazyVim los trae
  apagados para todos los servidores; aquí se refrescan sólo en buffers de
  Scala.

### 4. Racket sin soporte

78 archivos `.rkt` (los talleres de FLP) y ni resaltado por treesitter ni LSP.
No hay extra de LazyVim para Racket, pero el parser existe, `racket-langserver`
se instala con `raco`, y `nvim-paredit` **ya estaba instalado** por el extra
`lang.clojure` — solo le faltaba tener `racket` en su lista de filetypes.

## Qué cambió

En `lazyvim.json`:

- `dap.core` — nvim-dap, dap-ui, virtual-text, mason-nvim-dap
- `dap.nlua` — depurar la propia configuración de Neovim
- `lang.scala` — nvim-metals, con su propio Debug Adapter
- `lang.toml` — taplo (26 archivos, incluidos los de este repo)

Archivos nuevos en `lua/plugins/`, cada uno independiente y borrable por
separado:

| Archivo | Qué hace |
|---|---|
| `dap.lua` | `debugpy` y `bash-debug-adapter` en mason; `<leader>td` para depurar el test bajo el cursor |
| `linting.lua` | yamllint para YAML, actionlint restringido a `.github/workflows/`, shellcheck explícito |
| `racket.lua` | parser de treesitter, `racket_langserver`, paredit en `.rkt` |
| `scala.lua` | baja metals solo la primera vez y lo engancha; arregla el choque metals/jdtls y el atajo roto del extra; estado en lualine, codelens `run \| debug`, árbol de metals (`<leader>mt`); *attach* al puerto 5005 con el build target leído de `.bloop/` |

Y `yamllint/config`, que baja el ruido de las reglas de fábrica. Un `.yamllint`
dentro de un proyecto sigue teniendo prioridad sobre él.

Cuatro detalles que se comprobaron a mano, porque las recetas que circulan los
tienen mal o porque los extras de LazyVim no encajan con el resto de esta
configuración:

- Neovim 0.12 le pone filetype `yaml` a secas a los archivos de
  `.github/workflows/`, no `yaml.github`. Por eso actionlint va en la lista de
  `yaml` y se filtra con `condition`, no con un filetype aparte.
- LazyVim declara mason con `cmd = "Mason"` solamente, así que en un arranque
  headless `:MasonInstall` no existe hasta que se carga el plugin a mano.
- El extra `lang.scala` ata metals a los filetypes `scala`, `sbt` **y `java`**.
  Con `lang.java` habilitado eso significaba dos servidores sobre el mismo
  buffer: al abrir un `.java` arrancaban jdtls y metals, y metals se ponía a
  pedir permiso para importar el build. `scala.lua` reemplaza el `config` del
  extra para limitar el autocmd a Scala (`ft` no se puede recortar: lazy.nvim
  concatena esas listas entre specs, no las reemplaza). Comprobado: ahora un
  `.java` solo levanta jdtls.
- El mismo extra mapea `<leader>me` a `require("telescope")`, pero LazyVim usa
  snacks.picker desde la v15 y aquí no hay telescope: ese atajo reventaba con
  *module 'telescope' not found*. Se cambió por `require("metals").commands()`,
  que usa `vim.ui.select`.

Resultado: 60 plugins (0 con error), 35 paquetes de mason, ~234 ms de arranque
con un `.py` abierto.

## Depurar proyectos Gradle

Casi todo lo que hay aquí compila con Gradle: 51 wrappers `gradlew` en el árbol,
y tanto los talleres de Java como los de Scala. No hace falta nada específico de
Gradle en la configuración, pero conviene saber por dónde va cada camino.

**Java.** jdtls importa proyectos Gradle por su cuenta —usa el Tooling API, no
el `gradle` del sistema, así que basta con el wrapper del proyecto—. Comprobado
sobre `Talleres-base/ada-2023-2-…`: arranca el demonio de Gradle, sincroniza el
módulo y queda `ServiceReady`. Con `dap.core` habilitado, `dap_main` escanea las
clases `main` del proyecto y `test = true` engancha java-test, así que
`<leader>dc` ya lista configuraciones reales.

**Scala.** Metals importa el build a través de Bloop. Con sbt pregunta al abrir
el proyecto ("New sbt workspace detected…" → *Import build*) y ejecuta
`sbt bloopInstall`; con Gradle necesita que el build aplique el plugin `scala`.
La primera importación tarda y lualine lo va contando. Si no arranca sola:
`<leader>mi` (*import build*) y `<leader>mD` (*doctor*), que dice exactamente
qué le falta. `<leader>mt` abre el árbol de metals, con las suites de test.

Para depurar: breakpoint con `<leader>db`, `<leader>dc` → `RunOrTest`; o
`<leader>cc` sobre el `run | debug` que metals pinta encima del `main`.

**El camino que siempre funciona, para los dos.** Lanzar la herramienta de
build suspendida en el puerto 5005 y engancharse (`<leader>dc` → *Attach*):

```sh
sbt -jvm-debug 5005 run        # sbt; igual con test
./gradlew test --debug-jvm     # Gradle
./gradlew run  --debug-jvm
```

y desde nvim `<leader>dc`. Para Java el extra `lang.java` ya trae *Debug
(Attach) - Remote* en ese puerto; el equivalente de Scala lo añade `scala.lua`.
Esto depura exactamente lo que ejecuta Gradle, con el classpath y los `jvmArgs`
del `build.gradle` —que en estos talleres importan, porque suben la memoria a
2 GB y el stack a 8 MB—.

## Lo que se dejó igual, a propósito

Quedan cinco extras habilitados sin un solo archivo de ese lenguaje en
`~/repositorios`: `lang.elm`, `lang.clojure`, `lang.terraform`, `lang.ansible` y
`lang.helm`. Se quedan porque son plausibles para lo que se enseña (cloud,
lenguajes de programación), porque sus servidores se instalan y cargan sin
problema, y porque `lang.clojure` es lo que trae `nvim-paredit`, que ahora usa
Racket.

**`lang.erlang` sí se quitó**, porque no era gratis: declara el servidor
`erlangls`, cuyo paquete de mason (`erlang-ls`) se compila desde el fuente con
`rebar3 escriptize`. En esta máquina no hay Erlang —ni `erl`, ni `rebar3`, ni
`escript`—, así que mason fallaba con `bash: line 2: rebar3: command not found`
cada vez que intentaba instalarlo. Con cero archivos `.erl` en el árbol, la
respuesta correcta era quitar el extra, no instalar una toolchain de Erlang.

Si alguna vez hace falta Erlang, hay dos caminos: reactivar el extra tras
`pacman -S erlang rebar3`, o mejor usar `elp` (Erlang Language Platform, de
WhatsApp), que mason distribuye como binario precompilado y no necesita
toolchain.

También se probó y se descartó **ltex-ls-plus** para revisar gramática y
ortografía en español en Markdown y LaTeX. Funcionaba —detectaba concordancia y
tildes, con los mensajes en español, igual que el `ltex` que Zed ya tiene
configurado en `zed/settings.json`— pero es un servidor Java con LanguageTool
dentro: ~500 MB de RSS y varios segundos hasta el primer diagnóstico cada vez
que se abre un `.md`. Para revisar prosa está Zed. Si alguna vez se quiere de
vuelta, es un archivo en `lua/plugins/` con `ltex_plus` y
`settings.ltex.language = "es"`.

## Ideas para después

- `ai.claudecode` — extra de LazyVim para Claude Code dentro del editor.
- `editor.harpoon2` o `util.project` — saltar entre repos, que aquí hay ~100.
- Un `.markdownlint.yaml` propio: las reglas de fábrica son estrictas con las
  líneas largas y los encabezados repetidos.
- MiniZinc son 147 archivos y no hay nada: ni parser de treesitter ni LSP
  decente. Habría que escribirlo.
