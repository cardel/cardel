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
        kb_options = "grp:win_space_toggle",
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

---- Aspecto general ----
-- Sin espacios entre ventanas, al contrario de hyprance.lua. El color del borde
-- activo lo pone hyprance.lua leyendo los colores de pywal, asi que aqui no se
-- vuelve a tocar.
hl.config({
    general = {
        gaps_in     = 0,
        gaps_out    = 0,
        border_size = 2,
        layout = "master",
        allow_tearing = false,
    },
})

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
