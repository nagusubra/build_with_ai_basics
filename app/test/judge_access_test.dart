import 'package:bakeout/services/judge_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the ready-made profiles are Maya with Jill and Arjun with Jack', () {
    expect(JudgeAccess.readyMadeFor('maya@bakeout.demo')?.cherry, 'girl');
    expect(JudgeAccess.readyMadeFor('arjun@bakeout.demo')?.cherry, 'boy');
    expect(JudgeAccess.readyMadeFor('someone@example.com'), isNull);
    expect(JudgeAccess.readyMadeFor(null), isNull);
  });

  test('fresh judge accounts are recognised by their domain only', () {
    expect(JudgeAccess.isFreshJudge('judge-ab12cd34@judge.bakeout.demo'), isTrue);
    expect(JudgeAccess.isFreshJudge('maya@bakeout.demo'), isFalse);
    expect(JudgeAccess.isFreshJudge('judge@example.com'), isFalse);
    expect(JudgeAccess.isFreshJudge(null), isFalse);
  });

  test('there is no tour request until a judge logs into a ready-made profile', () {
    expect(JudgeAccess.takeTourRequest(), isFalse);
  });
}
