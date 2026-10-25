import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/judge_access.dart';
import '../theme/colors.dart';

/// "Judging BakeOut?": one click into a ready-made profile, or a fresh account that starts sign-up
/// from the first question. Once signed in it says which account is open and offers a switch.
class JudgePanel extends StatelessWidget {
  const JudgePanel({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: JudgeAccess.ready,
    builder: (context, ready, _) => ready
        ? const _JudgeOptions()
        : const _Card(child: _Header(subtitle: 'Getting the kitchen ready…')),
  );
}

/// Opens [JudgePanel] in a sheet, for windows too narrow to show it beside the phone.
Future<void> showJudgeSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: BakeColors.warmCream,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => const Padding(
    padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
    child: JudgePanel(),
  ),
);

class _JudgeOptions extends StatefulWidget {
  const _JudgeOptions();

  @override
  State<_JudgeOptions> createState() => _JudgeOptionsState();
}

class _JudgeOptionsState extends State<_JudgeOptions> {
  final _auth = AuthService();

  /// What's in progress: a ready-made email, 'fresh', or 'switch'.
  String? _busy;
  String? _error;

  Future<void> _run(String what, Future<void> Function() action) async {
    setState(() {
      _busy = what;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _auth.changes,
    initialData: _auth.currentUser,
    builder: (context, snap) {
      final user = snap.data;
      return _Card(
        key: const Key('judge-panel'),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: user == null ? _signedOut(context) : _signedIn(context, user),
        ),
      );
    },
  );

  Widget _signedOut(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(subtitle: 'Skip the sign-up. One click and you’re in.'),
        const SizedBox(height: 14),
        Text(
          'READY-MADE PROFILE',
          style: text.labelSmall?.copyWith(
            color: BakeColors.muted,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        for (final account in JudgeAccess.readyMade)
          _AccountTile(
            account: account,
            busy: _busy == account.email,
            enabled: _busy == null,
            onTap: () =>
                _run(account.email, () => JudgeAccess.logInAs(account, _auth)),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('judge-fresh'),
          onPressed: _busy == null
              ? () => _run('fresh', () => JudgeAccess.startFresh(_auth))
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: BakeColors.deepCherry,
            side: const BorderSide(color: BakeColors.cherryRed, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _busy == 'fresh'
              ? const _Spinner()
              : const Text('✨', style: TextStyle(fontSize: 16)),
          label: const Text(
            'Start fresh: build a profile from scratch',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (_error != null) _ErrorLine(_error!),
        const SizedBox(height: 10),
        Text(
          'Tip: open Maya here and Arjun in a private window to chat as both of them.',
          style: text.bodySmall?.copyWith(color: BakeColors.muted),
        ),
      ],
    );
  }

  Widget _signedIn(BuildContext context, User user) {
    final text = Theme.of(context).textTheme;
    final readyMade = JudgeAccess.readyMadeFor(user.email);
    final fresh = JudgeAccess.isFreshJudge(user.email);
    final who = readyMade != null
        ? 'You’re in as ${readyMade.name}, a ready-made profile.'
        : fresh
        ? 'You’re in with a fresh account. Sign-up starts from the very first question.'
        : 'You’re in as ${user.email ?? 'your own account'}.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(subtitle: 'Enjoy BakeOut!'),
        const SizedBox(height: 12),
        Row(
          children: [
            if (readyMade != null) ...[
              _Avatar(readyMade.cherry),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                who,
                key: const Key('judge-signed-in'),
                style: text.bodyMedium?.copyWith(
                  color: BakeColors.charcoal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('judge-switch'),
          onPressed: _busy == null
              ? () => _run('switch', () => JudgeAccess.signOut(_auth))
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: BakeColors.deepCherry,
            side: const BorderSide(color: BakeColors.line, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _busy == 'switch'
              ? const _Spinner()
              : const Text(
                  'Switch profile',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
        if (fresh)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Switching ends this fresh account; you can always start another.',
              style: text.bodySmall?.copyWith(color: BakeColors.muted),
            ),
          ),
        if (_error != null) _ErrorLine(_error!),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: BakeColors.cherryRed.withValues(alpha: 0.25),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: BakeColors.deepCherry.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: BakeColors.softPink,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            '🏆 Judging BakeOut?',
            style: TextStyle(
              color: BakeColors.deepCherry,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: text.titleMedium?.copyWith(color: BakeColors.charcoal),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final JudgeAccount account;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wingman = account.cherry == 'girl' ? 'Jill' : 'Jack';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: BakeColors.warmCream,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('judge-login-${account.name.toLowerCase()}'),
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            child: Row(
              children: [
                _Avatar(account.cherry),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Log in as ${account.name}',
                        style: text.titleSmall?.copyWith(
                          color: BakeColors.deepCherry,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$wingman is the wingman · ${account.summary}',
                        style: text.bodySmall?.copyWith(
                          color: BakeColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                busy
                    ? const _Spinner()
                    : const Icon(
                        Icons.arrow_forward_rounded,
                        color: BakeColors.cherryRed,
                        size: 20,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.cherry);

  final String cherry;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    padding: const EdgeInsets.all(3),
    child: Image.asset(
      'assets/mascots/${cherry == 'girl' ? 'jill' : 'jack'}_smile.png',
      fit: BoxFit.contain,
    ),
  );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(
      strokeWidth: 2.2,
      color: BakeColors.cherryRed,
    ),
  );
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      message,
      key: const Key('judge-error'),
      style: const TextStyle(
        color: BakeColors.deepCherry,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
