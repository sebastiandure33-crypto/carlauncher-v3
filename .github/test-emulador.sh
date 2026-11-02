#!/bin/bash
# Instala el APK en un emulador Android 10 de 1024x600, lo recorre y revisa que no se cierre.
# Deja capturas y registro en out/.
OUT=out
PKG=com.rgservice.carlauncher3
shot() { sleep "${2:-2}"; adb exec-out screencap -p > "$OUT/$1.png"; }
# Toca el primer elemento cuyo texto contiene $1 (Compose expone los textos a la accesibilidad)
tap() {
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb pull /sdcard/ui.xml $OUT/ui.xml >/dev/null 2>&1
  B=$(python3 - "$1" <<'PY'
import re,sys
t=sys.argv[1]; s=open('out/ui.xml',encoding='utf-8').read()
for m in re.finditer(r'<node [^>]*?text="([^"]*)"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',s):
    if t in m.group(1):
        x1,y1,x2,y2=map(int,m.groups()[1:]); print((x1+x2)//2,(y1+y2)//2); break
PY
)
  if [ -n "$B" ]; then adb shell input tap $B; echo "toque '$1' en $B"; else echo "NO ENCONTRADO: '$1'"; fi
}

adb shell wm density 160
adb shell wm size | tee $OUT/pantalla.txt
adb install -r -g $OUT/CarLauncher3.apk | tee $OUT/instalacion.txt
adb logcat -c
adb shell am start -W -n $PKG/com.rgservice.carlauncher.MainActivity | tee $OUT/arranque.txt
shot 01_bienvenida 3
shot 02_inicio 8
tap "Ver todo";            shot 03_mantenimiento 4
tap "Rotación";            shot 04_mantenimiento_ruedas 4
adb shell input keyevent KEYCODE_BACK
# Cargar km del tablero escribiendo con el teclado y marcar "Lo cambié hoy"
tap "Aceite motor";        shot 05_ventana_tablero 2
adb shell input text 120000; shot 05b_tablero_escrito 1
adb shell input keyevent KEYCODE_ENTER; shot 05c_ventana_aceite 2
tap "Lo cambié hoy";       shot 05d_inicio_con_aceite 3
tap "Ver todo";            shot 05e_mantenimiento_cargado 4
adb shell input keyevent KEYCODE_BACK; sleep 2
tap "Apps";                shot 06_apps 4
adb shell input keyevent KEYCODE_BACK; sleep 2
tap "Ajustes";             shot 07_ajustes 3
adb shell input swipe 512 500 512 150 400; shot 07b_ajustes_abajo 2
tap "Diagnóstico";         shot 08_diagnostico_musica 2
adb shell input keyevent KEYCODE_BACK; sleep 1
tap "Nombre";              shot 08b_nombre 2
adb shell input text Ruben; adb shell input keyevent KEYCODE_ENTER; sleep 1
adb shell input keyevent KEYCODE_BACK; sleep 2
adb shell input swipe 900 300 700 300 300; shot 09_pagina_mapa 4
adb shell input swipe 900 300 700 300 300; shot 10_pagina_accesos 2
tap "Noche auto";          shot 11_modo_noche 2
tap "Noche";               shot 12_modo_dia 2
tap "Día"; sleep 1
sleep 3
PID=$(adb shell pidof $PKG | tr -d '\r')
echo "PID=$PID" | tee $OUT/proceso.txt
adb logcat -d > $OUT/logcat_completo.txt
grep -E "FATAL EXCEPTION" -A40 $OUT/logcat_completo.txt > $OUT/errores.txt || true
adb shell dumpsys meminfo $PKG | head -40 > $OUT/memoria.txt || true
rm -f $OUT/ui.xml
if [ -z "$PID" ] || [ -s $OUT/errores.txt ]; then echo "LA APP SE CERRÓ" | tee -a $OUT/proceso.txt; exit 1; fi
echo "OK: recorrió todas las pantallas y sigue abierta, sin errores" | tee -a $OUT/proceso.txt
