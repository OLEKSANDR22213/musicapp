import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../playlist_service.dart';
import '../widgets/audio_mini_player.dart';
import '../audio_controller.dart';
import '../main.dart' show Track; // используем модель Track из main.dart
import 'playlist_detail_page.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});
  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  final _svc = PlaylistService();

  Future<void> _create() async {
    final titleCtrl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Новый плейлист'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(hintText: 'Например, Lofi Evening'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, titleCtrl.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await _svc.createPlaylist(title);
    }
  }

  /// Играть весь плейлист через глобальный AudioController
  Future<void> _playPlaylist(String playlistId) async {
    final snap = await FirebaseFirestore.instance
        .collection('playlists/$playlistId/tracks')
        .orderBy('addedAt', descending: false)
        .get();

    if (snap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('В плейлисте пока нет треков')),
        );
      }
      return;
    }

    final tracks = snap.docs.map((d) {
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

    // стартуем очередь
    final a = context.read<AudioController>();
    await a.playFromList(tracks, startIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои плейлисты')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _svc.myPlaylists(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('Плейлистов пока нет'));
          }

          final docs = snap.data!.docs;

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = docs[i];
              final title = p['title'] as String? ?? 'Без названия';
              final updated = (p['updatedAt'] as Timestamp?)
                  ?.toDate()
                  .toLocal()
                  .toString()
                  .split('.')
                  .first;

              return ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(title),
                subtitle: Text('обновлён: ${updated ?? "—"}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PlaylistDetailPage(playlistId: p.id, title: title),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Играть плейлист',
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => _playPlaylist(p.id),
                    ),
                    IconButton(
                      tooltip: 'Удалить плейлист',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Удалить плейлист?'),
                            content: const Text(
                                'Плейлист и его треки будут удалены.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        );
                        if (yes == true) await _svc.deletePlaylist(p.id);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      // мини-плеер всегда внизу
      bottomNavigationBar: const SafeArea(child: AudioMiniPlayer()),
    );
  }
}
