# Zed

Editor para documentos en LaTeX, con vim, corrector en espanol y Copilot.
Medido sobre **Zed 1.16.2** (`/usr/lib/zed/zed-editor`), extension LaTeX 0.2.3,
texlab 5.26.0.

```bash
./install.sh          # enlaza y avisa de lo que falta en el sistema
```

## Que hay aqui

| Archivo | Va a |
|---|---|
| `settings.json` | `~/.config/zed/settings.json` |
| `keymap.json` | `~/.config/zed/keymap.json` |
| `tasks.json` | `~/.config/zed/tasks.json` |
| `debug.json` | `~/.config/zed/debug.json` |
| `snippets/` | `~/.config/zed/snippets/` |
| `themes/` | `~/.config/zed/themes/` |

Todo enlazado, no copiado.

## Enlazar `settings.json` es seguro, aunque Zed lo reescriba

Zed reescribe `settings.json` cada vez que se cambia algo desde la interfaz —
mover un panel, por ejemplo. Con otros programas eso destruiria el enlace: la
escritura atomica normal crea un temporal y lo renombra encima, y el symlink
desaparece.

Zed no. Resuelve el enlace antes de escribir
(`crates/settings/src/settings_store.rs`: `canonicalize()` y luego
`atomic_write()` sobre la ruta ya resuelta), de modo que el archivo del repo
recibe el cambio y el enlace sigue en pie. Es lo contrario de lo que hace
Firefox con `prefs.js` — ver `obs/README.md`.

Ventaja practica: los ajustes que se toquen desde la interfaz aparecen en
`git status` en vez de perderse. Asi se descubrio que la copia anterior llevaba
meses desviada, con cuatro bloques de paneles que el repo no tenia.

## LaTeX

### texlab no puede compilar aqui, y por eso lo hacen las tareas

texlab expone compilar y saltar al PDF como **comandos LSP**
(`workspace/executeCommand`), y **Zed no tiene forma de invocar un comando LSP
arbitrario**: no hay accion, ni orden de la paleta, ni nada en la extension (su
`extension.toml` declara `capabilities = []` y ningun `slash_command`).

O sea: el unico disparador que texlab ofrece a Zed es **guardar**. Y encenderlo
(`build.onSave: true`) no sirve aqui, por dos motivos medidos sobre
`~/repositorios/work/papers-project`:

- **Fallaria en cada guardado.** Sus papers resuelven `infedu.cls` por
  `TEXINPUTS` desde `template/`. Sin esa variable no aparece —
  `env -u TEXINPUTS kpsewhich infedu.cls` no devuelve nada — y latexmk, que es
  lo que texlab lanza, no la exporta.
- **Ensuciaria el arbol.** La regla 4.4 de ese repositorio exige que nada se
  escriba junto a las fuentes y que los intermedios se borren al terminar cada
  build. latexmk hace justo lo contrario: conserva `.fdb_latexmk` y los
  auxiliares para poder compilar incremental.

Asi que `build.onSave` queda en **`false`** y el trabajo lo hacen las tareas:

| Tecla | Que hace |
|---|---|
| `space l b` | busca un `Makefile` subiendo desde el `.tex` y lo usa; sin Makefile, latexmk |
| `space l v` | abre el PDF en la linea del cursor, y dejando armada la vuelta |

`space l v` no pasa por texlab: llama a zathura con `--synctex-forward` usando
`$ZED_ROW` y `$ZED_COLUMN`, y su `-x` deja montada la busqueda inversa. Busca el
PDF en `build/` antes que junto al fuente, y sube un nivel para que
`letters/cover-letter.tex` encuentre `../build/cover-letter.pdf`. Comprobado con
los tres casos reales del paper de INFEDU.

`autosave` esta en `"off"` de todas formas: si algun proyecto enciende
`build.onSave`, el autoguardado convertiria cada pausa al teclear en una
compilacion.

**Para un `.tex` suelto**, sin Makefile ni TEXINPUTS, compilar al guardar si es
comodo. Eso se enciende en el `.zed/settings.json` de ese proyecto:

```json
{ "lsp": { "texlab": { "settings": { "texlab": {
  "build": { "onSave": true, "forwardSearchAfter": true }
} } } } }
```

Ahi si entra en juego el bloque `forwardSearch` de `settings.json`.

### `latexmk` no estaba instalado, y es el compilador por defecto

La extension rellena `build.executable` con `latexmk` cuando uno no lo pone. En
Arch `latexmk` viene en **`texlive-binextra`**, que no estaba: de los doce
paquetes de texlive instalados, ninguno lo trae. Compilar fallaba antes de
empezar.

`build.executable` se deja **sin poner a proposito**. El preajuste de la
extension pasa un `-e '$pdf_mode = 1 unless $pdf_mode != 0;'` que respeta el
`.latexmkrc` del proyecto — de modo que un documento que necesite XeLaTeX solo
tiene que traer `$pdf_mode = 5;` en su `.latexmkrc`. Fijar aqui un `-pdf` pelado
pisaria ese archivo y forzaria pdflatex en todos lados.

### El visor se pone a mano porque evince gana la deteccion

La extension detecta un visor y configura la busqueda directa sola. El orden en
que prueba (`src/texlab_workspace_config/preview_presets.rs`, funcion
`determine`) es: Skim en mac, SumatraPDF en Windows, y despues **evince antes que
zathura, sioyek, okular o qpdfview**.

Aqui solo habia evince, asi que gano, y la extension llego a descargarse su
script de apoyo — `~/.local/share/zed/extensions/work/latex/evince_synctex.py`
esta en disco desde abril. El problema es que instalar zathura **no cambiaria
nada**: evince seguiria ganando.

La escapatoria es que la extension **nunca pisa un `forwardSearch` puesto por el
usuario**. Por eso `settings.json` lo fija a zathura a mano. Zathura es ademas lo
que uno quiere aqui: se maneja con teclas de vim, y hace busqueda directa e
inversa.

Sobre los `%%` de esos argumentos: texlab sustituye `%f`, `%l` y `%p`, y colapsa
`%%` en un `%` literal — esta en su propio test unitario
(`crates/commands/src/placeholders.rs`: `"%%f"` → `"%f"`). Ese `%` literal es el
que necesita zathura para su `%{input}` y `%{line}`. Un solo `%` ahi romperia la
busqueda inversa en silencio.

La busqueda inversa llama a **`zeditor`**, no a `zed`: es como se llama el
binario en Arch. La extension conoce los dos nombres, pero aqui esta escrito a
mano y hay que respetarlo.

### chktex venia apagado

Igual que en Neovim (ver el `CLAUDE.md` de la raiz): texlab trae chktex
desactivado de fabrica, y `chktex` lleva instalado todo este tiempo en
`/usr/bin`. Ahora se enciende con `onOpenAndSave`, no con `onEdit` — en cada
pulsacion se nota en un documento largo.

Ojo con donde va: en texlab `chktex` es una clave **de primer nivel**, no algo
dentro de `diagnostics` (`crates/texlab/src/server/options.rs`).

### El corrector en espanol nunca se ejecuto

`settings.json` llevaba un bloque `lsp.ltex` con `language: "es"`, y el
`CLAUDE.md` de la raiz lo daba por hecho. **La extension ltex no estaba
instalada**: solo habia `latex`, `dockerfile`, `html` y `log`. Zed acepta
cualquier clave bajo `lsp` sin quejarse, asi que la configuracion estaba ahi sin
servidor detras. Comprobado con `grep -aic 'ltex'` sobre el log historico de Zed
(1 MB): cero apariciones.

Ahora la instala Zed sola, por `auto_install_extensions`. **Descarga unos
320 MB** la primera vez: el unico artefacto de Linux que publica LTeX+ trae su
propio JRE dentro.

Con que idioma revisa, y por que no hay que tocarlo, mas abajo.

## LaTeX y Markdown son prosa, y Zed solo lo sabe de uno

Zed trae un trato de "prosa" para Markdown, Plain Text y Git Commit. Para
**LaTeX no**: su bloque por defecto se limita a fijar el formateador y el
servidor. Aqui se le da el mismo trato, que es lo que corresponde a un lenguaje
que es texto corrido con marcas.

Lo que cambia, y por que:

- **`allow_rewrap: "anywhere"`.** Es lo que hace que `gq` funcione. Por defecto
  LaTeX hereda `"in_comments"`, y en el codigo de Zed eso es literal
  (`crates/editor/src/rewrap.rs`): `InComments => inside_comment`. O sea que
  `gqip` sobre un parrafo no hacia absolutamente nada, y solo refluia dentro de
  un comentario con `%`.
- **`remove_trailing_whitespace_on_save: false`.** Con el valor por defecto
  (`true`), abrir y guardar cualquiera de los **28 archivos** del workspace de
  papers que llevan espacios finales produce un diff de lineas que no se
  tocaron, en manuscritos firmados por varias personas. Zed ya hace esta misma
  excepcion con Markdown y con Diff.
- **`completions.words: "disabled"`.** Sin esto el menu se llena de palabras
  sacadas del propio buffer y tapa lo util, que son las de texlab (`\cite`,
  `\ref`, `\label`) y las de Copilot. Mismo criterio que Markdown.
- **80 columnas**, no 100. No es un numero redondo elegido a ojo: es a lo que
  esta escrito el material. En `main.tex`, 1201 de 1247 lineas no vacias caben
  en 80 y la mediana es 70; los `.md` del workspace dan p90 entre 76 y 82. El
  `wrap_guides` pinta la marca donde toca cortar.

## Mermaid y formulas en Markdown

Dos cosas que suenan parecidas y se resuelven de forma distinta.

**Los diagramas mermaid los dibuja Zed solo.** No hace falta instalar nada: el
binario lleva un crate propio, `mermaid_render`, y los colorea con el tema del
editor. Se ven con `space m p`. La extension `mermaid` que declara
`auto_install_extensions` es solo para colorear el codigo mientras se escribe.

**Las formulas no se renderizan, y es a proposito.** El parser de Markdown de
Zed no activa `ENABLE_MATH` — de hecho la lista se llama `UNWANTED_OPTIONS` y
`ENABLE_MATH` esta dentro (`crates/markdown/src/parser.rs`), y los eventos
`InlineMath` y `DisplayMath` se descartan con un brazo vacio. Tampoco hay
extension que lo arregle: el registro no devuelve nada para *math*, *katex* ni
*latex-markdown*.

La salida es pasar por pandoc, que si las renderiza. `space m f` convierte el
archivo actual con `pandoc --pdf-engine=xelatex` y lo abre. Escribe en
`$TMPDIR/zed-md/`, nunca junto al fuente, para no ensuciar ningun repositorio.
Comprobado con `$a^2+b^2=c^2$` y un sumatorio: salen bien.

Lo que pandoc **no** hace por su cuenta es rasterizar los mermaid; para eso esta
`space m d`, que llama a `pdfgithub/generate-pdf.sh` sobre la carpeta entera y
usa `mmdc`. Resumen:

| Quiero | Tecla | Lo hace |
|---|---|---|
| ver diagramas mermaid | `space m p` | Zed, nativo |
| ver formulas | `space m f` | pandoc + xelatex |
| ambas cosas, en PDF | `space m d` | pdfgithub + mmdc |

## Snippets

En `snippets/`, enlazados a `~/.config/zed/snippets/`. Se escribe el prefijo y
se acepta con Tab.

Los prefijos de LaTeX no son genericos: salen de contar el uso real en el
workspace de papers — `table` 82, `tabular` 57, `figure` 39, `enumerate` 37,
`tikzpicture` 34, `tabularx` 27; y en macros, `cite` 490, `label` 277, `cref`
213, `parencite` 95, `textcite` 55. De ahi `fig`, `tab`, `tabx`, `tikz`, `plot`,
`cite`, `tcite`, `cref`, `Cref`, `lab`, `sec`, `eq`.

Dos detalles del formato, comprobados en `crates/snippet` de Zed:

- **Admiten comentarios**, porque los lee con `serde_json_lenient`.
- **La barra invertida escapa solo ante `$`, `\` y `}`.** Para que salga el `\\`
  de final de fila de LaTeX hacen falta cuatro en el origen, que en JSON se
  escriben como ocho. Por eso tampoco hay snippet de matematica en linea: el `$`
  fuera de un marcador habria que escaparlo, y el autoclose de la extension ya
  cierra el `$` solo.

## El corrector cambia de idioma solo

`ltex.language` esta en `es`, pero **24 de los 25 `.tex` del workspace estan en
ingles**, y aun asi no hay que tocar nada: LTeX+ lee los comandos de babel y
cambia su idioma segun lo que declare el documento. `\usepackage[american]{babel}`,
que es lo que traen esos papers, esta explicitamente entre los que reconoce. El
`es` de aqui es solo el respaldo para lo que no declare idioma.

Para un documento sin babel, el snippet `ltex` inserta la linea magica:

```latex
% LTeX: language=en-US
```

## Atajos

El keymap de vim que trae Zed **ya sigue las convenciones de nvim moderno**, asi
que aqui no se repiten. Funcionan de fabrica:

| Tecla | Que hace |
|---|---|
| `K`, `g h` | hover |
| `g d` / `g y` / `g I` | definicion / tipo / implementacion |
| `g r r` / `g r n` / `g r a` | referencias / renombrar / acciones |
| `] d` / `[ d` | diagnostico siguiente / anterior |
| `] c` / `[ c` | cambio de git siguiente / anterior |
| `g O` | esquema del archivo |

Lo que se anade aqui es lo que falta:

| Tecla | Que hace |
|---|---|
| `space l b` / `space l w` | compilar / compilar en continuo |
| `space l v` / `space l c` / `space l n` | ver PDF en esta linea / limpiar / contar palabras |
| `space m p` / `space m s` | vista previa de Markdown (mermaid incluido) |
| `space m f` / `space m d` | Markdown con formulas / PDF de la carpeta |
| `space w h j k l` | dividir la ventana |
| `space u w` / `space u l` / `space u i` / `space u a` | ajuste de linea / numeros / pistas / Copilot |
| `space b d` / `space b q` | cerrar este / cerrar los demas |
| `j k a A d r c x p y p y r` | panel de proyecto con teclas de vim |

### Dos atajos que no hacian nada

**Los seis `task::Spawn` del keymap apuntaban al vacio.** `tasks.json` no
existia — ni en el repo ni en `~/.config/zed/`. Un `task::Spawn` cuyo `task_name`
no aparece en ningun sitio no hace nada ni deja rastro, asi que `-` (yazi),
`space g g` (lazygit), `space f f`, `space f d`, `space s g` y `space o s`
llevaban tiempo muertos.

**Un prefijo y una secuencia larga no pueden compartir tecla.** Habia
`space g` (panel de git) junto a `space g g` (lazygit), y `space o` (esquema)
junto a `space o s` (Obsidian). El panel de git paso a `space g s` y Obsidian a
`space n o`.

### Del repo de referencia se cogio poco, a proposito

`Nexseer/zed-config` sirvio para el panel de proyecto con teclas de vim, que es
lo mejor que tiene. Lo demas se dejo fuera:

- Reata `K`, `g d`, `g r`, `g i` y las de hunks, que Zed ya trae.
- Usa `editor::GoToPrevHunk`, que **ya no existe** — el nombre bueno es
  `editor::GoToPreviousHunk`. Un nombre de accion invalido no da error en Zed:
  el atajo simplemente no responde.
- Pisa `H` y `L` para cambiar de pestana. En vim son ir al principio y al final
  de la pantalla, y quien lleva anos con vim los usa.

## Copilot

Funciona: el `copilot-language-server` 1.534.0 arranca e inicializa bien (visto
en `~/.local/share/zed/logs/`). Se autentica por su cuenta, en
`~/.config/github-copilot/auth.db`, y **no usa el token de `gh`** — los ambitos
de ese token ni siquiera incluyen Copilot.

Dos cosas por decidir, que no se tocaron porque son gusto personal:

- El modelo esta fijado a **`gpt-4.1`**, tanto para el chat como para el asistente
  en linea. Copilot ofrece hoy modelos bastante mejores; se cambia desde el
  desplegable del panel del agente, y al hacerlo Zed lo escribe en este mismo
  `settings.json` (que ahora esta enlazado, asi que el cambio queda versionado).
- Las predicciones estan activas tambien en LaTeX. Escribiendo prosa pueden
  molestar; `space u a` las apaga y enciende sin tocar la configuracion.

### Ajustes obsoletos: Zed avisa, pero con una notificacion

Zed lleva un migrador (`crates/migrator/`, 43 reglas) y, cuando encuentra una
clave vieja, muestra una notificacion — *"file uses deprecated settings which can
be automatically updated"* — **no un error**. El ajuste viejo se sigue leyendo,
asi que nada parece roto y es facil convivir con el durante meses.

Este archivo llevaba una: `features.edit_prediction_provider`, que la migracion
`m_2026_02_02` mueve a `edit_predictions.provider` (y borra `features` si queda
vacio). Venia heredada de la configuracion anterior.

El valor va como **cadena**, no como objeto. Poner `{ "name": "copilot" }` da
`unknown variant 'name', expected one of 'none', 'copilot', 'zed', 'codestral',
'ollama', 'open_ai_compatible_api', 'mercury'`.

El resto esta al dia. Cruzadas las 43 reglas contra todas las claves y acciones
de aqui, las unicas coincidencias son nombres **destino**, no obsoletos:
`agent_ui_font_size` (regla `m_2025_10_03`, que renombra `agent_font_size`),
`menu::SelectPrevious`, `editor::ToggleEditPrediction`,
`workspace::ActivatePaneLeft` y `vim::PushAddSurrounds`. De paso queda claro que
el `workspace::ActivatePaneInDirection` del repo de referencia es justamente la
forma vieja.

Para revisarlo en el futuro, sin leer las 43 reglas a mano:

```bash
# nombres obsoletos (origen) frente a los nuevos (destino) en cada regla
grep -rn '("[a-z_:]*", "[a-z_:]*")' crates/migrator/src/migrations/
```

### Un error del log que no significa nada

En cada escritura de `settings.json` aparece:

```
ERROR [crates/zed/src/main.rs:1917] missing field `name` at line 171 column 1
```

**Es ruido y se puede ignorar.** Zed mete el archivo de ajustes en un
deserializador que exige un `name` de primer nivel — la forma de un tema — y eso
no depende de lo que haya dentro: con `settings.json` reducido a `{}` el mensaje
sale igual, y la posicion sigue al archivo (`line 1 column 2` con `{}`,
`column 23` con `{"theme": "One Dark"}`, `line 171 column 1` con el archivo
completo). Tampoco es la carpeta `themes/`: quitandola sigue saliendo.

Lo que si importa es el **otro** mensaje, que es el de verdad:

```
ERROR [zed::zed] Failed to load user settings: ...
```

Ese aparece solo cuando un valor esta mal, y es el que hay que mirar.

## `agent_font_size` no existe

Estaba en el archivo y no hacia nada. Zed solo conoce `agent_ui_font_size` y
`agent_buffer_font_size` — comprobado contra su `default.json` y contra el
binario, cero apariciones de la otra.

## La fuente fallaba en silencio

`ui_font_family` y `buffer_font_family` piden **IosevkaTerm Nerd Font**. No
estaba instalada: `fc-list` no devolvia ni una familia Iosevka y `fc-match`
resolvia a Noto Sans, asi que Zed llevaba meses pintando con otra sin decirlo —
que es como falla una fuente que falta, sin ningun aviso. Ya esta puesta
(`ttf-iosevkaterm-nerd`), y `install.sh` lo comprueba en cada ejecucion.

## Lo que hay que instalar

La lista vive en **`paquetes.txt`**, no en el README ni dentro del script, para
que anadir una tarea que llame a un programa nuevo sea una fila y no un cambio
de codigo. `install.sh` la lee para las dos cosas: comprobar que hay y construir
la orden de pacman.

En una maquina nueva:

```bash
./install.sh --paquetes       # imprime la orden con todo lo que espera
./install.sh                  # enlaza, y avisa de lo que siga faltando
```

Hoy son estos, todos en `extra`, ninguno del AUR:

| Paquete | Para |
|---|---|
| `zed` | el editor, y el CLI `zeditor` de la busqueda inversa |
| `texlive-binextra` | `latexmk` (compilar) y `texcount` (contar palabras) |
| `texlive-bin` | `chktex`, los avisos dentro del editor |
| `zathura` + `zathura-pdf-mupdf` | ver el PDF con synctex en las dos direcciones |
| `ttf-iosevkaterm-nerd` | la fuente que pide `settings.json` |
| `pandoc-cli` | formulas en Markdown |
| `mermaid-cli` | rasterizar mermaid en el PDF de la carpeta |
| `lazygit` | la tarea de `space g g` |

**Dos nombres que no coinciden con su binario**, y que cuestan un rato si se
copian mal: el paquete de `pandoc` es **`pandoc-cli`**, y **`chktex` no es un
paquete** — llega dentro de `texlive-bin`. Ninguno de los dos existe como
`pacman -S pandoc` ni `pacman -S chktex`.

Para *ver* mermaid en Zed no hace falta `mermaid-cli`: eso lo dibuja el editor
por su cuenta. El paquete solo hace falta para el PDF de `space m d`.

### La comprobacion de la fuente decia que faltaba estando instalada

Merece la pena por lo que ensena. `install.sh` corre con `set -euo pipefail`, y
la comprobacion era:

```bash
fc-list : family | grep -qi 'IosevkaTerm Nerd Font'
```

`grep -q` sale en cuanto encuentra la primera coincidencia y cierra la tuberia.
`fc-list`, que suelta 100 KB, sigue escribiendo, recibe **SIGPIPE** y termina en
141. Con `pipefail`, el codigo de la tuberia es ese 141, asi que el `if` se iba
al `else` y el script anunciaba que faltaba una fuente que estaba puesta.

El tamano de la salida no protege, aunque lo parezca: medido, `lsmod | grep -q
'^snd'` tambien devuelve 141 con solo 6 KB, porque lo que importa es si quien
escribe sigue escribiendo cuando el lector se va. La solucion es `grep` **sin**
`-q`, redirigiendo a `/dev/null`: asi lee toda la entrada y no hay senal.

Un `grep -q` que lee un **archivo** o un here-string no tiene este problema,
porque no hay tuberia. Solo los de tuberia.
