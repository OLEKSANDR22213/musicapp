import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:musicaplication/screens/recommendations_page.dart';
import 'package:musicaplication/widgets/audio_mini_player.dart';
import 'playlist_service.dart';
import 'screens/playlists_page.dart';
import 'package:provider/provider.dart';
import 'audio_controller.dart';



final _plSvc = PlaylistService();



const APP_NAME = "YourFlutterApp";
const HOST_DISCOVERY = "https://api.audius.co";


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAuth.instance.signInAnonymously();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AudioController(),
      child: const AudiusApp(),
    ),
  );
}

class AudiusApp extends StatelessWidget {
  const AudiusApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audius Search Player',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: const SearchPage(),
    );
  }
}

class Track {
  final String id;
  final String title;
  final String artist;
  final String artwork;
  final int duration;
  final String genre;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.artwork,
    required this.duration,
    required this.genre,
  });

  factory Track.fromJson(Map<String, dynamic> j) {
    String img = '';
    final art = j['artwork'];
    if (art is Map && art.isNotEmpty) img = (art.values.first ?? '').toString();

    return Track(
      id: j['id'].toString(),
      title: (j['title'] ?? '').toString(),
      artist: (j['user']?['name'] ?? j['user']?['handle'] ?? '').toString(),
      artwork: img,
      duration: int.tryParse('${j['duration'] ?? 0}') ?? 0,
      genre: (j['genre'] ?? '').toString(), // <—
    );
  }
}


class AudiusApi {
  String? _base;

  Future<String> _baseUrl() async {
    if (_base != null) return _base!;
    final r = await http.get(Uri.parse(HOST_DISCOVERY));
    if (r.statusCode == 200) {
      final data = json.decode(r.body) as Map<String, dynamic>;
      final list = (data['data'] as List?)?.cast<String>() ?? [];
      if (list.isNotEmpty) {
        _base = list.first;
        return _base!;
      }
    }
    _base = "https://discoveryprovider.audius.co";
    return _base!;
  }

  Future<List<Track>> searchTracks(String query, {int limit = 25}) async {
    final host = await _baseUrl();
    final uri = Uri.parse(
      "$host/v1/tracks/search"
          "?query=${Uri.encodeQueryComponent(query)}"
          "&limit=$limit&offset=0&only_downloadable=false"
          "&app_name=$APP_NAME",
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }
    final obj = json.decode(res.body) as Map<String, dynamic>;
    final results = (obj['data'] as List?) ?? const [];
    return results.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
  }
  Future<List<Track>> trendingTracks({String? genre, String time = 'week', int limit = 20}) async {
    final host = await _baseUrl();
    final params = [
      if (genre != null && genre.isNotEmpty) 'genre=${Uri.encodeQueryComponent(genre)}',
      'time=$time', // 'day' | 'week' | 'month' | 'year'
      'limit=$limit',
      'app_name=$APP_NAME',
    ].join('&');
    final uri = Uri.parse('$host/v1/tracks/trending?$params');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final obj = json.decode(res.body) as Map<String, dynamic>;
    final results = (obj['data'] as List?) ?? const [];
    return results.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
  }


  Future<String> streamUrl(String trackId) async {
    final host = await _baseUrl();
    return "$host/v1/tracks/$trackId/stream?app_name=$APP_NAME";
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _api = AudiusApi();
  final _controller = TextEditingController(text: "lofi");

  List<Track> _tracks = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search(_controller.text);
  }

  Future<void> _pickPlaylistAndAdd(Track t) async {
    final snap = await _plSvc.myPlaylists().first;
    final items = snap.docs;

    final chosenId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: items.isEmpty
            ? const SizedBox(height: 140, child: Center(child: Text('Нет плейлистов. Создай в меню «Мои плейлисты».')))
            : ListView(
          shrinkWrap: true,
          children: items.map((d) {
            return ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(d['title'] ?? 'Без названия'),
              onTap: () => Navigator.pop(context, d.id),
            );
          }).toList(),
        ),
      ),
    );

    if (chosenId == null) return;

    await _plSvc.addTrack(playlistId: chosenId, track: {
      'id': t.id,
      'title': t.title,
      'artist': t.artist,
      'artwork': t.artwork,
      'duration': t.duration,
      'genre': t.genre,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавлено в плейлист')),
      );
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _api.searchTracks(q.trim(), limit: 30);
      setState(() => _tracks = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString();
    final ss = (s % 60).toString().padLeft(2, '0');
    return "$m:$ss";
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AudioController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audius Search Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaylistsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Рекомендации',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendationsPage())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Search for tracks',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: _search,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _search(_controller.text),
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: _tracks.isEmpty
                ? const Center(child: Text('Nothing found'))
                : ListView.separated(
              itemCount: _tracks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = _tracks[i];
                final isCurrent = a.currentTrack?.id == t.id;
                final isPlaying = isCurrent && a.playing;

                return ListTile(
                  leading: t.artwork.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      t.artwork, width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
                    ),
                  )
                      : const Icon(Icons.album, size: 40),
                  title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${t.artist} • ${_fmt(t.duration)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton.filledTonal(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: () {
                          final ctrl = context.read<AudioController>();
                          if (isCurrent) {
                            ctrl.playPause();
                          } else {
                            ctrl.playFromList(_tracks, startIndex: i);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.playlist_add),
                        onPressed: () => _pickPlaylistAndAdd(t),
                      ),
                    ],
                  ),
                  onTap: () {
                    final ctrl = context.read<AudioController>();
                    if (isCurrent) {
                      ctrl.playPause();
                    } else {
                      ctrl.playFromList(_tracks, startIndex: i);
                    }
                  },
                  onLongPress: () => _pickPlaylistAndAdd(t),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AudioMiniPlayer(),
    );
  }
}
