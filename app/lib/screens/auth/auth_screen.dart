import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';
import '../../theme/colors.dart';
import '../../widgets/mascot.dart';
import '../../widgets/mascot_rive.dart';
import '../../widgets/onboarding.dart';

/// Email sign-up or log-in. The rest of sign-up (basics) follows once the account exists.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth, this.startWithLogIn = false});

  final AuthService auth;
  final bool startWithLogIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  late bool _logIn = widget.startWithLogIn;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _switchMode(bool logIn) {
    if (logIn == _logIn) return;
    setState(() {
      _logIn = logIn;
      _error = null;
    });
    _form.currentState?.reset();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_logIn) {
        await widget.auth.logIn(email: _email.text, password: _password.text);
      } else {
        await widget.auth.signUp(email: _email.text, password: _password.text);
      }
      TextInput.finishAutofillContext();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final sent = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BakeColors.warmCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _ResetSheet(auth: widget.auth, initialEmail: _email.text.trim()),
    );
    if (sent != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('If there’s an account for $sent, a reset link is on its way. Check your inbox.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: [
                const Center(
                  child: AnimatedMascot(
                    MascotPose.duoWelcome,
                    size: 150,
                    animationAsset: MascotMotion.welcomeAsset,
                    posterAsset: MascotMotion.welcomePosterAsset,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: 250.ms,
                  child: Column(
                    key: ValueKey(_logIn),
                    children: [
                      Text(_logIn ? 'Welcome back' : 'Create your account', textAlign: TextAlign.center, style: text.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        _logIn ? 'Jack and Jill kept your seat warm 🍒' : 'A few minutes to set up, and your cherries will guide you.',
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(color: BakeColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _ModeSwitch(logIn: _logIn, enabled: !_busy, onChanged: _switchMode),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('auth-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  enableSuggestions: false,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: bakeField('Email').copyWith(prefixIcon: const Icon(Icons.mail_outline_rounded)),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s) ? null : 'Enter your email address';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('auth-password'),
                  controller: _password,
                  focusNode: _passwordFocus,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: [_logIn ? AutofillHints.password : AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _busy ? null : _submit(),
                  decoration: bakeField('Password').copyWith(
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    helperText: _logIn ? null : 'At least 6 characters',
                    suffixIcon: IconButton(
                      key: const Key('auth-show-password'),
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    ),
                  ),
                  validator: (v) => (v ?? '').length >= 6 ? null : 'At least 6 characters',
                ),
                if (_logIn)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('auth-forgot'),
                      onPressed: _busy ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  )
                else
                  const SizedBox(height: 12),
                if (_error != null) _ErrorNote(_error!).animate().fadeIn(duration: 200.ms).shakeX(hz: 4, amount: 3),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('auth-submit'),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(_logIn ? 'Log in' : 'Create account'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const Key('auth-toggle'),
                  onPressed: _busy ? null : () => _switchMode(!_logIn),
                  child: Text(_logIn ? 'New here? Create an account' : 'Already have an account? Log in'),
                ),
                if (!_logIn)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'BakeOut is for people aged 18 and over. We’ll ask for your birthday next.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: BakeColors.muted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Log in | Sign up" as one rounded switch.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.logIn, required this.enabled, required this.onChanged});

  final bool logIn;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget side(String label, bool isLogIn, Key key) {
      final on = logIn == isLogIn;
      return Expanded(
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged(isLogIn) : null,
          child: MouseRegion(
            cursor: enabled && !on ? SystemMouseCursors.click : MouseCursor.defer,
            child: AnimatedContainer(
            duration: 200.ms,
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: on ? [BoxShadow(color: BakeColors.deepCherry.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))] : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, color: on ? BakeColors.deepCherry : BakeColors.muted),
            ),
          ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: BakeColors.softPink, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          side('Log in', true, const Key('auth-mode-login')),
          side('Sign up', false, const Key('auth-mode-signup')),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('auth-error'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: BakeColors.softPink,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BakeColors.cherryRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: BakeColors.deepCherry, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: BakeColors.deepCherry, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

/// Asks for the email and sends a reset link; returns the email it was sent to.
class _ResetSheet extends StatefulWidget {
  const _ResetSheet({required this.auth, required this.initialEmail});

  final AuthService auth;
  final String initialEmail;

  @override
  State<_ResetSheet> createState() => _ResetSheetState();
}

class _ResetSheetState extends State<_ResetSheet> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return setState(() => _error = 'Enter the email you signed up with.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.sendPasswordReset(email);
      if (mounted) Navigator.pop(context, email);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reset your password', style: text.headlineSmall),
          const SizedBox(height: 6),
          Text('We’ll email you a link to choose a new one.', style: text.bodyLarge?.copyWith(color: BakeColors.muted)),
          const SizedBox(height: 16),
          TextField(
            key: const Key('reset-email'),
            controller: _email,
            autofocus: widget.initialEmail.isEmpty,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            onSubmitted: (_) => _busy ? null : _send(),
            decoration: bakeField('Email').copyWith(prefixIcon: const Icon(Icons.mail_outline_rounded), errorText: _error),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('reset-send'),
            onPressed: _busy ? null : _send,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }
}
