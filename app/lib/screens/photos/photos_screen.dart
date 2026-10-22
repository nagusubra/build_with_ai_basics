import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../theme/colors.dart';
import '../../widgets/onboarding.dart';

/// One required photo, up to three more (`prd.md > Photos and Verification`).
class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key, required this.profile, required this.profiles, this.onDone});

  final UserProfile profile;
  final ProfileService profiles;
  final VoidCallback? onDone;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

/// A picked photo, kept as bytes so the same screen works on iOS, Android and the web.
class _Picked {
  _Picked(this.file, this.bytes);

  final XFile file;
  final Uint8List bytes;
}

class _PhotosScreenState extends State<PhotosScreen> {
  static const _max = 4;
  final _picker = ImagePicker();
  final _picked = <_Picked>[];
  bool _busy = false;
  String? _error;

  Future<void> _add() async {
    final files = await _picker.pickMultiImage(maxWidth: 1440, imageQuality: 85, limit: _max - _picked.length);
    if (files.isEmpty) return;
    final room = _max - _picked.length;
    final added = <_Picked>[];
    for (final file in files.take(room)) {
      added.add(_Picked(file, await file.readAsBytes()));
    }
    if (!mounted) return;
    setState(() => _picked.addAll(added));
  }

  void _remove(int i) => setState(() => _picked.removeAt(i));

  void _makeMain(int i) => setState(() => _picked.insert(0, _picked.removeAt(i)));

  Future<void> _upload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.profiles.uploadPhotos(widget.profile.uid, _picked.map((p) => p.file).toList());
      widget.onDone?.call();
    } catch (_) {
      if (mounted) setState(() => _error = 'Upload failed — check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingPage(
      title: 'Add your photos',
      subtitle: 'One is enough to start; add up to three more. Tap a photo to make it your main one.',
      progress: widget.onDone == null ? null : 0.75,
      onBack: Navigator.canPop(context) ? () => Navigator.pop(context) : null,
      action: FilledButton(
        key: const Key('photos-continue'),
        onPressed: _picked.isEmpty || _busy ? null : _upload,
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : const Text('Continue'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.8,
            children: [
              for (var i = 0; i < _picked.length; i++)
                GestureDetector(
                  onTap: () => _makeMain(i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(_picked[i].bytes, fit: BoxFit.cover),
                        if (i == 0)
                          const Positioned(
                            left: 8,
                            top: 8,
                            child: Chip(label: Text('Main'), backgroundColor: BakeColors.cherryRed, labelStyle: TextStyle(color: Colors.white)),
                          ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: IconButton.filledTonal(
                            onPressed: () => _remove(i),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_picked.length < _max)
                InkWell(
                  key: const Key('photos-add'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: _add,
                  child: Container(
                    decoration: BoxDecoration(
                      color: BakeColors.softPink,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: BakeColors.cherryRed.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: const Center(child: Icon(Icons.add_a_photo_outlined, size: 36, color: BakeColors.cherryRed)),
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: BakeColors.deepCherry)),
          ],
        ],
      ),
    );
  }
}
