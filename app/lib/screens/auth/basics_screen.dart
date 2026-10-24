import 'package:flutter/material.dart';

import '../../data/cities.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../theme/colors.dart';
import '../../widgets/city_picker.dart';
import '../../widgets/mascot.dart';
import '../../widgets/mascot_rive.dart';
import '../../widgets/onboarding.dart';

const genders = ['Man', 'Woman', 'Non-binary', 'Other'];
const meetOptions = ['Men', 'Women', 'Everyone'];
const lookingForOptions = {'partner': ('A partner', '💞'), 'friends': ('Friends', '🤝')};

/// Sign-up basics (`prd.md > Sign-Up and Login`), also reused by Edit profile.
class BasicsScreen extends StatefulWidget {
  const BasicsScreen({super.key, required this.uid, required this.profiles, this.existing, this.onSaved});

  final String uid;
  final ProfileService profiles;
  final UserProfile? existing;

  /// Called after saving when editing; onboarding moves on by itself.
  final VoidCallback? onSaved;

  @override
  State<BasicsScreen> createState() => _BasicsScreenState();
}

class _BasicsScreenState extends State<BasicsScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late String? _city = cities.contains(widget.existing?.city) ? widget.existing?.city : null;
  DateTime? _dob;
  late String? _gender = widget.existing?.gender;
  late final Set<String> _meet = {...?widget.existing?.interestedIn};
  late String? _lookingFor = widget.existing?.lookingFor;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      widget.profiles.dateOfBirth(widget.uid).then((d) {
        if (mounted && d != null) setState(() => _dob = d);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Your date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    if (_dob == null) return setState(() => _error = 'Add your date of birth.');
    if (_city == null) return setState(() => _error = 'Pick your city from the list.');
    if (!isAdult(_dob!, DateTime.now())) {
      return setState(() => _error = 'BakeOut is for people aged 18 and over.');
    }
    if (_gender == null || _meet.isEmpty || _lookingFor == null) {
      return setState(() => _error = 'Pick your gender, who you’d like to meet, and what you’re looking for.');
    }
    setState(() => _busy = true);
    try {
      await widget.profiles.saveBasics(
        uid: widget.uid,
        name: _name.text,
        dateOfBirth: _dob!,
        gender: _gender!,
        interestedIn: _meet.toList(),
        city: _city!,
        lookingFor: _lookingFor!,
        keepCherry: widget.existing?.gender == _gender ? widget.existing?.cherryAvatar : null,
      );
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) setState(() => _error = 'Couldn’t save just now — please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dob = _dob;
    return Form(
      key: _form,
      child: OnboardingPage(
        title: widget.existing == null ? 'A little about you' : 'Your basics',
        subtitle: 'Just the essentials. Your birthday stays private — people only see your age.',
        progress: widget.existing == null ? 0.05 : null,
        onBack: widget.existing == null ? null : () => Navigator.pop(context),
        top: widget.existing == null
            ? const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Center(
                  child: AnimatedMascot(
                    MascotPose.duoWelcome,
                    size: 170,
                    animationAsset: MascotMotion.welcomeAsset,
                    posterAsset: MascotMotion.welcomePosterAsset,
                  ),
                ),
              )
            : null,
        action: FilledButton(
          key: const Key('basics-continue'),
          onPressed: _busy ? null : _save,
          child: Text(widget.existing == null ? 'Continue' : 'Save'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('basics-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: bakeField('First name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'What should we call you?' : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('basics-dob'),
              onPressed: _pickDob,
              icon: const Icon(Icons.cake_outlined),
              label: Text(dob == null
                  ? 'Date of birth'
                  : '${dob.day}/${dob.month}/${dob.year}  ·  ${ageOn(dob, DateTime.now())} years old'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('basics-city'),
              onPressed: () async {
                final picked = await pickCity(context);
                if (picked != null) setState(() => _city = picked);
              },
              icon: const Icon(Icons.place_outlined),
              label: Text(_city ?? 'City'),
            ),
            const SizedBox(height: 20),
            Text('I am', style: text.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in genders)
                  ChoiceChip(
                    key: Key('gender-$g'),
                    label: Text(g),
                    selected: _gender == g,
                    selectedColor: BakeColors.softPink,
                    onSelected: (_) => setState(() => _gender = g),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('I’d like to meet', style: text.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in meetOptions)
                  FilterChip(
                    key: Key('meet-$m'),
                    label: Text(m),
                    selected: _meet.contains(m),
                    selectedColor: BakeColors.softPink,
                    onSelected: (on) => setState(() => on ? _meet.add(m) : _meet.remove(m)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('I’m looking for', style: text.titleMedium),
            const SizedBox(height: 8),
            for (final e in lookingForOptions.entries)
              ChoiceTile(
                key: Key('looking-${e.key}'),
                label: e.value.$1,
                emoji: e.value.$2,
                selected: _lookingFor == e.key,
                onTap: () => setState(() => _lookingFor = e.key),
              ),
            if (_error != null) Text(_error!, style: text.bodyMedium?.copyWith(color: BakeColors.deepCherry)),
          ],
        ),
      ),
    );
  }
}
