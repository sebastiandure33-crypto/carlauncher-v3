#!/bin/bash
# Instala el APK en el emulador, lo abre y revisa que no se cierre. Deja capturas y registro en out/.
set -x
OUT=out
PKG=com.rgservice.carlauncher3
adb shell wm size 1024x600
adb shell wm density 160
adb install -r -g $OUT/CarLauncher3.apk | tee $OUT/instalacion.txt
adb logcat -c
adb shell am start -W -n $PKG/com.rgservice.carlauncher.MainActivity | tee $OUT/arranque.txt
sleep 3;  adb exec-out screencap -p > $OUT/1_bienvenida.png
sleep 9;  adb exec-out screencap -p > $OUT/2_inicio.png
# Abrir Ajustes, Apps y Mantenimiento tocando la barra / "Ver todo" no es fiable por coordenadas:
# se usan las teclas: Home y vuelta, y se rota por las páginas de la tarjeta derecha con un deslizamiento.
adb shell input swipe 900 300 700 300 300; sleep 2; adb exec-out screencap -p > $OUT/3_pagina_mapa.png
adb shell input swipe 900 300 700 300 300; sleep 2; adb exec-out screencap -p > $OUT/4_pagina_accesos.png
adb shell input keyevent KEYCODE_HOME; sleep 3; adb exec-out screencap -p > $OUT/5_home.png
adb shell input keyevent KEYCODE_BACK; sleep 1
sleep 5
PID=$(adb shell pidof $PKG | tr -d '\r')
echo "PID=$PID" | tee $OUT/proceso.txt
adb logcat -d > $OUT/logcat_completo.txt
adb logcat -d -b crash > $OUT/crash.txt || true
grep -E "FATAL EXCEPTION|AndroidRuntime" -A30 $OUT/logcat_completo.txt > $OUT/errores.txt || true
adb shell dumpsys meminfo $PKG | head -40 > $OUT/memoria.txt || true
if [ -z "$PID" ] || [ -s $OUT/errores.txt ]; then echo "LA APP SE CERRÓ" | tee -a $OUT/proceso.txt; exit 1; fi
echo "OK: la app sigue abierta y sin errores" | tee -a $OUT/proceso.txt
