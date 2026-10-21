import 'dart:io';

import 'package:bakeout/services/face_math.dart';
import 'package:bakeout/services/verification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs the real on-device pipeline (Apple Vision + MobileFaceNet) on public-domain
/// official portraits from Wikimedia Commons.
const _portraits = {
  'obama_a': 'President_Barack_Obama.jpg',
  'obama_b': 'Official_portrait_of_Barack_Obama.jpg',
  'biden_a': 'Joe_Biden_presidential_portrait.jpg',
  'biden_b': 'Official_portrait_of_Vice_President_Joe_Biden.jpg',
  'harris_a': 'Kamala_Harris_Vice_Presidential_Portrait.jpg',
};

Future<Map<String, String>> _download() async {
  final dir = await Directory('${Directory.systemTemp.path}/bakeout_faces').create(recursive: true);
  final client = HttpClient()..userAgent = 'BakeOutTest/1.0 (hackathon)';
  final paths = <String, String>{};
  for (final entry in _portraits.entries) {
    final file = File('${dir.path}/${entry.key}.jpg');
    if (!await file.exists()) {
      final uri = Uri.parse('https://commons.wikimedia.org/wiki/Special:FilePath/${entry.value}?width=800');
      final response = await (await client.getUrl(uri)).close();
      await response.pipe(file.openWrite());
    }
    paths[entry.key] = file.path;
  }
  client.close();
  return paths;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('same person scores above the cutoff, different people below', (tester) async {
    final photos = await _download();
    final service = VerificationService();
    final names = photos.keys.toList();
    final report = StringBuffer('\n');
    final wrong = <String>[];

    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        final a = names[i], b = names[j];
        final same = a.split('_').first == b.split('_').first;
        final result = await service.compare(profilePhotoPath: photos[a]!, selfiePath: photos[b]!);
        expect(result.problem, isNull, reason: '$a vs $b: ${result.problem}');
        report.writeln('${same ? 'SAME' : 'diff'}  $a vs $b  ${result.similarity!.toStringAsFixed(3)}');
        if (result.matched != same) wrong.add('$a vs $b');
      }
    }
    // ignore: avoid_print
    print(report);
    service.dispose();
    expect(wrong, isEmpty, reason: 'Misjudged pairs (cutoff $faceMatchThreshold)');
  });
}
