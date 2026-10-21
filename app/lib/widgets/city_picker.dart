import 'package:flutter/material.dart';

import '../data/cities.dart';
import '../theme/colors.dart';

/// A searchable sheet of [cities]; returns the one picked, or null.
Future<String?> pickCity(BuildContext context, {String title = 'Where are you?', Set<String> exclude = const {}}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BakeColors.warmCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CitySheet(title: title, exclude: exclude),
    );

class _CitySheet extends StatefulWidget {
  const _CitySheet({required this.title, required this.exclude});

  final String title;
  final Set<String> exclude;

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final found = searchCities(_query).where((c) => !widget.exclude.contains(c)).toList();
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: text.titleLarge),
            const SizedBox(height: 10),
            TextField(
              key: const Key('city-search'),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search cities',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: BakeColors.line)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: found.isEmpty
                  ? Center(
                      child: Text('We don’t have that city yet — try the nearest big one.',
                          textAlign: TextAlign.center, style: text.bodyLarge?.copyWith(color: BakeColors.muted)),
                    )
                  : ListView.builder(
                      itemCount: found.length,
                      itemBuilder: (_, i) => ListTile(
                        key: Key('city-${found[i]}'),
                        leading: const Text('📍', style: TextStyle(fontSize: 20)),
                        title: Text(found[i]),
                        onTap: () => Navigator.pop(context, found[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
