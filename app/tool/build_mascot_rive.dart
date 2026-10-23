import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  final only = args
      .where((arg) => arg.startsWith('--only='))
      .map((arg) => arg.substring('--only='.length))
      .toSet();
  final appRoot = Directory.current;
  final repoRoot = appRoot.parent;
  final projectDir = Directory('${appRoot.path}/tool/mascot_rive');
  final assetDir = Directory('${projectDir.path}/assets');
  final poses = only.isEmpty
      ? mascotPoses
      : mascotPoses.where((pose) => only.contains(pose.artboard)).toList();

  if (poses.isEmpty) {
    stderr.writeln('No matching artboards. Use --only=DuoWelcome.');
    exitCode = 2;
    return;
  }

  assetDir.createSync(recursive: true);
  for (final pose in poses) {
    final source = File('${repoRoot.path}/design/mascots/${pose.source}.png');
    if (!source.existsSync()) {
      stderr.writeln('Missing source image: ${source.path}');
      exitCode = 1;
      return;
    }
    final resized = img.copyResize(
      img.decodeImage(source.readAsBytesSync())!,
      width: artboardSize,
      height: artboardSize,
      interpolation: img.Interpolation.average,
    );
    File('${assetDir.path}/${pose.source}.png')
        .writeAsBytesSync(img.encodePng(resized, level: 9));
    stdout.writeln('Resized ${pose.source}.png');
  }

  File('${projectDir.path}/scene.rml')
      .writeAsStringSync(buildScene(poses));
  stdout.writeln('Wrote scene.rml for ${poses.length} artboard(s)');

  final rive = riveExecutable();
  final verify = Process.runSync(
    rive,
    ['tool/mascot_rive', '--verify'],
    workingDirectory: appRoot.path,
  );
  stdout.write(verify.stdout);
  stderr.write(verify.stderr);
  if (verify.exitCode != 0) {
    exitCode = verify.exitCode;
    return;
  }

  final build = Process.runSync(
    rive,
    ['tool/mascot_rive', '--once'],
    workingDirectory: appRoot.path,
  );
  stdout.write(build.stdout);
  stderr.write(build.stderr);
  if (build.exitCode != 0) {
    exitCode = build.exitCode;
    return;
  }

  final built = File('${projectDir.path}/build/cherry_mascots.riv');
  if (!built.existsSync()) {
    stderr.writeln('Rive did not write ${built.path}');
    exitCode = 1;
    return;
  }
  final destination = File(
    '${appRoot.path}/assets/mascots/rive/cherry_mascots.riv',
  );
  destination.parent.createSync(recursive: true);
  built.copySync(destination.path);
  final size = destination.lengthSync();
  stdout.writeln(
    'Copied ${destination.path} (${(size / 1024).toStringAsFixed(0)} KB)',
  );
  if (size > 4 * 1024 * 1024) {
    stderr.writeln('The .riv is over 4 MB; reduce image detail before shipping.');
    exitCode = 1;
  }
}

const artboardSize = 768;

String riveExecutable() {
  final home = Platform.isWindows
      ? Platform.environment['USERPROFILE']
      : Platform.environment['HOME'];
  if (home != null) {
    final local = Platform.isWindows
        ? '$home\\.rive\\bin\\rive.exe'
        : '$home/.rive/bin/rive';
    if (File(local).existsSync()) return local;
  }
  return 'rive';
}

class MascotPose {
  const MascotPose({
    required this.artboard,
    required this.source,
    required this.pivotX,
    required this.pivotY,
    required this.duration,
    required this.sway,
    required this.scaleX,
    required this.scaleY,
    required this.lift,
    required this.sparkles,
  });

  final String artboard;
  final String source;
  final double pivotX;
  final double pivotY;
  final int duration;
  final double sway;
  final double scaleX;
  final double scaleY;
  final double lift;
  final List<Sparkle> sparkles;
}

class Sparkle {
  const Sparkle(this.x, this.y, this.phase, this.color);

  final double x;
  final double y;
  final double phase;
  final String color;
}

const mascotPoses = [
  MascotPose(
    artboard: 'DuoWelcome',
    source: 'cherry_duo_welcome',
    pivotX: 384,
    pivotY: 660,
    duration: 192,
    sway: 0.0087,
    scaleX: 1.006,
    scaleY: 1.012,
    lift: 4,
    sparkles: [
      Sparkle(72, 92, 0, 'FFFFD166'),
      Sparkle(700, 104, 0.33, 'FFFF8FA3'),
      Sparkle(420, 44, 0.66, 'FFFFD166'),
    ],
  ),
  MascotPose(
    artboard: 'DuoMatch',
    source: 'cherry_duo_match',
    pivotX: 384,
    pivotY: 670,
    duration: 180,
    sway: 0.007,
    scaleX: 1.005,
    scaleY: 1.010,
    lift: 3,
    sparkles: [
      Sparkle(90, 140, 0.1, 'FFFFD166'),
      Sparkle(690, 160, 0.45, 'FFFF8FA3'),
      Sparkle(384, 52, 0.75, 'FFFFD166'),
    ],
  ),
  MascotPose(
    artboard: 'DuoCooking',
    source: 'cherry_duo_cooking',
    pivotX: 384,
    pivotY: 680,
    duration: 204,
    sway: 0.006,
    scaleX: 1.005,
    scaleY: 1.010,
    lift: 3,
    sparkles: [
      Sparkle(62, 120, 0, 'FFFFD166'),
      Sparkle(710, 130, 0.4, 'FFFF8FA3'),
      Sparkle(704, 500, 0.72, 'FFFFD166'),
    ],
  ),
  MascotPose(
    artboard: 'BoyHello',
    source: 'cherry_boy_hello',
    pivotX: 384,
    pivotY: 690,
    duration: 168,
    sway: 0.010,
    scaleX: 1.005,
    scaleY: 1.011,
    lift: 4,
    sparkles: [
      Sparkle(660, 180, 0.08, 'FFFFD166'),
      Sparkle(700, 340, 0.4, 'FFFF8FA3'),
      Sparkle(248, 330, 0.7, 'FFFFD166'),
    ],
  ),
  MascotPose(
    artboard: 'GirlHello',
    source: 'cherry_girl_hello',
    pivotX: 384,
    pivotY: 690,
    duration: 168,
    sway: 0.010,
    scaleX: 1.005,
    scaleY: 1.011,
    lift: 4,
    sparkles: [
      Sparkle(150, 180, 0.08, 'FFFFD166'),
      Sparkle(680, 260, 0.4, 'FFFF8FA3'),
      Sparkle(624, 392, 0.7, 'FFFFD166'),
    ],
  ),
  MascotPose(
    artboard: 'BoyCheer',
    source: 'cherry_boy_cheer',
    pivotX: 384,
    pivotY: 650,
    duration: 120,
    sway: 0.017,
    scaleX: 1.012,
    scaleY: 1.022,
    lift: 7,
    sparkles: [
      Sparkle(100, 120, 0, 'FFFFD166'),
      Sparkle(690, 100, 0.3, 'FFFF8FA3'),
      Sparkle(300, 80, 0.65, 'FFFFD166'),
    ],
  ),
  MascotPose(
    artboard: 'GirlCheer',
    source: 'cherry_girl_cheer',
    pivotX: 384,
    pivotY: 650,
    duration: 120,
    sway: 0.017,
    scaleX: 1.012,
    scaleY: 1.022,
    lift: 7,
    sparkles: [
      Sparkle(110, 120, 0, 'FFFFD166'),
      Sparkle(700, 140, 0.3, 'FFFF8FA3'),
      Sparkle(620, 220, 0.65, 'FFFFD166'),
    ],
  ),
];

String buildScene(List<MascotPose> poses) {
  final out = StringBuffer()
    ..writeln('<Rive version="1" kind="fragment">');
  for (var i = 0; i < poses.length; i++) {
    final base = 1000 + i * 100;
    final pose = poses[i];
    out
      ..writeln(
        '  <ImageAsset file="assets/${pose.source}.png" '
        'name="${pose.source}" id="0:${base + 1}"/>',
      )
      ..writeln(
        '  <Artboard width="$artboardSize" height="$artboardSize" '
        'name="${pose.artboard}" defaultStateMachineId="0:${base + 20}" '
        'id="0:${base + 2}">',
      );
    out
      ..writeln(
        '    <Node x="${pose.pivotX}" y="${pose.pivotY}" '
        'name="${pose.artboard}Motion" id="0:${base + 10}">',
      )
      ..writeln(
        '      <Image x="-${pose.pivotX}" y="-${pose.pivotY}" '
        'originX="0" originY="0" assetId="0:${base + 1}" '
        'name="${pose.artboard}Image"/>',
      );
    for (var s = 0; s < pose.sparkles.length; s++) {
      writeSparkle(out, pose, base, s);
    }
    out
      ..writeln('    </Node>')
      ..writeln('    <LinearAnimation name="Idle" duration="${pose.duration}" '
          'loopValue="loop" id="0:${base + 22}">');
    writeBodyAnimation(out, pose, base);
    for (var s = 0; s < pose.sparkles.length; s++) {
      writeSparkleAnimation(out, pose, base, s);
    }
    out
      ..writeln('    </LinearAnimation>')
      ..writeln('    <StateMachine name="Idle" id="0:${base + 20}">')
      ..writeln('      <StateMachineLayer name="Layer 1" id="0:${base + 21}">')
      ..writeln('        <AnyState x="-200" y="-120"/>')
      ..writeln('        <ExitState x="400" y="-120"/>')
      ..writeln('        <EntryState>')
      ..writeln('          <StateTransition stateToId="0:${base + 23}"/>')
      ..writeln('        </EntryState>')
      ..writeln('        <AnimationState x="0" animationId="0:${base + 22}" '
          'id="0:${base + 23}"/>')
      ..writeln('      </StateMachineLayer>')
      ..writeln('    </StateMachine>')
      ..writeln('  </Artboard>');
  }
  out.writeln('</Rive>');
  return out.toString();
}

void writeSparkle(StringBuffer out, MascotPose pose, int base, int index) {
  final sparkle = pose.sparkles[index];
  out
    ..writeln(
      '      <Node x="${sparkle.x - pose.pivotX}" '
      'y="${sparkle.y - pose.pivotY}" '
      'name="Sparkle${index + 1}" id="0:${base + 31 + index}">',
    )
    ..writeln('        <Shape name="SparkleShape">')
    ..writeln('          <Star width="24" height="24" points="4" '
        'innerRadius="0.32" cornerRadius="3" originX="0.5" originY="0.5" '
        'name="Path"/>')
    ..writeln('          <Fill name="Fill">')
    ..writeln('            <SolidColor colorValue="${sparkle.color}" '
        'name="Color"/>')
    ..writeln('          </Fill>')
    ..writeln('        </Shape>')
    ..writeln('      </Node>');
}

void writeBodyAnimation(StringBuffer out, MascotPose pose, int base) {
  final d = pose.duration;
  final frames = [0, d ~/ 4, d ~/ 2, (d * 3) ~/ 4, d];
  writeDouble(out, 14, [
    RiveKey(0, pose.pivotY),
    RiveKey(frames[1], pose.pivotY - pose.lift),
    RiveKey(frames[2], pose.pivotY),
    RiveKey(frames[3], pose.pivotY - pose.lift * 0.45),
    RiveKey(frames[4], pose.pivotY),
  ], base + 10);
  writeDouble(out, 15, [
    RiveKey(0, 0),
    RiveKey(frames[1], pose.sway),
    RiveKey(frames[2], 0),
    RiveKey(frames[3], -pose.sway),
    RiveKey(frames[4], 0),
  ], base + 10);
  writeDouble(out, 16, [
    RiveKey(0, 1),
    RiveKey(frames[1], pose.scaleX),
    RiveKey(frames[2], 1),
    RiveKey(frames[3], 1 + (pose.scaleX - 1) * 0.4),
    RiveKey(frames[4], 1),
  ], base + 10);
  writeDouble(out, 17, [
    RiveKey(0, 1),
    RiveKey(frames[1], pose.scaleY),
    RiveKey(frames[2], 1),
    RiveKey(frames[3], 1 + (pose.scaleY - 1) * 0.4),
    RiveKey(frames[4], 1),
  ], base + 10);
}

void writeSparkleAnimation(
  StringBuffer out,
  MascotPose pose,
  int base,
  int index,
) {
  final d = pose.duration;
  final sparkle = pose.sparkles[index];
  final start = (sparkle.phase * d).round();
  final appear = start + 8;
  final fade = start + 36;
  final objectId = base + 31 + index;
  writeDouble(out, 18, [
    RiveKey(0, 0),
    RiveKey(start, 0),
    RiveKey(appear, 0.9),
    RiveKey(fade, 0),
    RiveKey(d, 0),
  ], objectId);
  writeDouble(out, 16, [
    RiveKey(0, 0.4),
    RiveKey(start, 0.4),
    RiveKey(appear, 1),
    RiveKey(fade, 0.4),
    RiveKey(d, 0.4),
  ], objectId);
  writeDouble(out, 17, [
    RiveKey(0, 0.4),
    RiveKey(start, 0.4),
    RiveKey(appear, 1),
    RiveKey(fade, 0.4),
    RiveKey(d, 0.4),
  ], objectId);
  writeDouble(out, 15, [
    RiveKey(0, 0),
    RiveKey(start, 0),
    RiveKey(appear, 0.3),
    RiveKey(fade, 0.5),
    RiveKey(d, 0.5),
  ], objectId);
}

class RiveKey {
  const RiveKey(this.frame, this.value);

  final int frame;
  final double value;
}

void writeDouble(
  StringBuffer out,
  int propertyKey,
  List<RiveKey> keys,
  int objectId,
) {
  final byFrame = <int, RiveKey>{};
  for (final key in keys) {
    byFrame[key.frame] = key;
  }
  final merged = byFrame.values.toList()
    ..sort((a, b) => a.frame.compareTo(b.frame));
  out
    ..writeln('      <KeyedObject objectId="0:$objectId">')
    ..writeln('        <KeyedProperty propertyKey="$propertyKey">');
  for (var i = 0; i < merged.length; i++) {
    final key = merged[i];
    final isLast = i == merged.length - 1;
    if (isLast) {
      out.writeln('          <KeyFrameDouble value="${key.value}" '
          'frame="${key.frame}" interpolationType="linear"/>');
    } else {
      out
        ..writeln('          <KeyFrameDouble value="${key.value}" '
            'frame="${key.frame}" interpolationType="cubic">')
        ..writeln('            <CubicEaseInterpolator x1="0.42" y1="0" '
            'x2="0.58" y2="1"/>')
        ..writeln('          </KeyFrameDouble>');
    }
  }
  out
    ..writeln('        </KeyedProperty>')
    ..writeln('      </KeyedObject>');
}
