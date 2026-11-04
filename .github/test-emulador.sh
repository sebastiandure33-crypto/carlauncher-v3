#!/bin/bash
# Prueba Car Launcher 4 en un emulador Android 10 de 1024x600 (como la radio):
# recorre las pantallas, prueba día/noche, brillo, volumen, búsqueda y ruta, mantenimiento,
# y guarda capturas y resultados en out/.
OUT=out
PKG=com.rgservice.carlauncher4
RES=$OUT/resultados.txt
: > $RES
log() { echo "$*" | tee -a $RES; }
shot() { sleep "${2:-2}"; adb exec-out screencap -p > "$OUT/$1.png"; }

# Toca el elemento cuyo texto o descripción contiene $1 ("=x" busca exacto); si no lo encuentra toca $2,$3
tapd() {
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb pull /sdcard/ui.xml $OUT/ui.xml >/dev/null 2>&1
  B=$(python3 - "$1" <<'PY'
import re,sys,html
t=sys.argv[1]; exact=t.startswith('='); t=t[1:] if exact else t
try: s=open('out/ui.xml',encoding='utf-8').read()
except Exception: s=''
for m in re.finditer(r'<node [^>]*?>',s):
    n=m.group(0)
    vals=[html.unescape(v) for v in re.findall(r'(?:text|content-desc)="([^"]*)"',n)]
    ok=any((v.strip()==t) if exact else (t in v) for v in vals)
    b=re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',n)
    if ok and b:
        x1,y1,x2,y2=map(int,b.groups()); print((x1+x2)//2,(y1+y2)//2); break
PY
)
  if [ -n "$B" ]; then adb shell input tap $B; echo "toque '$1' en $B";
  elif [ -n "$2" ]; then adb shell input tap $2 $3; echo "toque '$1' por coordenadas $2 $3";
  else echo "NO ENCONTRADO: '$1'"; fi
}
bright() { adb shell settings get system screen_brightness | tr -d '\r'; }
vol() { adb shell media volume --stream 3 --get 2>/dev/null | grep -o 'volume is [0-9]*' | grep -o '[0-9]*$'; }

adb shell wm density 160
adb shell settings put secure immersive_mode_confirmations confirmed
adb shell settings put global window_animation_scale 1
adb shell wm size | tee $OUT/pantalla.txt

# GPS simulado en Asunción (se repite para que no se vea "sin GPS")
( while true; do adb emu geo fix -57.6050 -25.2950 >/dev/null 2>&1; sleep 2; done ) &
GEO=$!

adb install -r -g $OUT/CarLauncher4.apk | tee $OUT/instalacion.txt
adb shell appops set $PKG WRITE_SETTINGS allow
adb shell cmd notification allow_listener $PKG/$PKG.CarNotificationListener
adb shell settings put system screen_brightness_mode 0
adb shell settings put system screen_brightness 128
adb shell media volume --stream 3 --set 5 >/dev/null 2>&1
adb logcat -c
adb shell am start -W -n $PKG/.MainActivity | tee $OUT/arranque.txt
shot 01_inicio 12

# ---------------------------------------------------------------- día / noche
tapd "Modo " 42 510;           shot 02_modo_1 3
tapd "Modo " 42 510;           shot 03_modo_2 3
tapd "Modo " 42 510;           sleep 2
tapd "Modo Noche" 42 510;      sleep 2
adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb pull /sdcard/ui.xml $OUT/ui.xml >/dev/null 2>&1
grep -o 'Modo [A-Za-zíá]*' $OUT/ui.xml | head -1 | sed 's/^/Modo actual: /' | tee -a $RES

# ---------------------------------------------------------------- brillo y volumen (pantalla Apps)
tapd "=Apps" 42 426;           shot 04_apps 4
B0=$(bright); V0=$(vol)
adb shell input tap 180 160;   sleep 2
B1=$(bright)
adb shell input tap 349 330;   sleep 2
V1=$(vol)
log "Brillo del sistema: antes $B0 -> después $B1  $( [ "$B0" != "$B1" ] && echo OK || echo 'NO CAMBIÓ')"
log "Volumen música: antes $V0 -> después $V1  $( [ "$V0" != "$V1" ] && echo OK || echo 'NO CAMBIÓ')"
shot 05_apps_brillo_volumen 2

# brillo por modo: pasar a Día debe aplicar el brillo de día
tapd "Modo " 42 510;           sleep 3
B2=$(bright)
log "Brillo al pasar de modo: $B1 -> $B2  $( [ "$B1" != "$B2" ] && echo OK || echo 'NO CAMBIÓ')"
shot 06_apps_otro_modo 2
tapd "Modo " 42 510;           sleep 1
tapd "Modo " 42 510;           sleep 2

# ---------------------------------------------------------------- audio
tapd "=Audio" 42 228;          shot 07_audio_bluetooth 4
V2=$(vol)
tapd "Subir volumen" 0 0;      sleep 2
V3=$(vol)
log "Botón subir volumen: $V2 -> $V3  $( [ "$V2" != "$V3" ] && echo OK || echo 'NO CAMBIÓ')"
tapd "=Radio FM" 0 0;          shot 08_audio_radio 3
tapd "Reproducir" 0 0;         shot 09_audio_radio_play 2

# ---------------------------------------------------------------- mapa: búsqueda y ruta
tapd "=Mapa" 42 162;           shot 10_mapa 8
tapd "dónde vamos" 330 42;     sleep 1
adb shell input text "Palacio%sde%sLopez"
shot 11_mapa_busqueda 8
tapd "Palacio de L" 330 120;   shot 12_mapa_ruta 10
shot 13_mapa_ruta_siguiendo 8
adb shell input keyevent KEYCODE_BACK
tapd "=Inicio" 42 96;          shot 14_inicio_con_ruta 4

# ---------------------------------------------------------------- mantenimiento
tapd "=Auto" 42 360;           shot 15_mantenimiento 5
tapd "Rotación de neumáticos" 0 0;  shot 16a_transicion 0.25
shot 16b_ruedas 1.5
tapd "Pastillas de freno" 0 0; shot 17a_transicion 0.25
shot 17b_frenos 1.5
tapd "Pastillas de freno" 0 0; shot 18_editor_frenos 2
tapd "Próximo cambio" 0 0;     shot 19_teclado 2
for d in 2 5 0 0 0; do tapd "=$d" 0 0; sleep 0.4; done
shot 19b_teclado_escrito 1
tapd "=Guardar" 0 0;           shot 20_editor_guardado 2
adb shell input keyevent KEYCODE_BACK; sleep 1
tapd "Cerrar" 0 0;             shot 21_mantenimiento_guardado 2

# ---------------------------------------------------------------- ajustes y diagnóstico
tapd "=Apps" 42 426;           sleep 2
tapd "=Ajustes" 0 0;           shot 22_ajustes 3
adb shell input swipe 600 520 600 120 500; sleep 1
adb shell input swipe 600 520 600 120 500; shot 23_ajustes_abajo 2
tapd "Revisar música" 0 0;     shot 24_diagnostico 4

kill $GEO 2>/dev/null
sleep 2
PID=$(adb shell pidof $PKG | tr -d '\r')
echo "PID=$PID" | tee -a $RES
adb logcat -d > $OUT/logcat_completo.txt
grep -E "FATAL EXCEPTION" -A40 $OUT/logcat_completo.txt > $OUT/errores.txt || true
grep -E " E flutter|E/flutter|Another exception|══╡ EXCEPTION" -A12 $OUT/logcat_completo.txt > $OUT/errores_flutter.txt || true
log "Errores de Flutter: $(grep -c 'EXCEPTION\|E flutter\|E/flutter' $OUT/errores_flutter.txt)"
rm -f $OUT/ui.xml
if [ -z "$PID" ] || [ -s $OUT/errores.txt ]; then log "LA APP SE CERRÓ"; exit 1; fi
log "OK: recorrió todas las pantallas y sigue abierta"
