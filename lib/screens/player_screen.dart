import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio_controller.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioController>(builder: (context, a, _) {
      final t = a.currentTrack;
      final dur = a.duration ?? Duration.zero;

      return Scaffold(
        appBar: AppBar(title: const Text('Currently playing')),
        body: t == null
            ? const Center(child: Text('The queue is empty'))
            : Column(
          children: [
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: t.artwork.isNotEmpty
                      ? Image.network(t.artwork, fit: BoxFit.cover)
                      : const ColoredBox(color: Colors.black12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: Theme.of(context).textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(t.artist, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<Duration?>(
              stream: a.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final value = dur.inMilliseconds == 0
                    ? 0.0
                    : pos.inMilliseconds / dur.inMilliseconds;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Slider(
                        value: value.clamp(0.0, 1.0),
                        onChanged: (v) {
                          if (dur.inMilliseconds > 0) {
                            a.seek(Duration(
                                milliseconds:
                                (dur.inMilliseconds * v).round()));
                          }
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(pos)),
                          Text(_fmt(dur)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(iconSize: 36, icon: const Icon(Icons.skip_previous), onPressed: () => a.previous()),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => a.playPause(),
                  icon: Icon(a.playing ? Icons.pause : Icons.play_arrow),
                  label: Text(a.playing ? 'Pause' : 'Play'),
                ),
                const SizedBox(width: 8),
                IconButton(iconSize: 36, icon: const Icon(Icons.skip_next), onPressed: () => a.next()),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: a.queue.length,
                itemBuilder: (context, i) {
                  final q = a.queue[i];
                  final isCur = a.currentIndex == i;
                  return ListTile(
                    leading: isCur ? const Icon(Icons.volume_up) : const SizedBox(width: 24),
                    title: Text(q.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(q.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => a.playFromList(a.queue, startIndex: i),
                  );
                },
              ),
            )
          ],
        ),
      );
    });
  }
}
