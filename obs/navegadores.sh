#!/usr/bin/env bash
# navegadores.sh -- pone a Chromium y a Firefox a pedir la camara por PipeWire.
#
#   ./navegadores.sh          la activa en los dos
#   ./navegadores.sh --off    la quita
#
# Es el camino 1 del README: mientras el navegador abra /dev/video0 el mismo,
# nadie mas puede usar la camara. Pidiendola por PipeWire (via el portal) deja
# de ser exclusiva y OBS puede leerla a la vez.
#
# No pide root. Es idempotente: pasarlo dos veces no duplica nada.
#
# Los dos navegadores tienen que estar CERRADOS: los dos reescriben su config al
# salir y se llevarian por delante lo que se escriba aqui debajo.
set -euo pipefail

APAGAR=0
[[ "${1:-}" == "--off" ]] && APAGAR=1

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
FLAG_CHROMIUM="enable-webrtc-pipewire-camera@1"
PREF_FIREFOX="media.webrtc.camera.allow-pipewire"

respaldar() {
  cp -a -- "$1" "$1.bak.$(date +%Y%m%d-%H%M%S)"
}

# --- Chromium -------------------------------------------------------------
# El flag vive en "Local State", que es lo que escribe chrome://flags.
aplicar_chromium() {
  local ls="$CONF/chromium/Local State"
  if [[ ! -f "$ls" ]]; then
    echo "chromium: no hay perfil en $CONF/chromium, se omite"
    return
  fi
  if pgrep -x chromium >/dev/null; then
    echo "chromium: ESTA ABIERTO -- cierralo y repite, si no se pierde el cambio" >&2
    return
  fi
  # Respaldo solo si el cambio es real, si no cada pasada deja una copia mas.
  if grep -qF "$FLAG_CHROMIUM" "$ls"; then
    [[ "$APAGAR" == "1" ]] && respaldar "$ls"
  else
    [[ "$APAGAR" == "0" ]] && respaldar "$ls"
  fi
  APAGAR="$APAGAR" FLAG="$FLAG_CHROMIUM" ARCHIVO="$ls" python3 - <<'PY'
import json, os, pathlib
p = pathlib.Path(os.environ["ARCHIVO"])
flag, apagar = os.environ["FLAG"], os.environ["APAGAR"] == "1"
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
print("chromium:", ("desactivado" if apagar else "activado") if cambio else "ya estaba como toca")
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
    echo "firefox: no hay perfiles en $base, se omite"
    return
  fi
  if pgrep -x firefox >/dev/null; then
    echo "firefox: ESTA ABIERTO -- cierralo y repite, si no se pierde el cambio" >&2
    return
  fi

  local perfiles=()
  while IFS= read -r ruta; do
    [[ -d "$base/$ruta" ]] && perfiles+=("$base/$ruta")
  done < <(grep -oP '^Path=\K.*' "$base/profiles.ini" 2>/dev/null || true)

  if [[ ${#perfiles[@]} -eq 0 ]]; then
    echo "firefox: profiles.ini no lista ningun perfil, se omite"
    return
  fi

  local linea="user_pref(\"$PREF_FIREFOX\", true);"
  for p in "${perfiles[@]}"; do
    local uj="$p/user.js"
    if [[ "$APAGAR" == "1" ]]; then
      if [[ -f "$uj" ]] && grep -qF "$PREF_FIREFOX" "$uj"; then
        respaldar "$uj"
        grep -vF "$PREF_FIREFOX" "$uj" > "$uj.tmp" && mv -- "$uj.tmp" "$uj"
        echo "firefox: desactivado en $(basename -- "$p")"
      else
        echo "firefox: ya estaba fuera en $(basename -- "$p")"
      fi
      continue
    fi
    if [[ -f "$uj" ]] && grep -qF "$linea" "$uj"; then
      echo "firefox: ya estaba como toca en $(basename -- "$p")"
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
      echo "firefox: activado en $(basename -- "$p")"
    fi
  done
}

aplicar_chromium
aplicar_firefox
echo
echo "reinicia los navegadores ENTEROS: enumeran los dispositivos al arrancar"
echo "y no vuelven a mirar."
