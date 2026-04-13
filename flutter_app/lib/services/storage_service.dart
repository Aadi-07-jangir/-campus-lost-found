import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  static const String _bucket = 'item-images';

  Future<String> uploadImage({required Uint8List fileBytes, required String fileName}) async {
    final path = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from(_bucket).uploadBinary(path, fileBytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return path;
  }

  String getImageUrl(String filePath) {
    return _client.storage.from(_bucket).getPublicUrl(filePath);
  }

  Future<Uint8List> getFileBytes(String filePath) async {
    return await _client.storage.from(_bucket).download(filePath);
  }

  Future<void> deleteFile(String filePath) async {
    await _client.storage.from(_bucket).remove([filePath]);
  }
}
