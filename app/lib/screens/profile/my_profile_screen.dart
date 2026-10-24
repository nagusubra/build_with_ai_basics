import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/functions_service.dart';
import '../../services/profile_service.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../../widgets/log_out_sheet.dart';
import '../../widgets/mascot.dart';
import '../auth/basics_screen.dart';
import '../photos/photos_screen.dart';
import '../photos/verify_screen.dart';
import '../quiz/questions.dart';
import '../quiz/quiz_screen.dart';
import 'profile_view.dart';

/// Preview, edit, delete (`prd.md > My Profile: Preview, Edit, Delete`).
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key, required this.me, required this.profiles, required this.functions, required this.auth});

  final UserProfile me;
  final ProfileService profiles;
  final FunctionsService functions;
  final AuthService auth;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _deleting = false;

  Future<void> _open(Widget Function(VoidCallback done) screen) {
    final nav = Navigator.of(context);
    return nav.push(MaterialPageRoute(builder: (_) => screen(nav.pop)));
  }

  Future<void> _changePassword() async {
    final email = widget.auth.email;
    if (email == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.auth.sendPasswordReset(email);
      messenger.showSnackBar(SnackBar(content: Text('Check $email for a link to set a new password.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyAuthError(e))));
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile, photos, matches, and chats. '
          'People you matched with will no longer see you or your conversations. This can’t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep my account')),
          TextButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: BakeColors.deepCherry),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    setState(() => _deleting = true);
    try {
      await widget.functions.deleteAccount();
      await widget.auth.signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't delete everything just now — please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final text = Theme.of(context).textTheme;
    if (_deleting) {
      return const Scaffold(body: CherryLoading(caption: 'Deleting everything…'));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: ListView(
        key: const Key('my-profile-list'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          if (!me.verified)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: BakeColors.softPink, borderRadius: BorderRadius.circular(BakeShapes.cardRadius)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Get your verified badge ✓', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    me.verificationSkipped
                        ? 'A quick selfie check shows people you’re genuine. Some people only look at verified profiles.'
                        : 'You changed your photos, so the badge needs a new quick selfie check with your main photo.',
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    key: const Key('reverify'),
                    onPressed: () => _open((done) => VerifyScreen(profile: me, profiles: widget.profiles, onVerified: done)),
                    child: const Text('Verify now'),
                  ),
                ],
              ),
            ),
          Text('How others see you', style: text.titleMedium?.copyWith(color: BakeColors.muted)),
          const SizedBox(height: 10),
          ProfileView(profile: me, profiles: widget.profiles),
          const SizedBox(height: 28),
          Text('Edit', style: text.titleLarge),
          const SizedBox(height: 8),
          _EditTile(
            key: const Key('edit-basics'),
            title: 'Your basics',
            value: [me.name, me.city, me.lookingFor == 'friends' ? 'Friends' : 'A partner'].whereType<String>().join(' · '),
            onTap: () => _open((done) => BasicsScreen(uid: me.uid, profiles: widget.profiles, existing: me, onSaved: done)),
          ),
          _EditTile(
            key: const Key('edit-photos'),
            title: 'Photos',
            value: '${me.photos.length} photo${me.photos.length == 1 ? '' : 's'} · changing them means a new selfie check',
            onTap: () => _open((done) => PhotosScreen(profile: me, profiles: widget.profiles, onDone: done)),
          ),
          for (var i = 0; i < quizQuestions.length; i++)
            _EditTile(
              key: Key('edit-${quizQuestions[i].field}'),
              title: quizQuestions[i].title,
              value: answerSummary(quizQuestions[i], me.food, me.prompts),
              onTap: () => _open((done) => QuizScreen(profile: me, profiles: widget.profiles, startAt: i, onDone: done)),
            ),
          const SizedBox(height: 28),
          Text('Account', style: text.titleLarge),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.mail_outline_rounded, color: BakeColors.muted),
                  title: const Text('Signed in as'),
                  subtitle: Text(widget.auth.email ?? '—', key: const Key('account-email')),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  key: const Key('change-password'),
                  leading: const Icon(Icons.lock_reset_rounded, color: BakeColors.muted),
                  title: const Text('Change password'),
                  subtitle: const Text('We’ll email you a link to set a new one'),
                  onTap: _changePassword,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  key: const Key('logout'),
                  leading: const Icon(Icons.logout_rounded, color: BakeColors.cherryRed),
                  title: const Text('Log out', style: TextStyle(color: BakeColors.cherryRed, fontWeight: FontWeight.w800)),
                  onTap: () => confirmLogOut(context, auth: widget.auth, cherry: me.cherryAvatar),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: const Key('delete-account'),
            onPressed: _delete,
            style: OutlinedButton.styleFrom(
              foregroundColor: BakeColors.deepCherry,
              side: const BorderSide(color: BakeColors.deepCherry),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete my account'),
          ),
        ],
      ),
    );
  }
}

class _EditTile extends StatelessWidget {
  const _EditTile({super.key, required this.title, required this.value, required this.onTap});

  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missing = value == null || value!.isEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          missing ? 'Add an answer' : value!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: missing ? BakeColors.cherryRed : BakeColors.muted, fontWeight: missing ? FontWeight.w700 : null),
        ),
        trailing: const Icon(Icons.edit_outlined, color: BakeColors.muted),
      ),
    );
  }
}
