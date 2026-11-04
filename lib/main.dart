import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'data/app_state.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La radio tiene 1,4 GB de RAM: menos memoria para imágenes (calles del mapa, íconos)
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 48 << 20
    ..maximumSize = 400;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  debugPrint('CL4 arranque');
  try {
    await App.i.init().timeout(const Duration(seconds: 12));
  } catch (e, st) {
    debugPrint('CL4 init: $e\n$st');
  }
  debugPrint('CL4 init listo');
  runApp(const CarLauncherApp());
}

class CarLauncherApp extends StatelessWidget {
  const CarLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: App.i.night,
      builder: (_, night, __) {
        final pal = night ? Pal.night : Pal.day;
        return MaterialApp(
          title: 'Car Launcher 4',
          debugShowCheckedModeBanner: false,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(
            useMaterial3: true,
            brightness: night ? Brightness.dark : Brightness.light,
            fontFamily: 'Barlow',
            scaffoldBackgroundColor: pal.ground,
            colorScheme: ColorScheme.fromSeed(
              seedColor: pal.accent,
              brightness: night ? Brightness.dark : Brightness.light,
              primary: pal.accent,
              onPrimary: pal.onAccent,
              surface: pal.panelSolid,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: pal.panelSolid,
              headerBackgroundColor: pal.accent,
              headerForegroundColor: pal.onAccent,
            ),
          ),
          builder: (context, child) {
            // Todo se diseña para 600 de alto (pantalla 1024×600); en otras pantallas se escala igual.
            final mq = MediaQuery.of(context);
            final s = mq.size.height <= 0 ? 1.0 : mq.size.height / 600;
            final design = Size(mq.size.width / s, 600);
            return PalScope(
              pal: pal,
              child: FittedBox(
                fit: BoxFit.fill,
                alignment: Alignment.topLeft,
                child: SizedBox.fromSize(
                  size: design,
                  child: MediaQuery(
                    data: mq.copyWith(
                      size: design,
                      devicePixelRatio: mq.devicePixelRatio * s,
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: mq.viewInsets / s,
                      textScaler: TextScaler.noScaling,
                    ),
                    child: child!,
                  ),
                ),
              ),
            );
          },
          home: const Shell(),
        );
      },
    );
  }
}
