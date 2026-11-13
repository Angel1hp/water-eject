import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const WaterEjectApp());
}

class WaterEjectApp extends StatelessWidget {
  const WaterEjectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Eject',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
      ),
      home: const EjectScreen(),
    );
  }
}

/// Pantalla principal de Water Eject.
class EjectScreen extends StatefulWidget {
  const EjectScreen({super.key});

  @override
  State<EjectScreen> createState() => _EjectScreenState();
}

class _EjectScreenState extends State<EjectScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  String _status = 'Listo para expulsar el agua';
  late AnimationController _waveController;

  static const int _sampleRate = 44100;
  static const int _durationSeconds = 30;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (!_isPlaying) {
          _status = 'Secuencia finalizada';
          _waveController.stop();
        } else {
          _waveController.repeat();
        }
      });
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _player.dispose();
    super.dispose();
  }

  /// Genera los bytes WAV con el tono de expulsión de agua:
  /// barrido sinusoidal descendente (180 Hz -> 165 Hz) con variación
  /// de amplitud, similar al modo "Water Eject" de iOS.
  /// Devuelve el WAV completo (cabecera + PCM) una única vez,
  /// sin duplicar los datos.
  Uint8List generateTone() {
    const int sampleRate = _sampleRate;
    const int durationSec = _durationSeconds;
    final int numSamples = sampleRate * durationSec;

    // Datos PCM: 16 bits mono.
    final Uint8List pcm = Uint8List(numSamples * 2);

    final Double8 = ByteData.view(pcm.buffer);
    final Random random = Random(42);

    double phase = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;

      // Barrido de frecuencia: 180 Hz -> 165 Hz y de vuelta, en ciclos.
      final double progress = (t % 3) / 3.0; // ciclo de 3 segundos
      final double freq =
          165.0 + 15.0 * sin(2 * pi * progress); // 165-180 Hz

      phase += 2 * pi * freq / sampleRate;

      // Envolvente suave (evita clics al inicio/fin y respiración del tono).
      final double envelope = min(1.0, min(t / 0.1, (durationSec - t) / 0.5));
      final double breath =
          0.75 + 0.25 * sin(2 * pi * t / 3.0 - pi / 2);
      // Ruido leve para vibrar las gotas de agua.
      final double noise = (random.nextDouble() - 0.5) * 0.04;

      final double value =
          (sin(phase) * breath + noise) * envelope * 0.85;

      final int sample = (value * 32767).round().clamp(-32768, 32767);
      Double8.setInt16(i * 2, sample, Endian.little);
    }

    // Cabecera WAV de 44 bytes.
    const int headerSize = 44;
    final int dataSize = pcm.length;
    final Uint8List wav = Uint8List(headerSize + dataSize);
    final ByteData header = ByteData.view(wav.buffer);

    void writeStr(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        wav[offset + i] = s.codeUnitAt(i);
      }
    }

    writeStr(0, 'RIFF');
    header.setUint32(4, 36 + dataSize, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // tamaño del bloque fmt
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits por muestra
    writeStr(36, 'data');
    header.setUint32(40, dataSize, Endian.little);

    wav.setRange(headerSize, wav.length, pcm);
    return wav;
  }

  Future<void> _toggleEject() async {
    if (_isPlaying) {
      await _player.stop();
      setState(() => _status = 'Detenido');
      return;
    }
    setState(() => _status = 'Expulsando agua… sube el volumen al máximo');
    final Uint8List wav = generateTone();
    await _player.play(BytesSource(wav));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.surface, colors.surfaceContainerHighest],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              _WaveIcon(
                animation: _waveController,
                isPlaying: _isPlaying,
                color: colors.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Water Eject',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: FilledButton.icon(
                  onPressed: _toggleEject,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _isPlaying ? colors.error : colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 18),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  icon: Icon(_isPlaying ? Icons.stop : Icons.water_drop),
                  label:
                      Text(_isPlaying ? 'Detener' : 'Expulsar agua'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text(
                  'Consejo: volumen moderado. Las frecuencias no garantizan '
                  'eliminar toda el agua del altavoz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icono animado de ondas de agua.
class _WaveIcon extends StatelessWidget {
  const _WaveIcon({
    required this.animation,
    required this.isPlaying,
    required this.color,
  });

  final AnimationController animation;
  final bool isPlaying;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return SizedBox(
          width: 180,
          height: 180,
          child: CustomPaint(
            painter: _WavePainter(
              progress: isPlaying ? animation.value : 0,
              isPlaying: isPlaying,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.progress,
    required this.isPlaying,
    required this.color,
  });

  final double progress;
  final bool isPlaying;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;

    final Offset center = size.center(Offset.zero);

    // Gota central.
    final Paint dropPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final Path drop = Path()
      ..moveTo(center.dx, center.dy - 30)
      ..quadraticBezierTo(center.dx + 26, center.dy + 8, center.dx, center.dy + 26)
      ..quadraticBezierTo(center.dx - 26, center.dy + 8, center.dx, center.dy - 30);
    canvas.drawPath(drop, dropPaint);

    // Ondas concéntricas que se expanden cuando está sonando.
    const int waves = 3;
    for (int i = 0; i < waves; i++) {
      final double waveProgress = (progress + i / waves) % 1.0;
      final double radius = 35 + waveProgress * 45;
      final double opacity =
          isPlaying ? (1 - waveProgress) * 0.8 : 0.25;
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isPlaying != isPlaying;
}
