import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:myapps_data/myapps_data.dart' show atomicWriteString;
import 'package:myapps_profile/myapps_profile.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../anime/services/anime_storage.dart';
import '../../../shared/services/image_service.dart';

/// App storage and synchronization facade over the shared repository.
class ProfileStore {
  /// Purpose: Prevent facade instantiation
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Public app API retained.
  const ProfileStore._();
  static const fileName = ProfileRepository.fileName;
  static const avatarSize = ProfileRepository.avatarSize;
  static final _repository = ProfileRepository(
    getAppDir: AnimeStorage.getAppDir,
    writeJson: atomicWriteString,
    onSaved: AutoSyncService.instance.notifySaved,
    imageResolver: ImageService.resolve,
    imageDeleter: ImageService.delete,
  );

  /// Purpose: Delegate load to the shared repository
  /// Inputs: None.
  /// Returns: `Future<ProfileData>`.
  /// Side effects: Reads or writes profile storage as appropriate.
  /// Notes: Public app API retained.
  static Future<ProfileData> load() => _repository.load();

  /// Purpose: Delegate update to the shared repository
  /// Inputs: ProfileData Function(ProfileData data) mutate.
  /// Returns: `Future<ProfileData>`.
  /// Side effects: Reads or writes profile storage as appropriate.
  /// Notes: Public app API retained.
  static Future<ProfileData> update(
    ProfileData Function(ProfileData data) mutate,
  ) => _repository.update(mutate);

  /// Purpose: Delegate setName to the shared repository
  /// Inputs: String name.
  /// Returns: `Future<ProfileData>`.
  /// Side effects: Reads or writes profile storage as appropriate.
  /// Notes: Public app API retained.
  static Future<ProfileData> setName(String name) => _repository.setName(name);

  /// Purpose: Delegate readAvatarBytes to the shared repository
  /// Inputs: None.
  /// Returns: `Future<Uint8List?>`.
  /// Side effects: Reads or writes profile storage as appropriate.
  /// Notes: Public app API retained.
  static Future<Uint8List?> readAvatarBytes() => _repository.readAvatarBytes();

  /// Purpose: Delegate setAvatarJpeg to the shared repository
  /// Inputs: Uint8List jpeg.
  /// Returns: `Future<ProfileData>`.
  /// Side effects: Reads or writes profile storage as appropriate.
  /// Notes: Public app API retained.
  static Future<ProfileData> setAvatarJpeg(Uint8List jpeg) =>
      _repository.setAvatarJpeg(jpeg);

  /// Purpose: Delegate removeAvatar to the shared repository
  /// Inputs: None.
  /// Returns: `Future<ProfileData>`.
  /// Side effects: Reads or writes profile storage as appropriate.
  /// Notes: Public app API retained.
  static Future<ProfileData> removeAvatar() => _repository.removeAvatar();

  /// Purpose: Delegate resolveImage to the shared repository
  /// Inputs: String relativePath.
  /// Returns: `Future<File>`.
  /// Side effects: Reads or writes profile storage as appropriate.
  /// Notes: Public app API retained.
  static Future<File> resolveImage(String relativePath) =>
      _repository.resolveImage(relativePath);

  /// Purpose: Let the user pick an image to edit into an avatar (1.7.2).
  /// Inputs: None.
  /// Returns: `Future<Uint8List?>` — the picked file's bytes, or null when
  /// the picker was cancelled.
  /// Side effects: Opens the file picker.
  /// Notes: Nothing is saved; the bytes go to the avatar editor, whose result
  /// is stored with [setAvatarJpeg].
  static Future<Uint8List?> pickAvatarSource() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    return picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
  }
}
