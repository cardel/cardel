-- LaTeX (VimTeX): visor con SyncTeX y quickfix menos ruidoso
--
-- El extra lazyvim.plugins.extras.lang.tex trae vimtex y texlab, pero deja el
-- visor sin configurar: solo toca vimtex_mappings_disable y
-- vimtex_quickfix_method. Sin vimtex_view_method, VimTeX usa su metodo por
-- defecto en Linux, "general", que se limita a lanzar el PDF con xdg-open. Eso
-- deja fuera las dos cosas que hacen util escribir LaTeX en un editor:
--
--   forward search  -- <localleader>lv lleva el PDF a la pagina y el punto
--                      exacto donde esta el cursor
--   inverse search  -- clic (o <C-clic>) en el PDF y Neovim salta a la linea
--                      del .tex que genero ese texto
--
-- Con 544 archivos .tex aqui -- 60 de beamer, 51 article, 11 IEEEtran, mas las
-- clases de Elsevier (cas-dc, cas-sc) y Springer (sn-jnl) -- y una tesis
-- repartida en 61 archivos, saltar entre fuente y PDF es la operacion mas
-- repetida del dia.
--
-- Requisito del sistema: zathura CON un backend de PDF. El paquete `zathura`
-- solo no abre nada; hay que instalar ademas zathura-pdf-mupdf (o
-- zathura-pdf-poppler). Se comprueba con `ls /usr/lib/zathura/`: si ese
-- directorio no existe, no hay backend.
--
-- El inverse search no necesita configuracion extra: VimTeX le pasa a zathura
-- su propio --synctex-editor-command apuntando al servidor de esta instancia
-- (v:servername), que Neovim siempre tiene.

return {
  {
    "lervag/vimtex",
    optional = true,
    init = function()
      -- zathura es el unico visor de los que soporta VimTeX que esta empaquetado
      -- en Arch y hace SyncTeX en los dos sentidos. evince, que era lo unico
      -- instalado antes, necesita un puente por dbus y solo hace forward.
      vim.g.vimtex_view_method = "zathura"

      -- El quickfix se abria con cualquier aviso. Las clases de journal avisan
      -- muchisimo por cosas que no son errores, asi que la ventana saltaba en
      -- cada compilacion y tapaba el texto. Con esto solo se abre si hay errores
      -- de verdad; los avisos siguen en la lista, accesibles con :copen.
      vim.g.vimtex_quickfix_open_on_warning = 0

      -- Ruido tipografico que no se corrige hasta el final del documento, si es
      -- que se corrige. Filtrarlo deja ver los errores reales.
      vim.g.vimtex_quickfix_ignore_filters = {
        "Overfull \\\\hbox",
        "Underfull \\\\hbox",
        "Overfull \\\\vbox",
        "Underfull \\\\vbox",
        "Font shape declaration has incorrect series value",
      }
    end,
  },
}

-- Nota sobre el motor: latexmk usa pdflatex por defecto y eso vale para 541 de
-- los 544 archivos. Los 3 que cargan fontspec/polyglossia necesitan xelatex, y
-- la forma correcta es un .latexmkrc junto a ESE documento con
--
--     $pdf_mode = 5;   # 1 = pdflatex, 4 = lualatex, 5 = xelatex
--
-- en vez de cambiar el motor global, que romperia los otros 541. latexmk lo lee
-- solo y VimTeX no tiene que enterarse.
