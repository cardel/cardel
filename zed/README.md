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

### Guardar es el unico disparador de compilacion que existe

Esto explica por que antes no compilaba nada. texlab expone compilar y saltar al
PDF como **comandos LSP** (`workspace/executeCommand`), y **Zed no tiene forma de
invocar un comando LSP arbitrario**: no hay accion, ni orden de la paleta, ni
nada en la extension (su `extension.toml` declara `capabilities = []` y ningun
`slash_command`).

O sea: la unica via es que texlab compile solo, al guardar. Con
`build.onSave: false` — que es lo que habia — **no hay ninguna manera de compilar
desde el editor**. Por eso ahora esta en `true`, junto con
`forwardSearchAfter: true`: guardar compila y el PDF salta a la linea del cursor.

`autosave` esta explicitamente en `"off"` por lo mismo: con autoguardado, cada
pausa al teclear lanzaria una compilacion.

Las tareas de `space l ...` son la salida de emergencia — recompilar entero, ver
el log, limpiar auxiliares — no el camino normal.

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

Para un documento en ingles no hay que tocar la configuracion; basta una linea
magica en el `.tex`:

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
| `space l v` / `space l c` / `space l n` | ver PDF / limpiar / contar palabras |
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

## `agent_font_size` no existe

Estaba en el archivo y no hacia nada. Zed solo conoce `agent_ui_font_size` y
`agent_buffer_font_size` — comprobado contra su `default.json` y contra el
binario, cero apariciones de la otra.

## La fuente falla en silencio

`ui_font_family` y `buffer_font_family` piden **IosevkaTerm Nerd Font**, que no
esta instalada: `fc-list` no devuelve ni una familia Iosevka, y `fc-match`
resuelve a Noto Sans. Zed lleva todo este tiempo pintando con otra fuente sin
decirlo. `install.sh` lo comprueba.

## Lo que hay que instalar

```bash
sudo pacman -S --needed texlive-binextra zathura zathura-pdf-mupdf \
                        ttf-iosevkaterm-nerd lazygit
```

- `texlive-binextra` → `latexmk` (compilar), `texcount` (contar palabras).
  Tambien trae `latexindent`, por si algun dia se quiere formatear.
- `zathura` + `zathura-pdf-mupdf` → visor con synctex en las dos direcciones.
- `ttf-iosevkaterm-nerd` → la fuente que la configuracion ya pedia.
- `lazygit` → la tarea de `space g g`.
