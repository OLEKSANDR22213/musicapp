import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../main.dart' show AudiusApi, Track;
import '../widgets/audio_mini_player.dart';
import '../audio_controller.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});
  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  final _api = AudiusApi();

  bool _loading = true;
  String? _error;

  // title -> tracks
  final Map<String, List<Track>> _sections = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }

    setState(() {
      _loading = true;
      _error = null;
      _sections.clear();
    });

    try {
      // жанры пользователя из его плейлистов
      final genres = await _topGenresFromMyPlaylists(limit: 3);

      // общие тренды
      final trending = await _api.trendingTracks(limit: 20);
      _sections['🔥 Trending now'] = trending;

      // тренды по любимым жанрам
      final baseGenres = genres.isNotEmpty ? genres : ['Electronic', 'Hip-Hop', 'Chill'];
      for (final g in baseGenres) {
        final list = await _api.trendingTracks(genre: g, limit: 12);
        if (list.isNotEmpty) {
          _sections['🎧 $g'] = list;
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<String>> _topGenresFromMyPlaylists({int limit = 3}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final qs = await FirebaseFirestore.instance
        .collectionGroup('tracks')
        .where('addedByUid', isEqualTo: uid)
        .limit(200)
        .get();

    final counts = <String, int>{};
    for (final d in qs.docs) {
      final g = (d.data()['genre'] ?? '').toString().trim();
      if (g.isEmpty) continue;
      counts[g] = (counts[g] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    // слушаем глобальный плеер, чтобы подтягивать состояние (играет/пауза/текущий трек)
    final a = context.watch<AudioController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _sections.entries.map((e) {
          return _Section(
            title: e.key,
            tracks: e.value,
          );
        }).toList(),
      ),
      bottomNavigationBar: const AudioMiniPlayer(),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Track> tracks;

  const _Section({
    required this.title,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AudioController>();
    final currentId = a.currentTrack?.id;
    final isPlaying = a.playing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
              // кнопка "играть всю секцию"
              IconButton(
                tooltip: 'Играть все',
                icon: const Icon(Icons.play_circle),
                onPressed: () => context.read<AudioController>().playFromList(tracks, startIndex: 0),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final t = tracks[i];
              final playingThis = isPlaying && currentId == t.id;

              return SizedBox(
                width: 160,
                child: InkWell(
                  onTap: () {
                    final ctrl = context.read<AudioController>();
                    if (playingThis) {
                      ctrl.playPause();
                    } else {
                      ctrl.playFromList(tracks, startIndex: i);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: t.artwork.isNotEmpty
                              ? Image.network(
                            t.artwork,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12),
                          )
                              : const ColoredBox(color: Colors.black12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        t.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            playingThis ? Icons.pause_circle_filled : Icons.play_circle_fill,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(t.genre.isNotEmpty ? t.genre : ''),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
