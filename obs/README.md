# Compartir la camara entre OBS y Zoom web

El problema al dar clase: Zoom en el navegador coge la webcam y entonces OBS no
puede, o al reves. **Si se puede compartir**, y hay dos caminos distintos que
sirven para cosas distintas.

Antes de nada, en cualquier maquina:

```sh
./comprobar.sh     # no cambia nada, solo dice que hay y que falta
```

| script | que hace | root |
|---|---|---|
| `comprobar.sh` | diagnostico, no toca nada | no |
| `navegadores.sh` | camino 1: Chromium y Firefox piden la camara por PipeWire | no |
| `install.sh` | camino 2: v4l2loopback, la camara virtual de OBS | si |
| `mic-virtual.sh` | microfono falso para mandar el audio de OBS a Zoom | no |

## Lo que pasa de verdad

**El microfono no es el problema.** Se comparte solo. PipeWire abre la tarjeta
ALSA una vez y reparte a todos los clientes; los programas no hablan con el
hardware. Medido con dos grabaciones simultaneas de la misma fuente: las dos
aparecen enganchadas a la fuente al mismo tiempo y las dos escriben audio
valido. No hay nada que configurar.

**`/dev/video0` si es exclusivo.** Un dispositivo V4L2 lo reserva un solo
programa. Medido: con una captura en marcha, la segunda muere en

```
VIDIOC_REQBUFS returned -1 (Device or resource busy)
```

Y `/dev/video1` no es una salida: la webcam expone dos nodos y el segundo es
solo *Metadata Capture*, no da imagen.

**Pero PipeWire tambien multiplexa video**, igual que el audio. Ya expone la
webcam como `Video/Source` sin instalar nada. Medido con dos consumidores
solapados sobre el mismo nodo:

```
83. gst-launch-1.0   75. input_1  < USB2.0 HD UVC WebCam:capture_1  [active]
92. gst-launch-1.0   68. input_1  < USB2.0 HD UVC WebCam:capture_1  [active]
```

los dos `[active]` a la vez, 300 y 120 frames respectivamente, sin un solo
error. Asi que la exclusividad es de `/dev/video0`, no de la camara: **el que
entra por PipeWire no pelea con nadie.**

> El primer intento de esta medicion dio un falso positivo: los dos procesos
> sacaron sus frames pero el primero habia terminado antes de que arrancara el
> segundo, asi que no probaba nada. Si se repite, hay que mirar el grafo
> (`wpctl status`) *durante* el solape y ver los dos `[active]`.

## Camino 1 -- PipeWire: los dos leen la misma camara

Sin root, sin modulos, sin reiniciar. Los dos programas piden la camara por
PipeWire en vez de abrir `/dev/video0`.

```sh
./navegadores.sh          # Chromium y Firefox
./navegadores.sh --off    # deshacer
```

- **Chromium**: activa el flag `enable-webrtc-pipewire-camera`, que es lo que
  escribe `chrome://flags` en `Local State`.
- **Firefox**: pone `media.webrtc.camera.allow-pipewire` en `user.js`, no en
  `prefs.js` -- Firefox reescribe `prefs.js` al cerrarse y se llevaria el cambio
  por delante; `user.js` lo relee en cada arranque y gana. A cambio, el valor
  queda fijado y `about:config` no lo puede cambiar de forma permanente: para
  soltarlo, `--off`.
- **OBS**: como fuente, `Video Capture Device (PipeWire)` (sale marcada BETA),
  no la de V4L2 de toda la vida. Esto no lo hace el script, es un clic.

Los dos navegadores tienen que estar **cerrados** al pasar el script, y despues
hay que reiniciarlos **enteros**: enumeran los dispositivos al arrancar y no
vuelven a mirar.

Zoom ve **la camara tal cual**. Sirve para grabar la clase en OBS mientras Zoom
muestra tu cara normal.

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
cualquier programa y sin flags, y por eso sigue siendo el camino por defecto.

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

Los dos se pueden tener puestos a la vez; no se estorban.

## Si Zoom no ve la camara virtual (camino 2)

Chromium filtra los nodos V4L2 que anuncian salida y captura a la vez, y por eso
`exclusive_caps=1` esta en `etc/modprobe.d/v4l2loopback.conf`. **Esto es lo unico
de este README que no esta medido** — no habia forma sin instalar el modulo.
Cuando este, se comprueba asi:

```sh
v4l2-ctl -d /dev/video10 --info | grep -A4 'Device Caps'
```

Con la camara parada debe decir *Video Output*; en cuanto OBS empieza a emitir
pasa a *Video Capture*, que es cuando el navegador la lista. Si aun asi no sale,
reinicia el navegador entero.

## Orden de arranque (camino 2)

Primero OBS, despues Zoom. Si Zoom ya tenia `/dev/video0` abierto, OBS se queda
sin webcam real. Con el camino 1 el orden da igual, que es su otra ventaja.

## Audio de OBS hacia Zoom (opcional)

Para hablar no hace falta nada. Esto es para que la clase oiga lo que suena
**dentro de OBS** -- un video, musica, la mezcla entera. Zoom web solo sabe leer
de un microfono, asi que se le da uno falso:

```sh
./mic-virtual.sh on      # crea "OBS_Virtual_Mic"
./mic-virtual.sh off
```

En OBS: *Ajustes > Audio > Dispositivo de monitorizacion* = `OBS_Virtual_Mic`, y
en el mezclador poner cada fuente que quieras enviar en **Monitorizar y emitir**.
En Zoom, microfono: **Monitor of OBS_Virtual_Mic**.

Es un `module-null-sink` de PipeWire y no sobrevive al reinicio, a proposito:
mientras esta puesto, Zoom deja de oir el microfono real.

## Llevar esto al PC de mesa

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
