import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlaylistService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  Future<String> createPlaylist(String title) async {
    final ref = await _db.collection('playlists').add({
      'title': title,
      'ownerUid': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'coverUrl': null,
    });
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myPlaylists() {
    return _db.collection('playlists')
        .where('ownerUid', isEqualTo: _uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Future<void> deletePlaylist(String playlistId) async {
    final tracks = await _db.collection('playlists/$playlistId/tracks').get();
    for (final d in tracks.docs) {
      await d.reference.delete();
    }
    await _db.doc('playlists/$playlistId').delete();
  }

  Future<void> addTrack({
    required String playlistId,
    required Map<String, dynamic> track,
  }) async {
    await _db.doc('playlists/$playlistId').update({'updatedAt': FieldValue.serverTimestamp()});
    await _db.collection('playlists/$playlistId/tracks').doc(track['id']).set({
      ...track,
      'addedAt': FieldValue.serverTimestamp(),
      'addedByUid': _uid,
    });
  }

  Future<void> removeTrack(String playlistId, String trackId) async {
    await _db.doc('playlists/$playlistId/tracks/$trackId').delete();
    await _db.doc('playlists/$playlistId').update({'updatedAt': FieldValue.serverTimestamp()});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> playlistTracks(String playlistId) {
    return _db.collection('playlists/$playlistId/tracks')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }
}
