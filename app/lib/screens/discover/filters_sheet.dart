import 'package:flutter/material.dart';

import '../../data/cities.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../theme/colors.dart';
import '../../widgets/city_picker.dart';
import '../quiz/questions.dart';

/// Opens the Discover filters; saving them updates the profile, which reloads Discover.
Future<void> showDiscoverFilters(BuildContext context, {required UserProfile me, required ProfileService profiles}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BakeColors.warmCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _FiltersSheet(me: me, profiles: profiles),
    );

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.me, required this.profiles});

  final UserProfile me;
  final ProfileService profiles;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String _mode = widget.me.lookingFor ?? 'partner';
  late final Set<String> _food = {...widget.me.filters.foodTypes};
  late RangeValues _ages = RangeValues(widget.me.filters.minAge.toDouble(), widget.me.filters.maxAge.toDouble());
  late final List<String> _cities = [...widget.me.filters.cities];
  bool _saving = false;

  static const _floor = DiscoverFilters.ageFloor;
  static const _ceiling = DiscoverFilters.ageCeiling;

  void _reset() => setState(() {
        _food.clear();
        _ages = const RangeValues(_floor * 1.0, _ceiling * 1.0);
        _cities.clear();
      });

  Future<void> _addCity() async {
    final picked = await pickCity(context, title: 'Add a city', exclude: _cities.toSet());
    if (picked != null) setState(() => _cities.add(picked));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.profiles.saveDiscoverSettings(
        widget.me.uid,
        lookingFor: _mode,
        filters: DiscoverFilters(
          foodTypes: _food.toList(),
          minAge: _ages.start.round(),
          maxAge: _ages.end.round(),
          cities: _cities,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t save your filters — try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final foodOptions = quizQuestions.firstWhere((q) => q.field == 'foodType').options;
    final maxLabel = _ages.end.round() >= _ceiling ? '$_ceiling+' : '${_ages.end.round()}';
    final myCity = widget.me.city;

    Widget section(String title, [String? note]) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium),
              if (note != null) Text(note, style: text.bodyMedium?.copyWith(color: BakeColors.muted)),
            ],
          ),
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
            child: Row(
              children: [
                Expanded(child: Text('Who would you like to meet?', style: text.titleLarge)),
                TextButton(key: const Key('filters-reset'), onPressed: _reset, child: const Text('Reset')),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: const Key('filters-list'),
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                section('I’m here for', 'Switching also changes who can see you. Friends only ever meet friends.'),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'partner', label: Text('💞 A partner', key: Key('mode-partner'))),
                    ButtonSegment(value: 'friends', label: Text('🤝 Friends', key: Key('mode-friends'))),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                section('Food preference', _food.isEmpty ? 'Anyone — tap to narrow it down.' : null),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final o in foodOptions)
                      FilterChip(
                        key: Key('filter-food-${o.label}'),
                        label: Text('${o.emoji} ${o.label}'),
                        selected: _food.contains(o.label),
                        selectedColor: BakeColors.softPink,
                        onSelected: (on) => setState(() => on ? _food.add(o.label) : _food.remove(o.label)),
                      ),
                  ],
                ),
                section('Age', '${_ages.start.round()} – $maxLabel'),
                RangeSlider(
                  key: const Key('filter-age'),
                  values: _ages,
                  min: _floor.toDouble(),
                  max: _ceiling.toDouble(),
                  divisions: _ceiling - _floor,
                  activeColor: BakeColors.cherryRed,
                  labels: RangeLabels('${_ages.start.round()}', maxLabel),
                  onChanged: (v) => setState(() => _ages = v),
                ),
                section('Location'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      key: const Key('filter-anywhere'),
                      label: const Text('🌍 Anywhere'),
                      selected: _cities.isEmpty,
                      selectedColor: BakeColors.softPink,
                      onSelected: (_) => setState(_cities.clear),
                    ),
                    if (myCity != null && cities.contains(myCity) && !_cities.contains(myCity))
                      ActionChip(
                        key: const Key('filter-my-city'),
                        avatar: const Icon(Icons.near_me_outlined, size: 18),
                        label: Text('Near me · ${myCity.split(',').first}'),
                        onPressed: () => setState(() => _cities.add(myCity)),
                      ),
                    for (final c in _cities)
                      InputChip(
                        key: Key('filter-city-$c'),
                        label: Text('📍 $c'),
                        selected: true,
                        selectedColor: BakeColors.softPink,
                        showCheckmark: false,
                        onDeleted: () => setState(() => _cities.remove(c)),
                      ),
                    ActionChip(
                      key: const Key('filter-add-city'),
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Add a city'),
                      onPressed: _addCity,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('filters-apply'),
                  onPressed: _saving ? null : _save,
                  child: const Text('Show me people'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
