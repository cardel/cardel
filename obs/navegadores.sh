#!/usr/bin/env bash
# navegadores.sh -- pone a los navegadores a pedir la camara por PipeWire.
#
#   ./navegadores.sh          la activa en todos los que encuentre
#   ./navegadores.sh --off    la quita
#
# Es el camino 1 del README: mientras un programa abra /dev/video0 el mismo,
# nadie mas puede usar la camara. Pidiendola por PipeWire (via el portal) deja
# de ser exclusiva y OBS, Zoom y los navegadores pueden leerla a la vez.
#
# No pide root. Es idempotente: pasarlo dos veces no duplica nada.
#
# Los navegadores tienen que estar CERRADOS: reescriben su config al salir y se
# llevarian por delante lo que se escriba aqui debajo.
set -euo pipefail

APAGAR=0
[[ "${1:-}" == "--off" ]] && APAGAR=1

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
FLAG_CHROMIUM="enable-webrtc-pipewire-camera@1"
PREF_FIREFOX="media.webrtc.camera.allow-pipewire"

# Todo lo derivado de Chromium usa el mismo flag y el mismo formato de archivo,
# asi que van todos por la misma funcion. Los campos son:
#
#   etiqueta | directorio bajo ~/.config | nombre EXACTO del proceso | binario
#
# El nombre del proceso importa mas de lo que parece: Vivaldi corre como
# `vivaldi-bin`, no como `vivaldi`. Un `pgrep -x vivaldi` no encuentra nada
# aunque este abierto, y entonces el guardia de "cierralo primero" no salta y el
# navegador te pisa el cambio al salir.
#
# El binario solo se usa para comprobar que ese flag todavia existe en esa
# version. Si no esta en la lista, no pasa nada: el chequeo se omite.
NAVEGADORES=(
  "Chromium|chromium|chromium|/usr/lib/chromium/chromium"
  "Vivaldi|vivaldi|vivaldi-bin|/opt/vivaldi/vivaldi-bin"
  "Chrome|google-chrome|chrome|/opt/google/chrome/chrome"
  "Brave|BraveSoftware/Brave-Browser|brave|/usr/lib/brave-bin/brave"
)

respaldar() {
  cp -a -- "$1" "$1.bak.$(date +%Y%m%d-%H%M%S)"
}

# --- navegadores derivados de Chromium ------------------------------------
# El flag vive en "Local State", que es el mismo archivo que escribe
# chrome://flags (o vivaldi://flags, o brave://flags).
aplicar_chromium_like() {
  local etiqueta="$1" dir="$2" proc="$3" bin="$4"
  local ls="$CONF/$dir/Local State"

  if [[ ! -f "$ls" ]]; then
    echo "$etiqueta: sin perfil en $CONF/$dir, se omite"
    return
  fi

  if pgrep -x "$proc" >/dev/null 2>&1; then
    echo "$etiqueta: ESTA ABIERTO (proceso $proc) -- cierralo y repite, si no se pierde el cambio" >&2
    return
  fi

  # Que la version instalada siga teniendo el flag. Un dia Chromium lo quitara
  # --o lo hara permanente-- y sin esto seguiriamos escribiendo una entrada
  # muerta en Local State sin que nadie se entere.
  # grep -a: el binario pasa de 300 MB pero se recorre en decimas de segundo.
  if [[ -f "$bin" ]] && ! grep -qa 'enable-webrtc-pipewire-camera' "$bin"; then
    echo "$etiqueta: AVISO -- esta version ya no conoce enable-webrtc-pipewire-camera;" >&2
    echo "          comprueba en ${dir}://flags si cambio de nombre" >&2
  fi

  if grep -qF "$FLAG_CHROMIUM" "$ls"; then
    [[ "$APAGAR" == "1" ]] && respaldar "$ls"
  else
    [[ "$APAGAR" == "0" ]] && respaldar "$ls"
  fi

  APAGAR="$APAGAR" FLAG="$FLAG_CHROMIUM" ARCHIVO="$ls" ETIQUETA="$etiqueta" python3 - <<'PY'
import json, os, pathlib
p = pathlib.Path(os.environ["ARCHIVO"])
flag, apagar = os.environ["FLAG"], os.environ["APAGAR"] == "1"
etiqueta = os.environ["ETIQUETA"]
d = json.loads(p.read_text())
exp = d.setdefault("browser", {}).setdefault("enabled_labs_experiments", [])
if apagar:
    cambio = flag in exp
    d["browser"]["enabled_labs_experiments"] = [e for e in exp if e != flag]
else:
    cambio = flag not in exp
    if cambio:
        exp.append(flag)
if cambio:
    p.write_text(json.dumps(d, separators=(",", ":")))
print(f"{etiqueta}:", ("desactivado" if apagar else "activado") if cambio else "ya estaba como toca")
PY
}

# --- Firefox --------------------------------------------------------------
# Se escribe en user.js y no en prefs.js: prefs.js lo reescribe Firefox al
# cerrarse, user.js lo lee en cada arranque y gana. A cambio, el valor queda
# fijado y about:config no lo puede cambiar de forma permanente; para soltarlo,
# ./navegadores.sh --off
aplicar_firefox() {
  local base="$HOME/.mozilla/firefox"

  if [[ ! -d "$base" ]]; then
    # Instalado pero sin estrenar no es lo mismo que no instalado, y la
    # diferencia importa: el perfil no existe hasta el primer arranque, asi que
    # aqui no hay donde escribir todavia.
    if command -v firefox >/dev/null 2>&1; then
      echo "Firefox: instalado pero sin perfil todavia -- abrelo una vez, cierralo,"
      echo "         y vuelve a pasar este script"
    else
      echo "Firefox: no esta instalado, se omite"
    fi
    return
  fi

  if pgrep -x firefox >/dev/null 2>&1; then
    echo "Firefox: ESTA ABIERTO -- cierralo y repite, si no se pierde el cambio" >&2
    return
  fi

  local perfiles=()
  while IFS= read -r ruta; do
    [[ -d "$base/$ruta" ]] && perfiles+=("$base/$ruta")
  done < <(grep -oP '^Path=\K.*' "$base/profiles.ini" 2>/dev/null || true)

  if [[ ${#perfiles[@]} -eq 0 ]]; then
    echo "Firefox: profiles.ini no lista ningun perfil, se omite"
    return
  fi

  local linea="user_pref(\"$PREF_FIREFOX\", true);"
  for p in "${perfiles[@]}"; do
    local uj="$p/user.js"
    if [[ "$APAGAR" == "1" ]]; then
      if [[ -f "$uj" ]] && grep -qF "$PREF_FIREFOX" "$uj"; then
        respaldar "$uj"
        grep -vF "$PREF_FIREFOX" "$uj" > "$uj.tmp" && mv -- "$uj.tmp" "$uj"
        echo "Firefox: desactivado en $(basename -- "$p")"
      else
        echo "Firefox: ya estaba fuera en $(basename -- "$p")"
      fi
      continue
    fi
    if [[ -f "$uj" ]] && grep -qF "$linea" "$uj"; then
      echo "Firefox: ya estaba como toca en $(basename -- "$p")"
    else
      if [[ -f "$uj" ]]; then
        respaldar "$uj"
        grep -vF "$PREF_FIREFOX" "$uj" > "$uj.tmp" && mv -- "$uj.tmp" "$uj"
      fi
      {
        echo "// Camara por PipeWire, para poder compartirla con OBS."
        echo "// Lo pone obs/navegadores.sh de los dotfiles; quitalo con --off."
        echo "$linea"
      } >> "$uj"
      echo "Firefox: activado en $(basename -- "$p")"
    fi
  done
}

for entrada in "${NAVEGADORES[@]}"; do
  IFS='|' read -r etiqueta dir proc bin <<<"$entrada"
  aplicar_chromium_like "$etiqueta" "$dir" "$proc" "$bin"
done
aplicar_firefox

echo
echo "reinicia los navegadores ENTEROS: enumeran los dispositivos al arrancar"
echo "y no vuelven a mirar."
