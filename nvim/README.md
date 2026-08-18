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
# y, con un .scala abierto:  :MetalsInstall   (Scala; usa coursier)
```

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

Y todos dentro de proyectos **Gradle** (`settings.gradle` + el plugin `scala`,
Scala 2.13, ScalaTest); no hay un solo `build.sbt` en el árbol, aunque `sbt`,
`scala` y `coursier` sí están instalados vía coursier.

El extra `lang.scala` trae nvim-metals, y Metals **implementa el Debug Adapter
por su cuenta**: no hace falta ningún adaptador de mason, basta
`require("metals").setup_dap()` — que el extra ya llama. Con eso quedan las
configuraciones `RunOrTest` y `Test Target`.

Dos cosas del extra no servían tal cual aquí; ver `lua/plugins/scala.lua`.

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
| `scala.lua` | arregla el choque metals/jdtls y el atajo roto del extra; añade el *attach* de Gradle |

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

**Scala.** Metals importa el build a través de Bloop. Gradle es su integración
menos pulida —necesita que el build aplique el plugin `scala`, que es el caso
aquí— y la primera importación tarda. Si no arranca sola: `<leader>mi`
(*import build*) y `<leader>mD` (*doctor*), que dice exactamente qué le falta.

**El camino que siempre funciona, para los dos.** Lanzar la tarea de Gradle
suspendida y engancharse:

```sh
./gradlew test --debug-jvm     # queda esperando en el puerto 5005
./gradlew run  --debug-jvm
```

y desde nvim `<leader>dc`. Para Java el extra `lang.java` ya trae *Debug
(Attach) - Remote* en ese puerto; el equivalente de Scala lo añade `scala.lua`.
Esto depura exactamente lo que ejecuta Gradle, con el classpath y los `jvmArgs`
del `build.gradle` —que en estos talleres importan, porque suben la memoria a
2 GB y el stack a 8 MB—.

## Lo que se dejó igual, a propósito

Hay seis extras habilitados sin un solo archivo de ese lenguaje en
`~/repositorios`: `lang.elm`, `lang.erlang`, `lang.clojure`, `lang.terraform`,
`lang.ansible` y `lang.helm`. Se quedan porque son plausibles para lo que se
enseña (cloud, lenguajes de programación), porque el coste medido es
despreciable —todo se carga de forma diferida— y porque `lang.clojure` es lo que
trae `nvim-paredit`, que ahora usa Racket. Quitarlos es cambiar una línea de
`lazyvim.json` si alguna vez estorban.

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
