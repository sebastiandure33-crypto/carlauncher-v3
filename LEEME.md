# Car Launcher 4 (Flutter)

Pantalla de inicio para la radio Android del auto (7", 1024×600, Android 10).
Se instala junto al Car Launcher 3: es otra app (`com.rgservice.carlauncher4`).

## Compilar (GitHub, sin Android Studio)

1. Crear un repositorio en GitHub y subir **todo** el contenido de esta carpeta (incluida la carpeta oculta `.github`).
2. Pestaña **Actions** › **Compilar APK** › *Run workflow* (también arranca solo con cada cambio en `main`).
3. Al terminar con ✅: abrir la ejecución › **Artifacts** › `CarLauncher4-apk`. Adentro está `CarLauncher4.apk`.
   También queda en la rama `apk` del repositorio.
4. Si termina con ❌: abrir el paso **Revisar código** o **Compilar release** y copiar las líneas con `error`.

El workflow ejecuta `flutter create .` para completar la carpeta `android/` (gradle, íconos, temas).
No pisa los archivos propios: el manifiesto y el código Kotlin de `android/app/src/main/`.

### Con Android Studio

```
flutter create --platforms=android --org com.rgservice --project-name carlauncher4 .
flutter pub get
flutter build apk --release
```

## Primer arranque en la radio

1. Abrir "Car Launcher 4" y permitir **Ubicación** (velocidad, viaje y km).
2. En la tarjeta de música: **Permitir** › activar Car Launcher 4 en *Acceso a notificaciones*. Esto sirve para ver y controlar la música y para leer el próximo giro de Maps o Waze.
3. Ajustes (engranaje en Apps):
   - **Pantalla de inicio** › elegir Car Launcher 4 › *Siempre*.
   - **Cambiar el brillo** › permitir *Modificar ajustes del sistema*.
   - **Permiso para abrirse solo** (recomendado).
4. Elegir las apps de cada botón: Ajustes › *Apps de cada botón*. También se puede mantener apretado el botón.
   - **Bluetooth**: la app de música Bluetooth de la radio (por ejemplo `com.tw.bt`).
   - **Radio FM**: la app de radio de la pantalla.
   - **Teléfono**, **USB**, **Mapas** y **Ecualizador**.
5. Mantenimiento › **Cargar km**: los km del tablero. Después el GPS los va sumando solo.

## Qué hace cada pantalla

- **Inicio**
  - Mapa con caché: lo que se ve con internet queda guardado.
  - Velocímetro GPS con el aviso del límite.
  - Viaje: km, minutos y promedio.
  - Clima: Open-Meteo; sin internet muestra el último guardado.
  - Próximo giro de Maps o Waze.
  - Casa y Trabajo: toque largo para guardar la ubicación actual.
  - Música y estado del auto.
- **Audio**
  - Pestañas Bluetooth, Radio FM, Apps de música y USB. Toque largo en una pestaña cambia su app.
  - Volumen, ecualizador, progreso tocable (si la app lo permite), datos del teléfono conectado y otras fuentes que estén sonando.
- **Auto (mantenimiento)**
  - Holograma del auto visto desde arriba.
  - **Un toque** elige la pieza: el visor se desliza en línea recta desde la pieza anterior y la resalta, sin zoom ni cortes. **Otro toque** (o toque largo) abre el editor.
  - Por km:
    - «Lo cambié hoy»;
    - «Próximo cambio a…» (lo que dice el sticker del taller);
    - intervalo (los sugeridos u otro);
    - borrar, si es un ítem propio.
  - Por fecha: elegir, quitar o borrar.
  - El **+** agrega ítems propios, por km o por fecha.
  - Al abrir el launcher, el auto de la tarjeta del inicio hace la animación de arranque: dibuja el contorno, lo escanea y revisa cada pieza en verde o rojo. La primera vez que se entra a esta pantalla también la hace.
- **Apps**
  - Bluetooth y WiFi (abren los ajustes, porque Android 10 no deja prenderlos desde otra app).
  - Brillo y volumen.
  - Modo noche: automático por la puesta del sol, Noche o Día.
  - Límite de velocidad.
  - Los 4 accesos de la barra y todas las apps con buscador. Toque largo en una app la asigna a un botón.

## Límites conocidos

- **Radio FM**: Android no tiene un sistema estándar para sintonizar. La sintonía la hace la app de radio de la pantalla.
  - Desde acá: buscar emisora (◀◀ ▶▶), play/pausa y abrir la app.
  - La frecuencia del dial se lee de lo que informa esa app. Si no informa nada, se ve `--.-`.
- **Bluetooth**: muchas radios usan su propio Bluetooth (app `com.tw.bt` o similar) que Android no ve. En ese caso la tarjeta dice "Bluetooth de la radio" y los botones de música se mandan a esa app.
  - Si play o siguiente no responden: Ajustes › Audio › *Modo de los botones*. Son los mismos 6 modos del Car Launcher 3; probá uno por uno.
- El mapa necesita internet la primera vez que se ve cada zona.

## Estructura

```
lib/
  main.dart                   arranque, tema día/noche, escala a 1024×600
  core/native.dart            llamadas a Android
  core/theme.dart             colores y textos
  data/                       estado, mantenimiento, ajustes, clima, sol
  ui/shell.dart               barra lateral y pestañas
  ui/pages/                   inicio, audio, mantenimiento, apps, ajustes
  ui/widgets/holo_car.dart    holograma del auto (animación continua)
android/app/src/main/kotlin/  GPS, música, navegación, Bluetooth, volumen, brillo
```
