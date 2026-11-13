import 'package:flutter_test/flutter_test.dart';
import 'package:water_eject/main.dart';

void main() {
  test('generateTone devuelve un WAV válido', () {
    final state = EjectScreenState();
    final wav = state.generateTone();
    expect(wav.length, greaterThan(1000));
    // Cabecera RIFF
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    // Formato WAVE
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
  });
}
