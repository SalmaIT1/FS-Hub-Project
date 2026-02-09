import 'dart:async';

class AudioRecorderController {
  bool _recording = false;
  int _startTs = 0;
  final _progress = StreamController<double>.broadcast();
  Stream<double> get progress => _progress.stream;

  Future<void> start() async {
    _recording = true;
    _startTs = DateTime.now().millisecondsSinceEpoch;
    Timer.periodic(Duration(milliseconds: 200), (t) {
      if (!_recording) t.cancel();
      final elapsed = DateTime.now().millisecondsSinceEpoch - _startTs;
      _progress.add(elapsed / 1000.0);
    });
  }

  Future<String> stop() async {
    _recording = false;
    // returns path to file recorded (production: proper file path)
    return '/tmp/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
  }

  void cancel() {
    _recording = false;
  }
}
