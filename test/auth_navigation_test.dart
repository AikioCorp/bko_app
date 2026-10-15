import 'package:flutter_test/flutter_test.dart';
import 'package:bko_app/core/routing/auth_navigation.dart';

void main() {
  group('sanitizeRedirect', () {
    test('rejects external URLs and open redirects', () {
      expect(sanitizeRedirect('https://evil.com'), '');
      expect(sanitizeRedirect('//evil.com/hack'), '');
      expect(sanitizeRedirect('javascript:alert(1)'), '');
      expect(sanitizeRedirect('\\evil.com'), '');
      expect(sanitizeRedirect(null), '');
      expect(sanitizeRedirect('   '), '');
    });

    test('rejects infinite redirect loops', () {
      expect(sanitizeRedirect('/login'), '');
      expect(sanitizeRedirect('/login?tab=register'), '');
      expect(sanitizeRedirect('/register'), '');
      expect(sanitizeRedirect('/verify-otp'), '');
      expect(sanitizeRedirect('/suspended'), '');
      expect(sanitizeRedirect('/taste-onboarding'), '');
    });

    test('preserves valid internal paths', () {
      expect(sanitizeRedirect('/podcasts/mali-culture'), '/podcasts/mali-culture');
      expect(sanitizeRedirect('/library?tab=saved'), '/library?tab=saved');
      expect(sanitizeRedirect('/explore'), '/explore');
    });
  });

  group('resolvePostAuthDecision', () {
    test('suspension has absolute priority over onboarding and redirects', () {
      final user = {
        'id': 'u1',
        'isSuspended': true,
        'isNewUser': true,
        'onboardingCompleted': false,
      };
      final decision = resolvePostAuthDecision(user, explicitTarget: '/podcasts/super');
      expect(decision.isSuspended, true);
      expect(decision.path, '/suspended');
      expect(decision.needsOnboarding, false);
    });

    test('new user without onboarding is sent to /taste-onboarding with clean redirect', () {
      final user = {
        'id': 'u2',
        'isNewUser': true,
        'onboardingCompleted': false,
        'onboardingState': 'NOT_PROMPTED',
      };
      final decision = resolvePostAuthDecision(user, explicitTarget: '/podcasts/test');
      expect(decision.needsOnboarding, true);
      expect(decision.path, '/taste-onboarding?redirect=%2Fpodcasts%2Ftest');
    });

    test('existing user with incomplete onboarding is sent to /taste-onboarding', () {
      final user = {
        'id': 'u3',
        'isNewUser': false,
        'onboardingCompleted': false,
        'onboardingState': 'NOT_PROMPTED',
      };
      final decision = resolvePostAuthDecision(user);
      expect(decision.needsOnboarding, true);
      expect(decision.path, '/taste-onboarding');
    });

    test('user who dismissed onboarding is NOT forced into /taste-onboarding', () {
      final user = {
        'id': 'u4',
        'isNewUser': false,
        'onboardingCompleted': false,
        'onboardingState': 'DISMISSED',
      };
      final decision = resolvePostAuthDecision(user, explicitTarget: '/explore');
      expect(decision.needsOnboarding, false);
      expect(decision.path, '/explore');
    });

    test('user with completed onboarding goes to explicit target or default route', () {
      final auditor = {
        'id': 'u5',
        'roles': ['USER'],
        'onboardingCompleted': true,
      };
      expect(resolvePostAuthDecision(auditor).path, '/');
      expect(resolvePostAuthDecision(auditor, explicitTarget: '/library').path, '/library');

      final creator = {
        'id': 'u6',
        'roles': ['CREATOR'],
        'onboardingCompleted': true,
      };
      expect(resolvePostAuthDecision(creator).path, '/studio');
    });
  });

  group('shouldShowCatchUpInvitation', () {
    test('returns false for null, unauthenticated or suspended user', () {
      expect(shouldShowCatchUpInvitation(null), false);
      expect(shouldShowCatchUpInvitation({}), false);
      expect(shouldShowCatchUpInvitation({'id': 'u', 'isSuspended': true}), false);
    });

    test('returns false when onboarding is already completed', () {
      final user = {
        'id': 'u',
        'onboardingCompleted': true,
        'onboardingState': 'COMPLETED',
      };
      expect(shouldShowCatchUpInvitation(user), false);
    });

    test('returns false when onboardingState is PROMPTED or DISMISSED', () {
      expect(shouldShowCatchUpInvitation({'id': 'u', 'onboardingState': 'PROMPTED'}), false);
      expect(shouldShowCatchUpInvitation({'id': 'u', 'onboardingState': 'DISMISSED'}), false);
    });

    test('returns true for existing account with NOT_PROMPTED and missing preferences', () {
      final user = {
        'id': 'u',
        'onboardingCompleted': false,
        'onboardingState': 'NOT_PROMPTED',
        'hasPreferences': false,
        'languagePreferences': [],
        'topicPreferences': [],
      };
      expect(shouldShowCatchUpInvitation(user), true);
    });
  });
}
