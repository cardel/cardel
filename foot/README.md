# foot

Terminal de Wayland para programar. Medido con **foot 1.27.0**, Hyprland
0.56.2, tmux 3.7c, JetBrainsMono Nerd Font.

`foot.ini` es la fuente de verdad. Todo lo que sigue esta comprobado en esta
maquina, no supuesto; donde no lo esta, lo dice.

---

## Lo primero: este archivo no se enlaza donde parece

**`~/.config/foot/foot.ini` no es un archivo que se edite: se genera.**
`~/.local/bin/refresh.sh` lo arma concatenando cuatro y redirigiendo:

```sh
cat defaults.ini overrides.ini ~/.cache/wal/foot.base.ini \
    overrides_colors.ini > foot.ini
```

Y `>` **sigue los symlinks**. Medido:

```
$ echo "contenido del repo" > repo-file; ln -sfn repo-file link
$ echo "generado por el script" > link
$ test -L link && echo "sigue siendo symlink"   # sigue siendo symlink
$ cat repo-file                                  # generado por el script
```

O sea: enlazar `foot.ini` al repositorio haria que el primer refresco de tema
escribiera la salida de pywal **dentro del repositorio**, sin romper el enlace
y sin un solo mensaje de error. Es la misma trampa que el `prefs.js` de
Firefox, y lo contrario de lo que hace Zed, que sí es seguro enlazar.

El destino correcto es **`overrides_colors.ini`**: es el ultimo de la
concatenacion, y en foot **gana la ultima aparicion de cada clave**. Medido
con un archivo que declara `term` dos veces:

```
$ printf '[main]\nterm=PRIMERO\nterm=ULTIMO\n' > orden.ini
$ foot -c orden.ini sh -c 'echo $TERM'
ULTIMO
```

Y comprobado de punta a punta sobre la concatenacion de verdad, preguntandole
al terminal por su fondo con OSC 11:

```
$ cat defaults.ini overrides.ini ~/.cache/wal/foot.base.ini foot.ini > generado.ini
$ foot -c generado.ini <script que emite \033]11;?\033\\ >
]11;rgb:0f0f/1111/1515
```

`0f1115`, el del repositorio — no el `0b090a` que pywal habia puesto tres
archivos antes. `install.sh` ademas rehace `foot.ini` al terminar, porque foot
solo lee ese y si no la configuracion no llegaria hasta el proximo refresco.

En una maquina sin este montaje (sin `defaults.ini`) el instalador detecta la
diferencia y enlaza `foot.ini` directamente. Ojo entonces con
`../install.sh`: su tabla `DESTINOS` apunta a `overrides_colors.ini` y en esa
otra maquina el estado saldria como `ausente` aunque este bien instalado.

---

## Lo que estaba mal antes

**La fuente no era la que parecia.** `defaults.ini` pedia
`font=JetBrainsMonoNF:size=12`, y esa familia **no existe**: fontconfig la
resolvia por parecido.

```
$ fc-match "JetBrainsMonoNF"
JetBrainsMonoNerdFont-Regular.ttf: "JetBrainsMono Nerd Font" "Regular"
```

Fijarse en el nombre que devuelve: **`JetBrainsMono Nerd Font`**, sin el
`Mono` final. Es la variante de ancho proporcional, donde los glifos Nerd
ocupan dos celdas. La que quiere un terminal es `JetBrainsMono Nerd Font
Mono`, que es ademas la que ya usan `alacritty.toml` y `tmux.conf`.
`fc-match` siempre devuelve algo, asi que no sirve de prueba por si solo: hay
que mirar si el nombre que sale es el que se pidio.

**`[colors]` esta obsoleta.** En foot 1.27 la seccion se llama
`[colors-dark]` (y `[colors-light]` para el tema claro). La vieja sigue
funcionando pero avisa por cada clave:

```
$ foot --check-config -c t-colors.ini
warn: [colors]: deprecated; use [colors-dark] instead
```

Y no era ruido invisible: el aviso **se imprime dentro de la ventana** cada vez
que se abre un terminal. Salia de la plantilla de pywal, que escribia el nombre
viejo. **Cambiado fuera de este repositorio** (respaldo `.bak.*` al lado):

| archivo | cambio |
|---|---|
| `~/.config/wal/templates/foot.base.ini` | `[colors]` → `[colors-dark]` |
| `~/.cache/wal/foot.base.ini` | lo mismo, para que surta efecto sin esperar a `wal` |

La plantilla es la que importa: `refresh.sh` regenera la copia de la cache a
partir de ella. Queda anotado aqui porque es lo unico de esta configuracion que
vive fuera del repositorio y no se veria en `git status`.

### foot no hace ligaduras

Ni `!=` ni `=>` ni `->` se unen, y no hay opcion que lo cambie: foot no
implementa ligaduras. `grapheme-shaping=yes` es para grupos de grafemas
(emoji con modificadores, banderas), no para esto. Alacritty tampoco las hace,
asi que no se pierde nada respecto a antes; el unico terminal de la familia que
sí es kitty.

**tmux no conocia foot.** `tmux 3.7c` trae de fabrica filas para `xterm*`,
`screen*` y `rxvt*` y **nada mas**:

```
$ tmux -L probe -f /dev/null new-session -d "sleep 20"
$ tmux -L probe show-options -g terminal-features
terminal-features[0] xterm*:clipboard:ccolour:cstyle:focus:title
terminal-features[1] screen*:title
terminal-features[2] rxvt*:ignorefkeys
```

Y el terminfo de foot no declara `RGB` ni `Tc` (igual que el de alacritty, por
eso el repositorio ya llevaba el override para ese). Sin fila propia, tmux
dentro de foot perdia truecolor, OSC 52 y sixel — en silencio, porque nada
falla: los colores simplemente se cuantizan a 256. `tmux/tmux.conf` ya lleva
la fila.

---

## El tema

Es **la misma paleta que `alacritty/alacritty.toml`**: Nord (aurora y frost)
sobre un fondo casi negro `#0f1115` en lugar del `#2e3440` lavado del Nord
original. La razon de copiarla en vez de traer un tema nuevo es que asi los
tres — foot, alacritty y el statusline de tmux — pintan el mismo rojo y el
mismo verde, y ninguno desmiente al otro.

`[colors-light]` es el mismo Nord por el otro lado (Snow Storm de fondo, los
acentos oscurecidos para que contrasten sobre blanco). **`Ctrl+Shift+t`
alterna**, que es lo que hace falta al proyectar en clase: sobre un proyector
el fondo casi negro se ve gris sucio y el texto tenue desaparece.

### Cambiarlo entero

foot trae **80 temas** en `/usr/share/foot/themes/`. Se ponen con una linea al
final de `foot.ini`, que por ser la ultima gana sobre lo de arriba:

```ini
include=/usr/share/foot/themes/catppuccin-mocha
```

Los que valen la pena para codigo, de los instalados:

| tema | como es |
|---|---|
| `catppuccin-mocha` | el mas popular ahora mismo; malva oscuro, contraste suave |
| `tokyonight-night` | azul muy oscuro, acentos frios y saturados |
| `gruvbox-dark` | calido, retro, el de menos fatiga en sesiones largas |
| `nord` | el Nord original, con su fondo `#2e3440` gris azulado |
| `rose-pine-moon` | malva templado, mas bajo en contraste |
| `jetbrains-darcula` | el de IntelliJ, si vienes de ahi |
| `selenized-black` | disenado por contraste medido, no por gusto |

Verlos todos antes de elegir: [trinitronx/preview-foot-themes](https://github.com/trinitronx/preview-foot-themes).
Fuera de los que trae: [tinted-theming/tinted-foot](https://github.com/tinted-theming/tinted-foot)
(los ~250 de base16), [dracula/foot](https://github.com/dracula/foot) y
[perttunurmi/foot-terminal-themes](https://github.com/perttunurmi/foot-terminal-themes).

---

## Atajos

Los de fabrica que no se tocan: `Ctrl+Shift+c`/`v` copiar y pegar,
`Ctrl+Shift+r` buscar en el historial, `Ctrl+Shift+n` terminal nuevo,
`Ctrl+Shift+o` abrir URL, `Ctrl+Shift+u` entrada unicode, `Ctrl` con `+`/`-`/`0`
para el tamano de letra.

Los que anade esta configuracion:

| atajo | que hace |
|---|---|
| `Ctrl+Shift+k` / `j` | media pagina arriba / abajo, como `C-u`/`C-d` de vim |
| `Ctrl+Shift+Home` / `End` | al principio / al final del historial |
| `Ctrl+Shift+t` | alterna tema claro / oscuro |
| `Ctrl+Shift+f` | etiqueta cada `ruta:linea` visible y copia la que elijas |
| `Ctrl+Shift+g` | lo mismo con los hashes de git |
| `Ctrl+Shift+y` | copia una URL en vez de abrirla |
| `Ctrl+Shift+p` | abre todo el historial de la ventana en nvim |

Ninguno pisa a tmux, cuyo prefijo es `C-b`. `Ctrl+Shift+u` no se usa para
media pagina precisamente porque ya es `unicode-input`.

`Ctrl+Shift+f` y `Ctrl+Shift+g` salen de las secciones `[regex:ubicacion]` y
`[regex:hash]`. No lanzan nada, solo copian, asi que no dependen de ningun
programa externo: es la forma rapida de sacar el `src/main.rs:42:8` de un
error de compilacion para pegarlo en un issue.

---

## Lo que foot puede y alacritty no: sixel

`CLAUDE.md` explica que en `yazi/` los PDF se previsualizan como **texto** y no
como imagen, y que la causa no es la configuracion sino que **alacritty 0.17 no
implementa ningun protocolo grafico**.

foot sí:

```
$ man 5 foot.ini | grep -A1 '^     sixel'
     sixel
         Boolean. When enabled, foot will process sixel images. Default: yes
```

Y tmux 3.7c esta compilado con soporte sixel (`screen_write_sixelimage`,
`tty_cmd_sixelimage` en el binario), que es lo que hace util la fila `sixel`
que se le acaba de anadir para foot.

Es decir: **bajo foot se podrian ver imagenes de verdad en yazi**, y quiza
tambien paginas de PDF renderizadas. No se ha tocado `yazi/` en este cambio —
la configuracion actual sigue usando `chafa` por el plugin `piper`, que
funciona igual en los dos terminales. Queda como lo siguiente que probar.

Relacionado, y por eso importante: **`line-height` y `letter-spacing` se dejan
sin poner a proposito**. `yazi/yazi.toml` le pasa a chafa
`--font-ratio 600/1320`, que es la forma de la celda calculada de las metricas
de esta fuente. Cualquiera de las dos opciones cambia esa relacion y las vistas
previas salen estiradas.

---

## Dos cosas que no estan activadas, y por que

**La zsh no emite OSC 133 ni OSC 7.** Comprobado sobre
`config/oh-my-zsh/.zshrc`: no hay nada. Consecuencia: `prompt-prev` /
`prompt-next` (saltar entre ordenes) no tendrian a que saltar, y
`Ctrl+Shift+n` abre el terminal nuevo en `$HOME` en vez de en el directorio
actual. Por eso **esos atajos no se declaran**: un atajo que no hace nada es
peor que no tenerlo.

Se arreglan pegando esto en `.zshrc` — y hay que hacerlo en la copia viva,
porque `.zshrc` en esta maquina no es un enlace:

```zsh
# Marcas de prompt (OSC 133) y directorio actual (OSC 7) para foot.
_foot_osc7()   { printf '\033]7;file://%s%s\033\\' "${HOST}" "${PWD}"; }
_foot_precmd() { printf '\033]133;A\033\\'; _foot_osc7; }
_foot_preexec(){ printf '\033]133;C\033\\'; }
autoload -Uz add-zsh-hook
add-zsh-hook precmd  _foot_precmd
add-zsh-hook preexec _foot_preexec
```

Con eso puestas, anadir a `[key-bindings]`:
`prompt-prev=Control+Shift+z` y `prompt-next=Control+Shift+x`.

**El desenfoque no esta comprobado.** `alpha=0.95` mas `blur=yes` en
`[colors-dark]` dan transparencia con desenfoque, pero `blur` necesita que el
compositor implemente `ext-background-effect-v1`. El binario de foot lo
soporta (`+blur` en `foot --version`) y el de Hyprland 0.56.2 menciona la
cadena dos veces, que es indicio pero **no** prueba. Se deja `alpha=1.0`.

---

## El terminal por defecto sigue siendo alacritty

Dos sitios lo declaran, y ninguno dice foot:

| archivo | linea |
|---|---|
| `~/.config/hypr/user_configs/default_apps.conf` | `env = TERMINAL,alacritty` |
| `config/oh-my-zsh/.zshrc` | `export TERMINAL=alacritty` |

`SUPER+Return` abre lo que diga `$TERMINAL`, o sea alacritty. Cambiar las dos
lineas a `foot` es todo lo que hace falta; se deja como esta porque es una
decision, no un defecto. (`hyprbinds.conf` sí llama a `foot` a pelo en
`SUPER+Y`, la busqueda de YouTube.)

---

## Comprobar un cambio

foot trae validador, y devuelve **230** cuando una opcion no existe:

```
$ foot --check-config -c foot.ini ; echo $?
0
$ printf '[colors]\ninventado=1\n' > malo.ini
$ foot --check-config -c malo.ini ; echo $?
err: [colors].inventado: 1: not valid option
230
```

`install.sh` lo ejecuta antes de enlazar nada, porque una configuracion rota
**no da error al arrancar**: foot se queda con los valores de fabrica y el
sintoma es "el tema no se aplico".

Cuidado al medir el codigo de salida: `foot --check-config ... | sed ...; echo $?`
devuelve el de `sed`, no el de foot, y siempre parece 0.
