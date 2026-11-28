import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ids.dart';

enum PhotoSource { camera, gallery }

/// Takes or chooses a photo. Behind an interface so widget tests need no
/// camera.
abstract class PhotoPicker {
  /// A temporary file path, or null when the user cancelled.
  Future<String?> pick(PhotoSource source);
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<String?> pick(PhotoSource source) async {
    final x = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2400,
    );
    return x?.path;
  }
}

/// A picker that never returns anything (web demo, tests by default).
class NoPhotoPicker implements PhotoPicker {
  const NoPhotoPicker();
  @override
  Future<String?> pick(PhotoSource source) async => null;
}

/// Where photos live: a folder inside the app's private storage. Files are
/// copied in (never moved from the gallery, never uploaded) and deleted with
/// the item they belong to.
abstract class AttachmentStorage {
  Future<String> import(String sourcePath);
  Future<void> delete(Iterable<String> paths);

  /// The file's content as the user put it in (decrypted when the storage
  /// encrypts), or null when it is gone or this storage keeps nothing.
  Future<Uint8List?> read(String path);
}

class PrivateAttachmentStorage implements AttachmentStorage {
  PrivateAttachmentStorage({Future<Directory> Function()? root})
    : _root = root ?? _defaultRoot;
  final Future<Directory> Function() _root;

  static Future<Directory> _defaultRoot() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'attachments'));
  }

  @override
  Future<String> import(String sourcePath) async {
    final dir = await _root();
    await dir.create(recursive: true);
    final ext = p.extension(sourcePath).toLowerCase();
    final dest = p.join(dir.path, '${newId()}${ext.isEmpty ? '.jpg' : ext}');
    await File(sourcePath).copy(dest);
    return dest;
  }

  @override
  Future<Uint8List?> read(String path) async {
    if (path.startsWith('demo:')) return null;
    final f = File(path);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> delete(Iterable<String> paths) async {
    for (final path in paths) {
      if (path.startsWith('demo:')) continue;
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('Could not delete attachment: $e');
      }
    }
  }
}

/// Keeps nothing (demo data and the web build): the "copied" path is the
/// source path itself.
class MemoryAttachmentStorage implements AttachmentStorage {
  @override
  Future<String> import(String sourcePath) async => sourcePath;
  @override
  Future<void> delete(Iterable<String> paths) async {}
  @override
  Future<Uint8List?> read(String path) async => null;
}
