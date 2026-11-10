import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    _initialized = true;
  }

  /// 播放单词音频 [id] 是词库中的 id (1-based)
  Future<void> play(int id) async {
    await init();
    final assetPath = 'audio/${id.toString().padLeft(5, '0')}.mp3';
    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      // 忽略播放错误，不影响主流程
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    _initialized = false;
  }
}