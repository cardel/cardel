-- Arranque. Antes hyprstart.conf mas los exec-once de overrides.conf.
--
-- Los exec-once pasan a un manejador del evento hyprland.start. Los `exec`,
-- que corrian tambien en cada recarga, se trataron uno por uno:
--
--   hyprcolors.sh  fuera. Metia los colores de pywal con
--                  `hyprctl keyword '$color3' ...`, y las variables de
--                  configuracion ya no existen en 0.57. Ahora hyprance.lua lee
--                  ~/.cache/wal/colors directo, asi que el color del borde
--                  sigue a pywal en cada recarga sin ayuda de nadie.
--   keybinds.sh    se queda, pero lee hyprbinds.conf para armar la tabla del
--                  menu de acciones, y ese archivo ya no manda. La tabla queda
--                  congelada en lo que decia el .conf. Hay que reescribirlo
--                  contra `hyprctl binds`, que ahora trae descripcion.
--   touchpad.sh -r fuera. Alternaba $TOUCHPAD_ENABLED con `hyprctl keyword`,
--                  que ya no existe. overrides.lua deja el touchpad activo.

local home = os.getenv("HOME")

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/bin/lxqt-policykit-agent >/dev/null")
    hl.exec_cmd("mako")
    hl.exec_cmd("wbg " .. home .. "/.cache/current_wallpaper.png")

    -- Solo texto
    hl.exec_cmd("wl-paste --type text --watch cliphist store")

    hl.exec_cmd("initial_boot.sh")
    hl.exec_cmd("battery_notify.sh")
    hl.exec_cmd("keybinds.sh")

    -- waybar, y despues una recarga. Los dos hacen falta: waybar-arranque.sh
    -- SOLO recarga, espera a que el proceso exista y sale callado si no lo
    -- encuentra. Al migrar lo deje solo y la barra no aparecio.
    --
    -- La recarga esta porque la instancia que arranca con la sesion se queda a
    -- veces con el modulo de escritorios vivo pero vacio, ni pinta numeros ni
    -- reacciona a los eventos. La causa exacta no esta identificada; lo
    -- descartado esta en waybar/README.md.
    hl.exec_cmd("waybar")
    hl.exec_cmd("waybar-arranque.sh")

    hl.exec_cmd("pcloud")

    -- ProtonVPN: el binario es protonvpn-app, no proton-vpn. Ese nombre no
    -- existe y el arranque fallaba en silencio. Queda en la bandeja y NO
    -- conecta: eso lo decide connect_at_app_startup en
    -- ~/.config/Proton/VPN/app-config.json, que esta en null.
    hl.exec_cmd("protonvpn-app --start-minimized")
end)
