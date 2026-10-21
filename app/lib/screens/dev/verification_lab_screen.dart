import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/face_math.dart';
import '../../services/verification_service.dart';
import '../../theme/colors.dart';
import '../../widgets/mascot.dart';
import '../photos/live_check_view.dart';

/// DEV ONLY — slice 1's verification trial. Removed when real onboarding lands (slice 5).
class VerificationLabScreen extends StatefulWidget {
  const VerificationLabScreen({super.key});

  @override
  State<VerificationLabScreen> createState() => _VerificationLabScreenState();
}

class _VerificationLabScreenState extends State<VerificationLabScreen> {
  final _service = VerificationService();
  final _picker = ImagePicker();

  String? _photoA;
  String? _photoB;
  FaceMatchResult? _result;
  bool _working = false;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<String?> _pick() async => (await _picker.pickImage(source: ImageSource.gallery))?.path;

  Future<void> _compare(String profile, String other, {bool deleteOther = false}) async {
    setState(() {
      _working = true;
      _result = null;
    });
    try {
      final result = await _service.compare(profilePhotoPath: profile, selfiePath: other);
      setState(() => _result = result);
    } finally {
      if (deleteOther) await File(other).delete();
      setState(() => _working = false);
    }
  }

  Future<void> _startLiveCheck() async {
    final profile = _photoA;
    if (profile == null) return;
    final selfie = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Live check')),
          body: LiveCheckView(
            onCaptured: (path) => Navigator.of(context).pop(path),
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
    if (selfie != null) await _compare(profile, selfie, deleteOther: true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verification lab · dev only')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Center(child: Mascot(MascotPose.duoVerify, size: 180)),
          const SizedBox(height: 8),
          Text(
            'Pick a profile photo, then compare it with another photo or with a live selfie.',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: BakeColors.muted),
          ),
          const SizedBox(height: 20),
          _PhotoRow(
            label: 'Profile photo',
            path: _photoA,
            onPick: () async {
              final p = await _pick();
              if (p != null) setState(() => _photoA = p);
            },
          ),
          const SizedBox(height: 12),
          _PhotoRow(
            label: 'Second photo (optional)',
            path: _photoB,
            onPick: () async {
              final p = await _pick();
              if (p != null) setState(() => _photoB = p);
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _working || _photoA == null ? null : _startLiveCheck,
            child: const Text('Start live check'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _working || _photoA == null || _photoB == null ? null : () => _compare(_photoA!, _photoB!),
            child: const Text('Compare the two photos'),
          ),
          const SizedBox(height: 24),
          if (_working) const Center(child: CircularProgressIndicator(color: BakeColors.cherryRed)),
          if (_result != null) _ResultCard(result: _result!),
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.label, required this.path, required this.onPick});

  final String label;
  final String? path;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 52,
            height: 52,
            child: path == null
                ? const ColoredBox(color: BakeColors.softPink, child: Icon(Icons.person, color: BakeColors.cherryRed))
                : Image.file(File(path!), fit: BoxFit.cover),
          ),
        ),
        title: Text(label, style: Theme.of(context).textTheme.titleMedium),
        trailing: TextButton(onPressed: onPick, child: Text(path == null ? 'Choose' : 'Change')),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final FaceMatchResult result;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final problem = switch (result.problem) {
      FaceProblem.noFaceInPhoto => "We couldn't find a face in the profile photo.",
      FaceProblem.noFaceInSelfie => "We couldn't see one clear face in the selfie.",
      FaceProblem.severalFacesInSelfie => 'There was more than one face in the selfie.',
      FaceProblem.unreadableImage => "That image couldn't be read.",
      null => null,
    };
    final matched = result.matched;
    return Card(
      color: matched ? const Color(0xFFEEF4E6) : BakeColors.softPink,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Mascot(matched ? MascotPose.boyCheer : MascotPose.boyTryAgain, size: 90, bob: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(matched ? 'Match ✓' : 'No match', style: text.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    problem ??
                        'Similarity ${result.similarity!.toStringAsFixed(3)} '
                            '(cutoff ${faceMatchThreshold.toStringAsFixed(2)})',
                    style: text.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
