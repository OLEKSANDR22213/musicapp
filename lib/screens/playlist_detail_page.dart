import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../playlist_service.dart';
import '../widgets/audio_mini_player.dart';
import '../audio_controller.dart';
import '../main.dart' show Track;

class PlaylistDetailPage extends StatefulWidget {
  final String playlistId;
  final String title;
  const PlaylistDetailPage({super.key, required this.playlistId, required this.title});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final _svc = PlaylistService();

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AudioController>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _svc.playlistTracks(widget.playlistId),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('There are no tracks - add from the search'));
          }

          // Преобразуем документы в список Track
          final tracks = docs.map((d) {
            final m = d.data();
            return Track(
              id: (m['id'] ?? '').toString(),
              title: (m['title'] ?? '').toString(),
              artist: (m['artist'] ?? '').toString(),
              artwork: (m['artwork'] ?? '').toString(),
              duration: (m['duration'] is int)
                  ? m['duration'] as int
                  : int.tryParse('${m['duration'] ?? 0}') ?? 0,
              genre: (m['genre'] ?? '').toString(),
            );
          }).toList();

          return ListView.separated(
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = tracks[i];
              final isCurrent = a.currentTrack?.id == t.id;
              final isPlaying = isCurrent && a.playing;

              return ListTile(
                leading: t.artwork.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    t.artwork,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.album, size: 40),
                  ),
                )
                    : const Icon(Icons.album, size: 40),
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton.filledTonal(
                      tooltip: isPlaying ? 'Pause' : 'Play',
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        final ctrl = context.read<AudioController>();
                        if (isCurrent) {
                          ctrl.playPause();
                        } else {
                          ctrl.playFromList(tracks, startIndex: i);
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete track',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _svc.removeTrack(widget.playlistId, t.id),
                    ),
                  ],
                ),
                onTap: () {
                  final ctrl = context.read<AudioController>();
                  if (isCurrent) {
                    ctrl.playPause();
                  } else {
                    ctrl.playFromList(tracks, startIndex: i);
                  }
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: const AudioMiniPlayer(),
    );
  }
}
