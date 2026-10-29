-- Variables de entorno. Antes hyprvars.conf.

-- Cursor
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "wall-gtk")

-- XDG
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- Capturas
hl.env("GRIMBLAST_EDITOR", "satty --filename")

-- PATH. En el .conf esto decia "$HOME/.local/bin:$PATH" y dependia de que
-- alguien expandiera las dos variables. Aqui se arma en Lua y queda explicito.
--
-- Y se quitan los repetidos, que no es cosmetico: hl.env corre en CADA recarga
-- de configuracion, asi que anteponer la carpeta sin mirar la metia otra vez
-- cada vez. Medido el 29 de octubre de 2026 tras una tarde de recargas:
-- ~/.local/bin aparecia decenas de veces seguidas en el PATH de los procesos
-- hijos. Funciona igual, pero crece sin tope y no hay razon para dejarlo.
local function path_con_bin_propio()
    local bin = os.getenv("HOME") .. "/.local/bin"
    local actual = os.getenv("PATH") or "/usr/local/bin:/usr/bin:/bin"
    local vistos, partes = {}, {}
    for parte in (bin .. ":" .. actual):gmatch("[^:]+") do
        if not vistos[parte] then
            vistos[parte] = true
            partes[#partes + 1] = parte
        end
    end
    return table.concat(partes, ":")
end

hl.env("PATH", path_con_bin_propio())

-- Fzf
hl.env("FZF_DEFAULT_COMMAND", "fd --type file --color=always")
hl.env("FZF_DEFAULT_OPTS", "--ansi")

-- Manpager
hl.env("MANROFFOPT", "-c")

-- Render
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_SCALE_FACTOR_ROUNDING_POLICY", "RoundPreferFloor")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland,x11")

-- Aplicaciones por omision. Antes user_configs/default_apps.conf. Los binds de
-- hyprbinds.lua usan estos mismos nombres desde el modulo, no desde el entorno.
hl.env("TERMINAL", "alacritty")
hl.env("SHELL", "/bin/zsh")
hl.env("EDITOR", "nvim")
hl.env("BROWSER", "vivaldi")
hl.env("FILE_MANAGER", "yazi")
hl.env("MENU", "fuzzel")
hl.env("CALCULATOR", "calc.fish")
hl.env("PAGER", "bat -p")
hl.env("MANPAGER", "sh -c 'col -bx | bat -p -lman'")
