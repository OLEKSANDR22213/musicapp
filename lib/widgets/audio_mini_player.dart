import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio_controller.dart';
import '../screens/player_screen.dart';

class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioController>(builder: (context, a, _) {
      final t = a.currentTrack;
      if (t == null) return const SizedBox.shrink();

      return Material(
        elevation: 8,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlayerScreen()),
          ),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: t.artwork.isNotEmpty
                      ? Image.network(t.artwork, width: 48, height: 48, fit: BoxFit.cover)
                      : const Icon(Icons.album, size: 40),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(a.playing ? Icons.pause : Icons.play_arrow),
                  onPressed: () => a.playPause(),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => a.next(),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
