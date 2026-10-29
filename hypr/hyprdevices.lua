-- Entrada y salida por omision. Antes hyprdevices.conf.
-- overrides.lua vuelve a tocar input mas abajo, y gana.

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
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

-- Comodin para cualquier monitor que no tenga regla propia. Ojo con esto: el
-- modo "highrr" elige la mayor frecuencia sin mirar la resolucion, y en el
-- monitor USB-C eso daba 800x600. Por eso maquina.lua lo declara aparte.
hl.monitor({ output = "", mode = "highrr", position = "auto", scale = "auto" })
