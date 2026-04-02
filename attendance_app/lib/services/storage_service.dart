import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a selfie captured during check-in.
  /// Returns the storage path (not a download URL) so it can be stored in Firestore.
  Future<String> uploadSelfie(String companyId, String uid, File file) async {
    final path = 'selfies/$companyId/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _storage.ref(path).putFile(file);
    return path;
  }

  /// Upload an avatar image for an employee profile.
  Future<String> uploadAvatar(String companyId, String uid, File file) async {
    final path = 'avatars/$companyId/$uid/avatar.jpg';
    await _storage.ref(path).putFile(file);
    return path;
  }

  /// Get a short-lived download URL from a storage path.
  Future<String> getDownloadUrl(String storagePath) async {
    return await _storage.ref(storagePath).getDownloadURL();
  }

  /// Delete a file from storage.
  Future<void> deleteFile(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
    } catch (_) {
      // Ignore if already deleted
    }
  }
}
