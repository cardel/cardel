-- Lo propio de esta instalacion. Antes user_configs/overrides.conf.
-- Se carga de ultimo, asi que gana sobre los modulos anteriores.
--
-- Este archivo es igual en todas las maquinas: lo que cambia de un equipo a
-- otro esta en maquina.lua, que no se versiona y devuelve la salida principal y
-- el nombre del touchpad. La version anterior tenia los monitores aqui dentro,
-- y por eso la copia del portatil se desvio de la del repositorio y se quedo
-- sin el arreglo de refresh.sh durante semanas.
local maquina = require("maquina")

-- gromit-mpx: anotar sobre la pantalla ----------------------------------
--
-- Todo pasa por gromit.sh (hypr/gromit.sh, enlazado en ~/.local/bin por
-- hypr/install.sh): arranca gromit si no corre y, si corre, le manda la orden.
-- Antes cada bind llamaba al flatpak con --toggle a pelo, y eso solo funciona
-- con gromit ya corriendo: --toggle es una opcion de CONTROL, no de arranque,
-- y sin instancia muere con 'Unknown Option for Gromit-MPX startup: "--toggle"'
-- (medido en 1.9.0, sale 1). Como nada lo arrancaba, SUPER+C no hacia nada.
--
-- Las teclas F son las que gromit trae de fabrica, F9 y F8 con sus
-- modificadores, para que su documentacion siga siendo cierta. Pero las declara
-- Hyprland, no gromit: las suyas van por un grab de XWayland (--debug:
-- "Grabbing hot key 'F9' from keyboard '3'"), que solo recibe pulsaciones
-- mientras una ventana X tiene el foco, y la superposicion de gromit no lo toma
-- salvo mientras dibuja. Por eso "las F no funcionaban". gromit.sh lo arranca
-- con --key none --undo-key none para que no queden las dos capas: con las dos,
-- F9 sobre una ventana X haria toggle dos veces.
--
-- Lo que cuesta: F8 y F9 dejan de llegar a las aplicaciones. Zed usa F8 y
-- Shift+F8 para saltar entre diagnosticos; LibreOffice, F8 (modo seleccion) y
-- F9 (recalcular). Si algun dia pesa mas eso, quitar solo las cuatro lineas de
-- F8/F9 y quedarse con las de SUPER, que son las mismas ordenes.
--
-- hyprbinds.lua ya usa SUPER+C para la calculadora y Hyprland NO reemplaza el
-- bind anterior: registra los dos y quedan en colision. Hay que soltarlo. La
-- cadena de hl.unbind tiene que coincidir letra por letra con la de hl.bind.
-- La calculadora sigue en la tecla XF86Calculator.
hl.unbind("SUPER + C")

hl.bind("SUPER + C", hl.dsp.exec_cmd("gromit.sh toggle"), { description = "Gromit, dibujar si o no" })
hl.bind("F9", hl.dsp.exec_cmd("gromit.sh toggle"), { description = "Gromit, dibujar si o no" })
hl.bind("SHIFT + F9", hl.dsp.exec_cmd("gromit.sh clear"), { description = "Gromit, borrar todo" })
hl.bind("CTRL + F9", hl.dsp.exec_cmd("gromit.sh visibility"), { description = "Gromit, ocultar o mostrar trazos" })
hl.bind("ALT + F9", hl.dsp.exec_cmd("gromit.sh quit"), { description = "Gromit, cerrar" })
hl.bind("F8", hl.dsp.exec_cmd("gromit.sh undo"), { description = "Gromit, deshacer trazo" })
hl.bind("SHIFT + F8", hl.dsp.exec_cmd("gromit.sh redo"), { description = "Gromit, rehacer trazo" })

-- Las mismas ordenes con SUPER, para un teclado sin fila F comoda o un
-- proyector que se coma las F con su propio atajo.
hl.bind("SUPER + U", hl.dsp.exec_cmd("gromit.sh undo"), { description = "Gromit, deshacer trazo" })
hl.bind("SUPER + SHIFT + U", hl.dsp.exec_cmd("gromit.sh redo"), { description = "Gromit, rehacer trazo" })
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("gromit.sh clear"), { description = "Gromit, borrar todo" })
hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd("gromit.sh visibility"), { description = "Gromit, ocultar o mostrar trazos" })

-- Pausar la inactividad, para una clase larga sin tocar el teclado. Mas fiable
-- que estirar los tiempos de hypridle.conf, porque se ve lo que esta pasando.
hl.bind("SUPER + I", hl.dsp.exec_cmd(
    'pkill hypridle && notify-send -u low -i system-lock-screen "Inactividad en pausa"'
    .. ' || { hypridle & notify-send -u low -i system-lock-screen "Inactividad activa"; }'
), { description = "Pausar o reanudar la inactividad" })

-- Luz calida de noche, que se alterna a mano. 4000 K tira a ambar, "identity"
-- devuelve el color real de la pantalla. Ojo al grabar o al editar video: con
-- esto encendido los colores que ves no son los del archivo.
hl.bind("SUPER + O", hl.dsp.exec_cmd("luz-calida.sh"), { description = "Luz calida de noche" })

-- Modo grabacion: sin efectos y con el ventilador callado, para grabar clase.
hl.bind("SUPER + G", hl.dsp.exec_cmd("modo-grabacion.sh"), { description = "Modo grabacion" })

-- Escritorio especial, el cajon: notas, musica o la terminal de apoyo sin
-- gastar un escritorio entero ni perder lo que estabas mirando.
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("cajon"), { description = "Mostrar u ocultar el cajon" })
hl.bind("SUPER + M", hl.dsp.window.move({ workspace = "special:cajon" }), { description = "Mandar la ventana al cajon" })
hl.workspace_rule({ workspace = "special:cajon", gaps_out = 60, border_size = 3 })

-- Otras aplicaciones
hl.bind("SUPER + X", hl.dsp.exec_cmd("obs"), { description = "OBS" })
hl.bind("SUPER + Z", hl.dsp.exec_cmd("xournalpp"), { description = "Xournal++" })

---- Entrada ----
-- Detectado por initial_boot.sh en su dia. Sustituye lo de hyprdevices.lua.
hl.config({
    input = {
        kb_layout  = "latam, us",
        kb_variant = "",
        kb_model   = "",
        -- grp:win_space_toggle  Super+Espacio cambia de distribucion.
        -- caps:super            Bloq Mayus pasa a ser un Super completo.
        --
        -- Lo segundo es un apano por una averia del teclado, no un gusto. El
        -- Win de este TUF dejo de mandar su codigo el 27 de octubre de 2026 a
        -- las 23:35 y manda en su lugar el evento WMI 0x4f, que asus_wmi no
        -- sabe traducir: cero eventos 0x4f en los seis arranques anteriores,
        -- decenas en todos los posteriores. Sin tecla Super no hay lanzador ni
        -- ninguno de los cien atajos.
        --
        -- /usr/share/X11/xkb/symbols/capslock dice que caps:super hace
        -- key <CAPS> { [ Super_L ] }, o sea el mismo keysym que perdio el
        -- teclado. Asi revive todo, incluido el bind de SUPER_L del lanzador.
        -- Si algun dia se desbloquea el Win, esta linea se puede quitar.
        kb_options = "grp:win_space_toggle,caps:super",
        kb_rules   = "",

        repeat_rate  = 50,
        repeat_delay = 300,

        follow_mouse = 1,

        sensitivity = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

-- El aspecto (espacios, bordes, sombra, blur, animaciones) esta todo en
-- hyprance.lua, que se carga antes. Aqui habia un bloque general que lo unico
-- que hacia era volver los espacios a cero, y con cero espacio el redondeo de
-- las esquinas no se ve. Si alguna vez quieres las ventanas pegadas otra vez,
-- es gaps_in y gaps_out en hyprance.lua.

---- Touchpad ----
-- Antes user_configs/touchpad.conf, que lo genero initial_boot.sh.
--
-- El estado era la variable $TOUCHPAD_ENABLED y touchpad.sh la movia con
-- `hyprctl keyword "$TOUCHPAD_ENABLED" true -r`. Las variables de
-- configuracion murieron con el formato .conf, y las dos salidas que parecian
-- obvias tampoco sirven en 0.57, medidas las dos:
--
--   hyprctl keyword 'device[nombre]:enabled' false   -> "unknown request"
--   hl.device({ ..., enabled = false }) en caliente   -> no se refleja
--
-- Asi que el estado vive en un archivo y esto lo lee al cargar. touchpad.sh
-- escribe ahi y pide `hyprctl reload config-only`, que es lo unico que aplica.
-- El archivo esta en XDG_RUNTIME_DIR, que se borra al cerrar sesion, asi que
-- cada sesion empieza con el touchpad activo.
local function touchpad_activo()
    local ruta = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/touchpad.status"
    local f = io.open(ruta, "r")
    if not f then return true end
    local estado = f:read("l")
    f:close()
    return estado ~= "false"
end

if maquina.touchpad then
    hl.device({
        name        = maquina.touchpad,
        enabled     = touchpad_activo(),
        sensitivity = 0.0,
    })
end

---- Tableta grafica ----
-- La M708 es la misma en los dos equipos; lo que cambia es a que salida se
-- mapea, y eso lo dice maquina.lua.
hl.device({
    name   = "ugtablet-m708-pen",
    output = maquina.salida,
})

---- Reglas de ventana ----

-- Lo que tiene mas sentido flotando y centrado que partiendo el mosaico: los
-- dialogos de ajustes, el control de volumen y el visor de video. "floating" es
-- el app-id que usan los binds de la distribucion cuando quieren una ventana
-- suelta, como el pulsemixer de SUPER+SHIFT+V.
hl.window_rule({
    name  = "sueltas-y-centradas",
    match = { class = "^(pavucontrol|nm-connection-editor|lxqt-policykit-agent|floating|mpv|org.pulseaudio.pavucontrol)$" },
    float  = true,
    center = true,
    size   = "60% 60%",
})

-- Los dialogos de abrir y guardar archivo, que salen de cualquier aplicacion.
hl.window_rule({
    name  = "dialogos-de-archivo",
    match = { title = "^(Open File|Save File|Abrir|Guardar|Seleccionar archivo).*$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "gromit-crisp",
    match = { class = "^(gromit-mpx|Gromit-mpx)$" },

    no_blur = true,
    no_dim  = true,
    opacity = "1.0 override 1.0 override 1.0 override",

    -- Comportamiento de superposicion
    float = true,
    pin   = true,

    -- Una sola pantalla. gromit no tiene ninguna opcion de monitor: se dibuja
    -- sobre la pantalla X entera, que en XWayland es la caja que engloba todas
    -- las salidas. Y sin regla, donde cae depende del monitor con foco al
    -- arrancarlo.
    --
    -- monitor es imprescindible: sin el, move de una ventana flotante se
    -- interpreta relativo al monitor donde Hyprland la deje caer.
    monitor = maquina.salida,
    move    = "0 0",
    size    = "1920 1080",
})

---- Gestos del touchpad ----
-- No habia ninguno configurado. Tres dedos en horizontal cambia de escritorio.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

---- Comodidades de 0.57 ----
hl.config({
    cursor = {
        -- Con el espejo a HDMI para el proyector y la pantalla USB-C, el
        -- puntero se perdia al cambiar de salida.
        warp_on_monitor_change = true,
    },

    misc = {
        -- Que una aplicacion que pide el foco lo reciba, en vez de quedarse
        -- parpadeando en waybar.
        focus_on_activate = true,
    },

    animations = {
        -- Del ultimo escritorio al primero sin frenar en el borde.
        workspace_wraparound = true,
    },

    binds = {
        -- Oprimir dos veces el numero del escritorio actual devuelve al
        -- anterior.
        workspace_back_and_forth = true,
    },
})
