-- Apariencia. Antes hyprance.conf.
--
-- Los colores venian de diecisiete variables de configuracion que hyprcolors.sh
-- rellenaba con `hyprctl keyword`. Eso ya no existe, asi que aqui se lee el
-- archivo que pywal genera y se usa el color que de verdad se usaba, el 3.

local function color_de_pywal(indice)
    local f = io.open(os.getenv("HOME") .. "/.cache/wal/colors", "r")
    if not f then return nil end
    local n = 0
    local hex = nil
    for linea in f:lines() do
        if n == indice then
            hex = linea
            break
        end
        n = n + 1
    end
    f:close()
    if not hex then return nil end
    local limpio = hex:gsub("^#", "")
    return "0xff" .. limpio
end

local borde_activo = color_de_pywal(3) or "0xff363737"

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 20,
        border_size = 2,
        col = {
            active_border   = borde_activo,
            inactive_border = "0xff363737",
        },
        layout = "master",
        allow_tearing = false,
    },

    decoration = {
        rounding = 10,
        blur = {
            enabled = true,
            size    = 3,
            passes  = 1,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "windows",     enabled = true, speed = 7,  bezier = "myBezier" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 7,  bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "fade",        enabled = true, speed = 7,  bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "default" })
