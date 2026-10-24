import 'package:flutter/material.dart';

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
  late bool _logIn = widget.startWithLogIn;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            children: [
              const Center(
                child: AnimatedMascot(
                  MascotPose.duoWelcome,
                  size: 170,
                  animationAsset: MascotMotion.welcomeAsset,
                  posterAsset: MascotMotion.welcomePosterAsset,
                ),
              ),
              Text(_logIn ? 'Welcome back' : 'Create your account', textAlign: TextAlign.center, style: text.headlineMedium),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('auth-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: bakeField('Email'),
                validator: (v) => (v ?? '').contains('@') ? null : 'Enter your email address',
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('auth-password'),
                controller: _password,
                obscureText: true,
                decoration: bakeField('Password'),
                validator: (v) => (v ?? '').length >= 6 ? null : 'At least 6 characters',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: text.bodyMedium?.copyWith(color: BakeColors.deepCherry)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('auth-submit'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_logIn ? 'Log in' : 'Create account'),
              ),
              TextButton(
                key: const Key('auth-toggle'),
                onPressed: _busy ? null : () => setState(() => _logIn = !_logIn),
                child: Text(_logIn ? 'New here? Create an account' : 'Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
