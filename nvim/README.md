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

Un paso queda fuera porque mason no lo empaqueta:

```sh
raco pkg install racket-langserver
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

### 3. Prosa en español: el hueco más grande

Entre Markdown, LaTeX y BibTeX son ~826 archivos, casi todos en español, y
Neovim no revisaba una sola palabra. texlab y marksman ven estructura;
markdownlint-cli2 ve estilo de Markdown, no prosa.

Zed ya lo tenía resuelto (`zed/settings.json` → `lsp.ltex.settings.ltex.language
= "es"`). Ahora Neovim usa el mismo servidor con la misma configuración, en la
variante mantenida (`ltex-ls-plus`; el `ltex-ls` original lleva años sin
releases). Comprobado sobre un texto de prueba: detecta concordancia (*«un
prueba»*, *«los estudiante»*) y tildes faltantes, con los mensajes en español.

### 4. Racket sin soporte

78 archivos `.rkt` (los talleres de FLP) y ni resaltado por treesitter ni LSP.
No hay extra de LazyVim para Racket, pero el parser existe, `racket-langserver`
se instala con `raco`, y `nvim-paredit` **ya estaba instalado** por el extra
`lang.clojure` — solo le faltaba tener `racket` en su lista de filetypes.

## Qué cambió

En `lazyvim.json`:

- `dap.core` — nvim-dap, dap-ui, virtual-text, mason-nvim-dap
- `dap.nlua` — depurar la propia configuración de Neovim
- `lang.toml` — taplo (26 archivos, incluidos los de este repo)

Archivos nuevos en `lua/plugins/`, cada uno independiente y borrable por
separado:

| Archivo | Qué hace |
|---|---|
| `dap.lua` | `debugpy` y `bash-debug-adapter` en mason; `<leader>td` para depurar el test bajo el cursor |
| `linting.lua` | yamllint para YAML, actionlint restringido a `.github/workflows/`, shellcheck explícito |
| `prose.lua` | `ltex-ls-plus` en español para md/tex/bib/gitcommit |
| `racket.lua` | parser de treesitter, `racket_langserver`, paredit en `.rkt` |

Y `yamllint/config`, que baja el ruido de las reglas de fábrica. Un `.yamllint`
dentro de un proyecto sigue teniendo prioridad sobre él.

Dos detalles que se comprobaron a mano porque las recetas que circulan los
tienen mal:

- Neovim 0.12 le pone filetype `yaml` a secas a los archivos de
  `.github/workflows/`, no `yaml.github`. Por eso actionlint va en la lista de
  `yaml` y se filtra con `condition`, no con un filetype aparte.
- LazyVim declara mason con `cmd = "Mason"` solamente, así que en un arranque
  headless `:MasonInstall` no existe hasta que se carga el plugin a mano.

Resultado: 59 plugins (0 con error), 36 paquetes de mason, ~234 ms de arranque
con un `.py` abierto.

## Lo que se dejó igual, a propósito

Hay seis extras habilitados sin un solo archivo de ese lenguaje en
`~/repositorios`: `lang.elm`, `lang.erlang`, `lang.clojure`, `lang.terraform`,
`lang.ansible` y `lang.helm`. Se quedan porque son plausibles para lo que se
enseña (cloud, lenguajes de programación), porque el coste medido es
despreciable —todo se carga de forma diferida— y porque `lang.clojure` es lo que
trae `nvim-paredit`, que ahora usa Racket. Quitarlos es cambiar una línea de
`lazyvim.json` si alguna vez estorban.

## Ideas para después

- `ai.claudecode` — extra de LazyVim para Claude Code dentro del editor.
- `editor.harpoon2` o `util.project` — saltar entre repos, que aquí hay ~100.
- Un `.markdownlint.yaml` propio: las reglas de fábrica son estrictas con las
  líneas largas y los encabezados repetidos.
- Poblar `ltex.dictionary.es` en `prose.lua` con la jerga recurrente (nombres de
  herramientas, términos técnicos) para que deje de marcarlos.
