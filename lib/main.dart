import 'dart:async';
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
          seedColor: const Color(0xFF00BCD4),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF04121F),
      ),
      home: const EjectScreen(),
    );
  }
}

class EjectScreen extends StatefulWidget {
  const EjectScreen({super.key});

  @override
  State<EjectScreen> createState() => _EjectScreenState();
}

class _EjectScreenState extends State<EjectScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _tickTimer;

  bool _isPlaying = false;
  double _progress = 0;
  late AnimationController _bubbles;

  static const int _sampleRate = 44100;
  static const int _durationSeconds = 30;

  @override
  void initState() {
    super.initState();
    _bubbles = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _bubbles.dispose();
    _player.dispose();
    super.dispose();
  }

  /// Genera los bytes WAV con el tono de expulsión de agua:
  /// barrido sinusoidal (165–180 Hz) con envolvente y ruido leve.
  /// Devuelve el WAV completo (cabecera + PCM) una única vez,
  /// sin duplicar los datos.
  Uint8List generateTone() {
    const int sampleRate = _sampleRate;
    const int durationSec = _durationSeconds;
    final int numSamples = sampleRate * durationSec;

    final Uint8List pcm = Uint8List(numSamples * 2);
    final ByteData data = ByteData.view(pcm.buffer);
    final Random random = Random(42);

    double phase = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double progress = (t % 3) / 3.0;
      final double freq = 165.0 + 15.0 * sin(2 * pi * progress);
      phase += 2 * pi * freq / sampleRate;

      final double envelope = min(1.0, min(t / 0.1, (durationSec - t) / 0.5));
      final double breath = 0.75 + 0.25 * sin(2 * pi * t / 3.0 - pi / 2);
      final double noise = (random.nextDouble() - 0.5) * 0.04;

      final double value =
          (sin(phase) * breath + noise) * envelope * 0.85;
      final int sample = (value * 32767).round().clamp(-32768, 32767);
      data.setInt16(i * 2, sample, Endian.little);
    }

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
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    header.setUint32(40, dataSize, Endian.little);

    wav.setRange(headerSize, wav.length, pcm);
    return wav;
  }

  Future<void> _toggleEject() async {
    if (_isPlaying) {
      _tickTimer?.cancel();
      _stopwatch.stop();
      await _player.stop();
      setState(() {
        _isPlaying = false;
        _progress = 0;
      });
      return;
    }

    setState(() {
      _isPlaying = true;
      _progress = 0;
      _stopwatch
        ..reset()
        ..start();
    });

    _tickTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {
        _progress = _stopwatch.elapsed.inMilliseconds /
            (_durationSeconds * 1000);
        if (_progress >= 1) {
          _progress = 1;
          _isPlaying = false;
          _tickTimer?.cancel();
          _stopwatch.stop();
        }
      });
    });

    final Uint8List wav = generateTone();
    await _player.play(BytesSource(wav));
  }

  int get _secondsLeft {
    final int left =
        _durationSeconds - (_progress * _durationSeconds).round();
    return left.clamp(0, _durationSeconds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo degradado
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF04121F),
                  Color(0xFF06263D),
                  Color(0xFF04121F),
                ],
              ),
            ),
            child: SizedBox.expand(),
          ),
          // Burbujas animadas de fondo
          AnimatedBuilder(
            animation: _bubbles,
            builder: (context, _) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _BubblesPainter(progress: _bubbles.value),
            ),
          ),
          // Contenido
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    children: [
                      const Icon(Icons.water_drop,
                          color: Color(0xFF00E5FF), size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'WATER EJECT',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Expulsa el agua de tu altavoz',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Botón circular con anillo de progreso y cuenta regresiva
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CircularProgressIndicator(
                        value: _progress == 0 ? null : _progress,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        color: const Color(0xFF00E5FF),
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    _GlowButton(
                      isPlaying: _isPlaying,
                      onTap: _toggleEject,
                    ),
                    if (_isPlaying)
                      Positioned(
                        bottom: -12,
                        child: Text(
                          '$_secondsLeft s',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                // Tarjeta de instrucciones
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      _InstructionRow(
                        index: '1',
                        text: 'Sube el volumen al máximo',
                      ),
                      _InstructionRow(
                        index: '2',
                        text: 'Pulsa el botón y espera 30 segundos',
                      ),
                      _InstructionRow(
                        index: '3',
                        text: 'Seca el exterior con un paño suave',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.35)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Las frecuencias no garantizan eliminar toda el '
                              'agua. Usa volumen moderado.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón central con efecto de brillo y gota.
class _GlowButton extends StatelessWidget {
  const _GlowButton({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPlaying
                ? [const Color(0xFFFF6B6B), const Color(0xFFC0392B)]
                : [const Color(0xFF00BCD4), const Color(0xFF00688B)],
          ),
          boxShadow: [
            BoxShadow(
              color: isPlaying
                  ? Colors.red.withValues(alpha: 0.4)
                  : const Color(0xFF00E5FF).withValues(alpha: 0.4),
              blurRadius: 40,
              spreadRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 70,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Fila de instrucciones numerada.
class _InstructionRow extends StatelessWidget {
  const _InstructionRow({required this.index, required this.text});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
            ),
            child: Text(
              index,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Burbujas ascendentes de fondo.
class _BubblesPainter extends CustomPainter {
  _BubblesPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(7);
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    for (int i = 0; i < 14; i++) {
      final double baseX = random.nextDouble() * size.width;
      final double radius = 4 + random.nextDouble() * 10;
      final double speed = 0.35 + random.nextDouble() * 0.5;
      final double yOffset = ((progress * speed + i * 0.11) % 1.0) *
          (size.height + 80) -
          40;
      paint.color =
          const Color(0xFF00E5FF).withValues(alpha: 0.05 + (i % 3) * 0.02);
      canvas.drawCircle(Offset(baseX, size.height - yOffset), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
