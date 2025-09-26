import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'main.dart' show AudiusApi, Track, APP_NAME;

class AudioController extends ChangeNotifier {
  final _player = AudioPlayer();
  final _api = AudiusApi();

  ConcatenatingAudioSource? _queueSource;
  final List<Track> _queue = [];

  List<Track> get queue => List.unmodifiable(_queue);
  int? get currentIndex => _player.currentIndex;
  Track? get currentTrack =>
      (currentIndex != null && currentIndex! < _queue.length)
          ? _queue[currentIndex!]
          : null;

  bool get playing => _player.playing;
  Stream<Duration?> get positionStream => _player.positionStream;
  Duration? get duration => _player.duration;

  AudioController() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.currentIndexStream.listen((_) => notifyListeners());
    _player.playerStateStream.listen((_) => notifyListeners());
  }

  Future<void> playFromList(List<Track> tracks, {int startIndex = 0}) async {
    final sources = <AudioSource>[];
    _queue
      ..clear()
      ..addAll(tracks);

    for (final t in tracks) {
      final url = await _api.streamUrl(t.id); // MP3
      sources.add(AudioSource.uri(Uri.parse(url), tag: t));
    }

    _queueSource = ConcatenatingAudioSource(children: sources);
    await _player.setAudioSource(_queueSource!, initialIndex: startIndex);
    await _player.play();
    notifyListeners();
  }

  Future<void> addToQueue(Track t) async {
    final url = await _api.streamUrl(t.id);
    final src = AudioSource.uri(Uri.parse(url), tag: t);
    if (_queueSource == null) {
      await playFromList([t], startIndex: 0);
      return;
    }
    await _queueSource!.add(src);
    _queue.add(t);
    notifyListeners();
  }

  Future<void> playPause() async => playing ? _player.pause() : _player.play();
  Future<void> next() async => _player.hasNext ? _player.seekToNext() : null;
  Future<void> previous() async => _player.hasPrevious ? _player.seekToPrevious() : null;
  Future<void> seek(Duration d) async => _player.seek(d);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
