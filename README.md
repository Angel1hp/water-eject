# Water Eject

App Android para expulsar agua del altavoz del teléfono mediante tonos de baja frecuencia (165–180 Hz), generada con **Flutter**.

## Descarga

Escanea el QR (`WaterEject_QR.png`) o descarga el APK directamente:

👉 [Descargar WaterEject.apk (v1.0.0)](https://github.com/Angel1hp/water-eject/releases/download/v1.0.0/WaterEject.apk)

> Al instalar, Android puede solicitar autorización para instalar apps desde el navegador.

## Funcionamiento

- Genera un tono WAV en tiempo real con `generateTone()` (Dart puro, sin assets).
- Barrido sinusoidal de 165–180 Hz con envolvente y ruido leve para vibrar las gotas de agua.
- Duración: 30 segundos por sesión.
- UI con animación de ondas concéntricas.

## Compilación

```bash
flutter pub get
flutter build apk --release
# APK: build\app\outputs\flutter-apk\app-release.apk
```

## ⚠️ Aviso

Las frecuencias de audio no garantizan eliminar el agua del dispositivo. Usa volumen moderado y no mantengas el altavoz al máximo por periodos prolongados.
