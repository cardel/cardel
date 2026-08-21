# Compartir la camara y el microfono entre OBS, los navegadores y Zoom

El problema al dar clase: Zoom en el navegador coge la webcam y entonces OBS no
puede, o al reves. **Si se pueden compartir**, y con mas de dos programas a la
vez. Hay dos caminos distintos que sirven para cosas distintas.

Antes de nada, en cualquier maquina:

```sh
./comprobar.sh     # no cambia nada, solo dice que hay y que falta
```

| script | que hace | root |
|---|---|---|
| `comprobar.sh` | diagnostico, no toca nada | no |
| `navegadores.sh` | camino 1: los navegadores piden la camara por PipeWire | no |
| `install.sh` | camino 2: v4l2loopback, la camara virtual de OBS | si |
| `mic-virtual.sh` | microfono falso para mandar el audio de OBS a Zoom | no |

## Lo que pasa de verdad

**`/dev/video0` es exclusivo.** Un dispositivo V4L2 lo reserva un solo
programa. Medido en el PC de mesa, dos capturas solapadas sobre el mismo nodo:
la primera va a 30 fps y la segunda muere en

```
VIDIOC_REQBUFS returned -1 (Device or resource busy)
```

Y `/dev/video1` no es una salida: la webcam expone dos nodos y el segundo es
solo *Metadata Capture*, no da imagen.

**Pero PipeWire multiplexa el video**, igual que el audio. Ya expone la webcam
como `Video/Source` sin instalar nada. Medido con **tres** consumidores
solapados (un `gst-launch` haciendo de OBS y dos Chromium con perfiles
distintos, los tres pidiendo la camara a la vez):

```
 90. gst-launch-1.0    93. input_1  < C922 Pro Stream Webcam:capture_1  [active]
 98. chromium         102. input_1  < C922 Pro Stream Webcam:capture_1  [active]
120. chromium         121. input_1  < C922 Pro Stream Webcam:capture_1  [active]
```

los tres `[active]` a la vez y cero errores. Y el dato que explica el mecanismo,
tomado durante ese mismo solape:

```
$ fuser -v /dev/video0
                     USER        PID ACCESS COMMAND
/dev/video0:         cardel     1475 F.... pipewire
```

**un solo proceso abre el dispositivo**, y es PipeWire. Los tres clientes hablan
con el, no con el kernel. Asi que la exclusividad es de `/dev/video0`, no de la
camara: el que entra por PipeWire no pelea con nadie, y no hay un limite de dos.

> El primer intento de esta medicion (en el portatil) dio un falso positivo: los
> dos procesos sacaron sus frames pero el primero habia terminado antes de que
> arrancara el segundo, asi que no probaba nada. Si se repite, hay que mirar el
> grafo (`wpctl status`) *durante* el solape y ver los `[active]` juntos.

## Camino 1 -- PipeWire: todos leen la misma camara

Sin root, sin modulos, sin reiniciar. Los programas piden la camara por PipeWire
en vez de abrir `/dev/video0`.

```sh
./navegadores.sh          # todos los navegadores que encuentre
./navegadores.sh --off    # deshacer
```

- **Chromium, Vivaldi, Chrome, Brave**: activa el flag
  `enable-webrtc-pipewire-camera`, que es lo que escribe `chrome://flags` (o
  `vivaldi://flags`) en `Local State`. Todos los derivados de Chromium usan el
  mismo flag y el mismo formato, asi que van por la misma funcion; el script
  solo toca los que tengan perfil creado.
- **Firefox**: pone `media.webrtc.camera.allow-pipewire` en `user.js`, no en
  `prefs.js` -- Firefox reescribe `prefs.js` al cerrarse y se llevaria el cambio
  por delante; `user.js` lo relee en cada arranque y gana. A cambio, el valor
  queda fijado y `about:config` no lo puede cambiar de forma permanente: para
  soltarlo, `--off`.
- **OBS**: como fuente, `Video Capture Device (PipeWire)` (sale marcada BETA),
  no la de V4L2 de toda la vida. Esto no lo hace el script, es un clic.

Los derivados de Chromium tienen que estar **cerrados** al pasar el script:
reescriben `Local State` al salir y se llevarian el cambio por delante. Firefox
no hace falta cerrarlo -- lo que reescribe al salir es `prefs.js`, y `user.js` no
lo toca nunca, que es justo por lo que se usa ese archivo.

En los dos casos hay que reiniciar el navegador **entero** despues: enumeran los
dispositivos al arrancar y no vuelven a mirar.

Zoom ve **la camara tal cual**. Sirve para grabar la clase en OBS mientras Zoom
muestra tu cara normal.

### Dos trampas del guardia de "cierralo primero"

**El nombre del proceso no es el del comando.** Vivaldi corre como
`vivaldi-bin`; un `pgrep -x vivaldi` no encuentra nada aunque este abierto en
pantalla. Con el nombre mal, el guardia no salta, el script escribe el flag y
Vivaldi te lo borra al cerrarse -- y no hay ningun error que lo delate. Por eso
`NAVEGADORES` lleva el nombre exacto del proceso en su propia columna.

**Instalado no es lo mismo que estrenado.** El perfil no existe hasta el primer
arranque: en el PC de mesa hay `firefox` en `/usr/bin` y ningun `~/.mozilla`.
El script lo dice con esas palabras en vez de callarse, porque "se omite" a
secas se lee como "ya estaba bien".

Ademas, antes de escribir nada se comprueba que el binario instalado siga
conociendo el flag (`grep -qa` sobre el ejecutable, decimas de segundo aun con
300 MB). El dia que Chromium lo quite o lo renombre, el script avisa en vez de
dejar una entrada muerta en `Local State`. Comprobado presente en Chromium 151 y
Vivaldi 8.1.

### Firefox puede tener mas perfiles de los que crees

El script recorre **todos** los perfiles de `profiles.ini`, no solo el activo, y
no es por prudencia. Firefox se crea un perfil nuevo por instalacion cuando el
que encuentra no le cuadra, y el bloque `[InstallXXXX]` lleva su propio
`Default` que **manda sobre** el `Default=1` del perfil:

```
[Install4F96D1932A9F858E]
Default=p96pwk1i.default-release-1
Locked=1
```

Visto aqui: un perfil creado a mano con `firefox -CreateProfile` quedo ignorado
y Firefox arranco con otro recien hecho, sin el pref. El perfil que de verdad se
esta usando es el que tiene `.parentlock`.

## Camino 2 -- v4l2loopback: Zoom ve la escena de OBS

```sh
./install.sh      # pide sudo
```

Instala `v4l2loopback-dkms`, copia los dos archivos de `etc/` a `/etc` y carga
el modulo. Crea `/dev/video10`, una camara falsa que rellena OBS:

```
webcam /dev/video0 ──> OBS ──> /dev/video10 "OBS Virtual Camera" ──> Zoom web
```

En OBS: **Herramientas > Iniciar camara virtual**. En Zoom, camara: **OBS
Virtual Camera**.

Aqui Zoom ve **lo que tengas montado en OBS**: las diapositivas, la camara en
una esquina, lo que sea. Es lo que quieres para dar clase. Funciona con
cualquier programa y sin flags.

Este instalador **copia en vez de enlazar**, al reves que el resto del repo: son
archivos de root que lee el kernel al arrancar, y un symlink hacia un repo
dentro de `$HOME` dejaria los parametros de carga de un modulo del kernel al
alcance de cualquier cosa que corra como el usuario. Cuando cambies algo en
`etc/`, vuelve a pasar el instalador.

## Cual usar

| Quieres que Zoom muestre... | Camino |
|---|---|
| tus diapositivas, la escena montada | 2 (v4l2loopback) |
| tu cara, y OBS grabando aparte | 1 (PipeWire) |
| varios programas viendo la camara a la vez | 1 (PipeWire) |

Los dos se pueden tener puestos a la vez; no se estorban.

## Si Zoom no ve la camara virtual (camino 2)

Chromium filtra los nodos V4L2 que anuncian salida y captura a la vez, y por eso
`exclusive_caps=1` esta en `etc/modprobe.d/v4l2loopback.conf`. **Esto es lo unico
de este README que no esta medido** — no habia forma sin instalar el modulo, y
en el PC de mesa `v4l2loopback-dkms` sigue sin estar. Cuando este, se comprueba
asi:

```sh
v4l2-ctl -d /dev/video10 --info | grep -A4 'Device Caps'
```

Con la camara parada debe decir *Video Output*; en cuanto OBS empieza a emitir
pasa a *Video Capture*, que es cuando el navegador la lista. Si aun asi no sale,
reinicia el navegador entero.

## Orden de arranque (camino 2)

Primero OBS, despues Zoom. Si Zoom ya tenia `/dev/video0` abierto, OBS se queda
sin webcam real. Con el camino 1 el orden da igual, que es su otra ventaja.

## Microfono

**Compartirlo es gratis y no hay nada que configurar.** PipeWire abre la tarjeta
ALSA una vez y reparte a todos los clientes; los programas no hablan con el
hardware. Medido sobre el Blue Yeti con dos grabaciones simultaneas:

```
89. pw-record   91. input_FL  < Blue Microphones:capture_FL  [active]
97. pw-record   98. input_FL  < Blue Microphones:capture_FL  [active]
```

las dos `[active]` a la vez y los dos WAV validos. Con OBS y dos navegadores
encima salen cinco streams de audio en el grafo sin un solo error.

**Lo que si falla, y en silencio, es cual coge cada programa.** En la misma
medicion, los dos navegadores se llevaron el microfono de la **webcam** en vez
del Yeti:

```
104. Chromium input  106. input_FL  < C922 Pro Stream Webcam:capture_FL  [active]
122. Chromium input  124. input_FL  < C922 Pro Stream Webcam:capture_FL  [active]
```

No es un fallo de nadie: el que no elige un dispositivo a mano se lleva el que
este por defecto, y el micro integrado de la webcam gana por prioridad de
WirePlumber. Se ve y se arregla asi:

```sh
pactl get-default-source                    # cual es ahora
pactl list sources short | grep -v monitor  # cuales hay
pactl set-default-source alsa_input.usb-Generic_Blue_Microphones_...
```

WirePlumber lo recuerda entre reinicios (lo guarda en
`~/.local/state/wireplumber/default-nodes`), asi que se hace una vez.
`comprobar.sh` lista los microfonos, marca el activo con `*` y avisa en amarillo
si el elegido es el de una webcam habiendo otro.

Ojo: eso solo arregla a quien pide "el de por defecto". En OBS el dispositivo se
elige por nombre en cada fuente de audio, y los navegadores recuerdan su eleccion
**por sitio** — si Zoom ya tenia guardado el micro de la webcam, hay que
cambiarlo en los permisos de esa pagina.

## Audio de OBS hacia Zoom (opcional)

Para hablar no hace falta nada, por lo de arriba. Esto es para que la clase oiga
lo que suena **dentro de OBS** -- un video, musica, la mezcla entera. Zoom web
solo sabe leer de un microfono, asi que se le da uno falso:

```sh
./mic-virtual.sh on      # crea "OBS_Virtual_Mic"
./mic-virtual.sh off
```

En OBS: *Ajustes > Audio > Dispositivo de monitorizacion* = `OBS_Virtual_Mic`, y
en el mezclador poner cada fuente que quieras enviar en **Monitorizar y emitir**.
En Zoom, microfono: **Monitor of OBS_Virtual_Mic**.

Es un `module-null-sink` de PipeWire y no sobrevive al reinicio, a proposito:
mientras esta puesto, Zoom deja de oir el microfono real.

## Llevar esto a otra maquina

```sh
git pull
./comprobar.sh       # que hay y que falta en esa maquina
./navegadores.sh     # camino 1, sin root
./install.sh         # camino 2, pide sudo
```

Y en OBS, elegir la fuente `Video Capture Device (PipeWire)` para el camino 1, o
*Herramientas > Iniciar camara virtual* para el camino 2.

Nada de esto lleva rutas ni numeros fijados a mano: `/dev/videoN` y los ids de
los nodos de PipeWire cambian entre maquinas, y `comprobar.sh` los descubre.

## Dependencias

- `obs-studio`, `v4l-utils` (para `v4l2-ctl`, con lo que se comprueba todo esto).
- Camino 2: `v4l2loopback-dkms` y `linux-headers` (dkms recompila el modulo tras
  cada actualizacion de kernel).
- Camino 1: nada extra; `xdg-desktop-portal` y el plugin de PipeWire de OBS ya
  vienen puestos.
- Para repetir las mediciones de aqui: `gst-plugin-pipewire` (el elemento
  `pipewiresrc`) y `pw-record`, que vienen con `pipewire`.
