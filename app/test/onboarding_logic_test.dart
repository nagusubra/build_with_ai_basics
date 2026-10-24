import 'package:bakeout/models/profile.dart';
import 'package:bakeout/screens/onboarding_flow.dart';
import 'package:bakeout/screens/quiz/questions.dart';
import 'package:flutter_test/flutter_test.dart';

const _complete = {
  'cookingRelationship': 'I cook when I have time',
  'foodType': 'Vegetarian',
  'cuisines': ['Italian', 'Indian', 'Thai'],
  'topCuisines': ['Italian'],
  'signatureDish': 'Paneer butter masala',
  'idealDate': 'Trying a completely new recipe',
  'cookingPersonality': ['The experimental chef'],
  'cookingTime': 'Around an hour',
};

void main() {
  group('age', () {
    test('counts full years, birthday or not', () {
      expect(ageOn(DateTime(2000, 6, 15), DateTime(2026, 6, 14)), 25);
      expect(ageOn(DateTime(2000, 6, 15), DateTime(2026, 6, 15)), 26);
    });

    test('18+ only, from the 18th birthday', () {
      expect(isAdult(DateTime(2008, 10, 21), DateTime(2026, 10, 21)), isTrue);
      expect(isAdult(DateTime(2008, 10, 22), DateTime(2026, 10, 21)), isFalse);
    });
  });

  group('cherry by gender', () {
    test('men get the boy cherry, women the girl cherry', () {
      expect(cherryForGender('Man', coinFlip: false), 'boy');
      expect(cherryForGender('Woman', coinFlip: true), 'girl');
    });

    test('everyone else gets either, by coin flip', () {
      expect(cherryForGender('Non-binary', coinFlip: true), 'boy');
      expect(cherryForGender('Non-binary', coinFlip: false), 'girl');
    });
  });

  group('quiz gating', () {
    test('the required answers complete the quiz; optional ones can be skipped', () {
      expect(quizComplete(_complete), isTrue);
      expect(quizComplete({..._complete}..remove('signatureDish')), isFalse);
    });

    test('"Other" food type needs what they typed', () {
      final q = quizQuestions.firstWhere((q) => q.field == 'foodType');
      expect(isAnswered(q, {'foodType': 'Other'}), isFalse);
      expect(isAnswered(q, {'foodType': 'Other', 'foodTypeOther': 'Jain'}), isTrue);
    });

    test('top three allows at most three and cooking personality at most two', () {
      final top = quizQuestions.firstWhere((q) => q.field == 'topCuisines');
      final style = quizQuestions.firstWhere((q) => q.field == 'cookingPersonality');
      expect(isAnswered(top, {'topCuisines': ['A', 'B', 'C', 'D']}), isFalse);
      expect(isAnswered(style, {'cookingPersonality': ['x', 'y', 'z']}), isFalse);
      expect(isAnswered(style, {'cookingPersonality': ['x', 'y']}), isTrue);
    });

    test('a returning person resumes at the first unanswered required card', () {
      expect(firstUnansweredIndex(const {}), 0);
      final noDish = {..._complete}..remove('signatureDish');
      expect(quizQuestions[firstUnansweredIndex(noDish)].field, 'signatureDish');
      expect(firstUnansweredIndex(_complete), quizQuestions.length);
    });
  });

  group('onboarding steps', () {
    const basics = {'name': 'Ana', 'age': 26, 'gender': 'Woman', 'lookingFor': 'partner'};

    test('walk basics → quiz → photos → verify → preview → Meet Cherry → done', () {
      UserProfile p(Map<String, dynamic> d) => UserProfile.fromMap('u', d);
      expect(nextStep(p({})), OnboardingStep.basics);
      expect(nextStep(p({...basics})), OnboardingStep.quiz);
      expect(nextStep(p({...basics, 'food': _complete})), OnboardingStep.quiz, reason: 'optional cards still ahead');
      final quizDone = {...basics, 'food': _complete, 'quizDone': true};
      expect(nextStep(p(quizDone)), OnboardingStep.photos);
      final photos = {...quizDone, 'photos': ['users/u/photos/1.jpg']};
      expect(nextStep(p(photos)), OnboardingStep.verify);
      expect(nextStep(p({...photos, 'verified': true})), OnboardingStep.preview);
      expect(nextStep(p({...photos, 'verified': true, 'previewSeen': true})), OnboardingStep.meetCherry);
      expect(nextStep(p({...photos, 'verified': true, 'previewSeen': true, 'onboardingComplete': true})), OnboardingStep.done);
    });

    test('verification is asked for, and moves on only when passed or skipped on purpose', () {
      final base = {...basics, 'food': _complete, 'quizDone': true, 'photos': ['x']};
      expect(nextStep(UserProfile.fromMap('u', {...base, 'previewSeen': true})), OnboardingStep.verify);
      expect(nextStep(UserProfile.fromMap('u', {...base, 'verificationSkipped': true})), OnboardingStep.preview);
    });
  });

  group('edit list summaries', () {
    QuizQuestion q(String field) => quizQuestions.firstWhere((q) => q.field == field);

    test('show the current answer, joined lists, slider levels, and typed "Other"', () {
      expect(answerSummary(q('cuisines'), {'cuisines': ['Italian', 'Thai']}, const {}), 'Italian, Thai');
      expect(answerSummary(q('adventure'), {'adventure': 8}, const {}), '8/10');
      expect(answerSummary(q('foodType'), {'foodType': 'Other', 'foodTypeOther': 'Jain'}, const {}), 'Jain');
      expect(answerSummary(q('musicGenres'), {'musicGenres': ['Lo-fi'], 'favouriteSong': 'Sunflower'}, const {}), 'Lo-fi · “Sunflower”');
    });

    test('a skipped optional answer reads as missing, so it can be added later', () {
      expect(answerSummary(q('comfortFood'), const {}, const {}), isNull);
      expect(answerSummary(q('prompts'), const {}, const {}), isNull);
      expect(answerSummary(q('prompts'), const {}, const {'winMeOverWith': 'Tiramisu'}), '1 of 3 answered');
    });
  });

  group('profile headline', () {
    test('comes from the first cooking personality', () {
      final p = UserProfile.fromMap('u', {
        'food': {'cookingPersonality': ['The experimental chef', 'The lazy chef']},
      });
      expect(profileHeadline(p), 'The experimental chef who measures everything with their heart');
    });

    test('has a warm fallback', () {
      expect(profileHeadline(const UserProfile(uid: 'u')), contains('Food lover'));
    });
  });
}
