# waybar

La barra de Hyprland. Medido con **waybar 0.15.0**, Hyprland 0.56.2, en
`carlos-portatil`.

Solo se versionan dos archivos, `modules.json` y `style.css`. Lo que queda
fuera, y por que, esta al final.

---

## El sintoma: la barra no mostraba los numeros de escritorio

Y no era "a veces": el centro de la barra estaba **completamente vacio**.
Medido capturando la franja con `grim` y promediando los pixeles — fondo liso,
sin una sola marca de texto, mientras la izquierda (reloj, bandeja, titulo de
ventana) y la derecha (red, audio, bateria) pintaban bien.

La config no tenia nada raro:

```json
"hyprland/workspaces": { "format": "{name}" }
```

y el CSS daba `color: #eceff4` sobre `@color4`. De hecho, **una segunda
instancia de waybar lanzada a mano, con esa misma config y ese mismo CSS,
mostraba el `1` perfectamente**. O sea que ni el modulo ni el estilo estaban
mal: lo que estaba mal era la instancia que arranco con la sesion.

Dos comprobaciones mas sobre esa instancia:

- cambiar de escritorio no alteraba **ni un pixel** del centro de la barra (la
  desviacion tipica de la region capturada salia identica antes y despues), asi
  que el modulo tampoco reaccionaba a los eventos;
- `kill -SIGUSR2` (recargar configuracion) lo arreglaba al instante: aparecian
  `1 2 3 4 6 8`.

Un modulo vivo, vacio y sordo, en una instancia concreta. Nada que se pueda
arreglar editando el formato.

## La hipotesis facil era falsa, y conviene dejarlo escrito

Los sockets de Hyprland no aparecen a la vez:

| socket | para que | creado |
|---|---|---|
| `.socket2.sock` | eventos | 14:04:43.812 |
| `.socket.sock` | comandos (`hyprctl`) | 14:04:44.666 |

y waybar arranco a las **14:04:44**, justo en esos 854 ms de diferencia. Parecia
resuelto: el modulo de escritorios consulta el socket de comandos al iniciarse
(`Loading persistent workspaces from Hyprland workspace rules`) y se habria
quedado sin respuesta.

Se simulo exactamente ese estado — una instancia falsa de Hyprland con un enlace
al socket de eventos real y **sin** socket de comandos — y waybar hizo otra cosa:

```
module hyprland/window:     Disabling module "hyprland/window", Hyprland IPC: Couldn't connect to ...
module hyprland/workspaces: Disabling module "hyprland/workspaces", Hyprland IPC: Couldn't connect to ...
```

Desactiva **los dos** modulos, y lo dice. En el fallo real `hyprland/window`
funcionaba (se veia el titulo de la ventana activa). Asi que no era eso.

**El mecanismo exacto sigue sin estar identificado.** Lo que si esta medido es
que depende del arranque: la instancia de la sesion falla y cualquier instancia
posterior funciona. El candidato que queda en pie es el emparejamiento por
salida: `hyprland/workspaces` filtra los escritorios por el monitor de la barra,
y `hyprland/window` no filtra por nada — lo que explicaria que uno muera y el
otro no. De ahi sale `all-outputs` abajo.

Eso explica tambien el "no me **suele** mostrar": `refresh.sh` (`SUPER+Shift+R`)
hace `pkill waybar; waybar &` en su linea 136, asi que cualquier cambio de tema
reinicia la barra y ese arranque si sale bien.

## El arreglo

```json
"hyprland/workspaces": {
  "format": "{name}",
  "persistent-workspaces": { "*": [1, 2, 3, 4, 5] },
  "all-outputs": true,
  "on-click": "activate",
  "on-scroll-up":   "hyprctl dispatch workspace e+1",
  "on-scroll-down": "hyprctl dispatch workspace e-1"
}
```

- **`persistent-workspaces`** pinta los numeros existan o no esos escritorios.
  Sin esto, waybar solo muestra los que tienen ventanas: recien iniciada la
  sesion eso es **un** boton, lo que ya de por si se lee como "no muestra los
  escritorios". Ademas los botones salen de la configuracion, no de preguntarle
  al compositor, asi que aparecen aunque la consulta inicial falle.

- **La lista explicita `[1,2,3,4,5]` y no el numero `5`.** Con `{"*": 5}`, que
  es la forma corta, la barra pinto **diez** botones (`1..10`) mientras Hyprland
  solo tenia `{1,2,3,4,5,8}`. Medido dos veces, tambien tras reiniciar waybar
  del todo, asi que no eran botones viejos de una recarga. Con la lista sale
  exactamente lo que dice la lista, mas los escritorios que existan de verdad
  por encima: `1 2 3 4 5 8`.

- **`all-outputs`** quita el filtrado por monitor. En un portatil de una sola
  pantalla no cambia nada de lo que se ve, y elimina el unico mecanismo que
  explicaria el fallo de arranque.

- **`on-click` / `on-scroll`** no existian: los botones no se podian pulsar.

Cinco fijos porque es lo que se usa: en el momento de medir habia ventanas en
`1, 2, 3, 4, 5` y `8`.

## La fuente que se pedia no existe

`style.css` declaraba:

```css
font-family: "JetBrains Mono NF";
```

Esa familia **no esta instalada**: `fc-list : family | grep -cx "JetBrains Mono NF"`
devuelve 0. Las que existen son `JetBrainsMono Nerd Font` (y sus variantes
`Mono` y `Propo`), todas sin espacio entre *JetBrains* y *Mono*.

fontconfig no falla nunca: resuelve por parecido y devuelve
`JetBrainsMono Nerd Font`. O sea que la barra se veia bien por casualidad, y
podia cambiar el dia que se instalara otra fuente parecida. Es el mismo fallo
que tenia `foot` con `JetBrainsMonoNF` (ver `foot/README.md`), y la misma regla:
**`fc-match` nunca prueba que una fuente exista — hay que comparar la familia
que devuelve con la que se pidio.**

Ahora se declara `JetBrainsMono Nerd Font`, que es exactamente lo que ya se
estaba pintando: el aspecto no cambia. Y se usa la variante **proporcional** a
proposito, al contrario que en foot y alacritty: una barra no es una rejilla de
celdas, no hay nada que alinear en columnas.

## Que NO se versiona

| ruta | por que |
|---|---|
| `configs/config.json`, `configs/config_laptop.json` | eligen que modulos salen y en que orden, y hay **uno por maquina**; `~/.config/waybar/config` es un enlace al que toque. Mismo caso que el bloque de monitores de `hypr/overrides.conf`: versionarlo obligaria a elegir una de las dos |
| `~/.cache/wal/colors-waybar.css` | lo genera pywal en cada cambio de tema y `style.css` lo importa con `@import`. Es cache, no configuracion |

**Enlazar aqui si es seguro**, al contrario que `foot.ini`. `refresh.sh` toca
waybar, pero solo la reinicia (`pkill waybar; waybar &`); no reescribe ningun
archivo con `>`, y no hay ninguna plantilla de pywal apuntando a estos dos.
Comprobado antes de poner el enlace — es justo la trampa que se documenta en
`foot/README.md`.

## Comprobar un cambio

```sh
./install.sh                 # enlaza y recarga con SIGUSR2
pkill -SIGUSR2 -x waybar     # recargar a mano
```

**`SIGUSR1` no es esa señal**: es la que oculta y muestra la barra, y es lo que
hace `SUPER+B`. Si se manda por error, parece que waybar ha muerto.

waybar no tiene un `--check-config` como foot. Para ver por que un modulo no
sale, hay que lanzarla a mano con registro:

```sh
waybar -l debug -c ~/.config/waybar/configs/config_laptop.json -s ~/.config/waybar/style.css
```

Lanzar una segunda barra encima de la de la sesion confunde. El truco que se uso
aqui: copiar el config a `/tmp`, cambiarle `"position"` a `"bottom"` y lanzarla
asi — se ven las dos a la vez y se pueden comparar.

Dos avisos del registro que son ruido y no tienen que ver con la barra:

- `Failed to open bar ipc connection: Socket path is empty` — es el IPC de
  *sway*, que en Hyprland no aplica.
- `Theme parsing error: gtk.css:70:38: Failed to import ... gtk-widgets-assets.css`
  — del tema GTK generado por pywal, no de `style.css`.
