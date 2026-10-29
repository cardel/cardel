-- Atajos de teclado. Antes hyprbinds.conf.
--
-- Equivalencias de los prefijos del formato viejo:
--   bind   -> hl.bind(...)
--   bindr  -> { release = true }
--   binde  -> { repeating = true }
--   bindl  -> { locked = true }
--   bindel -> { locked = true, repeating = true }
--   bindm  -> { mouse = true }
--
-- Cada bind lleva description, que es nuevo: `hyprctl binds` la muestra, y eso
-- es lo que deberia leer keybinds.sh cuando se reescriba.

local terminal     = "alacritty"
local file_manager = "yazi"
local browser      = "vivaldi"
local menu         = "fuzzel"
local calculator   = "calc.fish"

---------------------
---- APLICACIONES ----
---------------------

hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal), { description = "Terminal" })
hl.bind("SUPER + R", hl.dsp.exec_cmd(terminal .. " -e " .. file_manager), { description = "Gestor de archivos" })
hl.bind("SUPER + W", hl.dsp.exec_cmd(browser), { description = "Navegador" })
hl.bind("SUPER + A", hl.dsp.exec_cmd("actions.sh default"), { description = "Menu de acciones" })
hl.bind("SUPER + N", hl.dsp.exec_cmd("networkmanager_dmenu >/dev/null 2>&1"), { description = "Gestor de red" })
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd(terminal .. " --app-id floating -e pulsemixer || " .. terminal .. " -e pulsemixer"), { description = "Control de volumen" })

-- El Win solo. Va por keysym, no por modificador: con un keysym el orden en
-- que se oprimen las teclas cuenta y deja de comportarse como modificador.
hl.bind("SUPER_L", hl.dsp.exec_cmd("pkill " .. menu .. " || " .. menu), { release = true, description = "Menu" })

-- Y el mismo lanzador en una combinacion, para no depender de una sola tecla.
-- El Win de este teclado ya se averio una vez (manda el evento WMI 0x4f en vez
-- de su codigo) y con el se fue el lanzador entero.
hl.bind("SUPER + D", hl.dsp.exec_cmd("pkill " .. menu .. " || " .. menu), { description = "Menu" })

hl.bind("SUPER + P", hl.dsp.exec_cmd("actions.sh projector"), { description = "Menu de proyector" })
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("actions.sh player"), { description = "Menu de playerctl" })
hl.bind("SUPER + Y", hl.dsp.exec_cmd('foot --title="Youtube Search" --app-id=floating -e ytfzf -ftT mpv'), { description = "Buscar en Youtube" })
hl.bind("SUPER + E", hl.dsp.exec_cmd("emoji.sh"), { description = "Emojis" })
hl.bind("SUPER + V", hl.dsp.exec_cmd("clipboard.sh"), { description = "Historial del portapapeles" })
hl.bind("SUPER + CTRL + C", hl.dsp.exec_cmd("color_picker.sh"), { description = "Cuentagotas" })
hl.bind("SUPER + C", hl.dsp.exec_cmd(calculator), { description = "Calculadora" })
hl.bind("XF86Calculator", hl.dsp.exec_cmd(calculator), { description = "Calculadora" })
hl.bind("SUPER + SHIFT + Y", hl.dsp.exec_cmd("killall mpv"), { description = "Terminar mpv" })

-------------------------------
---- BLOQUEO, SALIR, RECARGA ----
-------------------------------

hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("actions.sh power"), { description = "Menu de apagado" })
hl.bind("CTRL + ALT + L", hl.dsp.exec_cmd("bloquear.sh"), { description = "Bloquear pantalla" })

-- El .conf llamaba a "Refresh.sh" con mayuscula y el script es refresh.sh, asi
-- que este atajo no hacia nada en este portatil. Corregido al migrar.
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("refresh.sh"), { description = "Recargar Hyprland" })

-------------------
---- CAPTURAS ----
-------------------

hl.bind("PRINT", hl.dsp.exec_cmd("grimblast --notify copysave output"), { description = "Captura del monitor" })
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("grimblast --notify copysave active"), { description = "Captura de la ventana" })
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd("grimblast --notify copysave area"), { description = "Captura de un area" })
hl.bind("SUPER + PRINT", hl.dsp.exec_cmd("grimblast --notify edit output"), { description = "Satty, monitor" })
hl.bind("SUPER + SHIFT + PRINT", hl.dsp.exec_cmd("grimblast --notify edit active"), { description = "Satty, ventana" })
hl.bind("SUPER + CTRL + PRINT", hl.dsp.exec_cmd("grimblast --notify edit area"), { description = "Satty, area" })

-- Para el portatil, que no tiene tecla PRINT propia (fn + F6)
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("grimblast --notify edit area"), { description = "Satty, area" })

----------------
---- VENTANAS ----
----------------

hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Cerrar ventana" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen(), { description = "Pantalla completa" })
hl.bind("SUPER + T", hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }), { description = "Alternar opacidad" })
hl.bind("SUPER + SHIFT + F", hl.dsp.window.float(), { description = "Alternar flotante" })

-- El dispatcher workspaceopt desaparecio en 0.57: la cadena ya no esta en el
-- binario, asi que el `hyprctl dispatch workspaceopt allfloat` del .conf no
-- tenia a quien llamar. Se rehace en Lua, recorriendo las ventanas del
-- escritorio activo. Esto corre al oprimir la tecla, asi que --verify-config no
-- lo revisa: es el unico bind sin comprobar de la migracion.
hl.bind("SUPER + ALT + F", function()
    local escritorio = hl.get_active_workspace()
    if not escritorio then return end
    for _, ventana in ipairs(hl.get_workspace_windows(escritorio)) do
        hl.dispatch(hl.dsp.window.float({ window = ventana, action = "toggle" }))
    end
end, { description = "Todas flotantes" })

hl.bind("SUPER + B", hl.dsp.exec_cmd("killall -SIGUSR1 waybar"), { description = "Mostrar u ocultar waybar" })

-- Redimensionar
local resize = {
    { "left",  -50,   0 },
    { "right",  50,   0 },
    { "up",      0, -50 },
    { "down",    0,  50 },
    { "H",     -50,   0 },
    { "L",      50,   0 },
    { "K",       0, -50 },
    { "J",       0,  50 },
}
for _, r in ipairs(resize) do
    hl.bind("SUPER + SHIFT + " .. r[1],
        hl.dsp.window.resize({ x = r[2], y = r[3], relative = true }),
        { repeating = true, description = "Redimensionar" })
end

-- Mover la ventana
local dirs = {
    { "left",  "l" }, { "right", "r" }, { "up", "u" }, { "down", "d" },
    { "H",     "l" }, { "L",     "r" }, { "K",  "u" }, { "J",    "d" },
}
for _, d in ipairs(dirs) do
    hl.bind("SUPER + CTRL + " .. d[1],
        hl.dsp.window.move({ direction = d[2] }),
        { description = "Mover la ventana" })
end
hl.bind("SUPER + CTRL + RETURN", hl.dsp.window.center(), { description = "Centrar la ventana" })

-- Mover el foco
for _, d in ipairs(dirs) do
    hl.bind("SUPER + " .. d[1],
        hl.dsp.focus({ direction = d[2] }),
        { description = "Mover el foco" })
end

--------------------
---- ESCRITORIOS ----
--------------------

hl.bind("SUPER + tab", hl.dsp.focus({ workspace = "m+1" }), { description = "Escritorio siguiente" })
hl.bind("SUPER + SHIFT + tab", hl.dsp.focus({ workspace = "m-1" }), { description = "Escritorio anterior" })

-- Por codigo de tecla, como en el .conf: code:10 es el 1 fisico, sin importar
-- la distribucion del teclado. 9 + numero.
for n = 1, 9 do
    local code = "code:" .. (9 + n)
    hl.bind("SUPER + " .. code, hl.dsp.focus({ workspace = n }), { description = "Ir al escritorio " .. n })
    hl.bind("SUPER + SHIFT + " .. code, hl.dsp.window.move({ workspace = n }), { description = "Llevar la ventana al escritorio " .. n })
    hl.bind("SUPER + CTRL + " .. code, hl.dsp.window.move({ workspace = n, follow = false }), { description = "Enviar la ventana al escritorio " .. n })
end

hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Escritorio siguiente" })
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Escritorio anterior" })

-- Mover y redimensionar con el raton
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Mover la ventana" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Redimensionar la ventana" })

-----------------------
---- TECLAS DE FUNCION ----
-----------------------

-- Volumen
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("volume.sh --inc"), { locked = true, repeating = true, description = "Subir volumen" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("volume.sh --dec"), { locked = true, repeating = true, description = "Bajar volumen" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("volume.sh --toggle"), { locked = true, description = "Silenciar" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("volume.sh --toggle-mic"), { locked = true, description = "Silenciar microfono" })

-- Reproduccion
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Pista anterior" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Pista siguiente" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Pausa" })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true, description = "Detener" })

-- Brillo
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightness.sh --inc"), { locked = true, repeating = true, description = "Mas brillo" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightness.sh --dec"), { locked = true, repeating = true, description = "Menos brillo" })
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightness.sh --inc --keys"), { locked = true, repeating = true, description = "Mas luz en el teclado" })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightness.sh --dec --keys"), { locked = true, repeating = true, description = "Menos luz en el teclado" })

-- Touchpad
hl.bind("XF86TouchpadToggle", hl.dsp.exec_cmd("touchpad.sh"), { locked = true, description = "Alternar touchpad" })

-- Bloquear al suspender
hl.bind("XF86Sleep", hl.dsp.exec_cmd("bloquear.sh"), { locked = true, description = "Bloquear al suspender" })

-- Asus
hl.bind("XF86Launch3", hl.dsp.exec_cmd("asusctl led-mode -n"), { locked = true, description = "Asus aura" })
hl.bind("XF86Launch4", hl.dsp.exec_cmd('asusctl profile -n && notify-send -u low "$(asusctl profile -p | tail -1)"'), { locked = true, description = "Perfil de ventilador Asus" })
hl.bind("XF86Launch1", hl.dsp.exec_cmd("rog-control-center"), { locked = true, description = "Centro de control Asus" })
