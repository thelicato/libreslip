import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/order_models.dart';

abstract interface class ItemImageStore {
  Future<String?> chooseAndStore();

  Future<void> remove(String path);
}

class LocalItemImageStore implements ItemImageStore {
  LocalItemImageStore({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> chooseAndStore() async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (selected == null) return null;
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'item_images'));
    await directory.create(recursive: true);
    final extension = p.extension(selected.path).toLowerCase();
    final safeExtension = {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)
        ? extension
        : '.jpg';
    final destination = p.join(directory.path, createLocalId() + safeExtension);
    await File(selected.path).copy(destination);
    return destination;
  }

  @override
  Future<void> remove(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
