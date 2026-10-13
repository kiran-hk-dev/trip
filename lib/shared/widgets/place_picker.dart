import 'package:flutter/material.dart';

import '../../core/reference/airports.dart';
import '../../core/reference/countries.dart';
import '../../core/theme/app_theme.dart';

/// Searchable country picker.
///
/// Returns the chosen [Country], or null if the user backed out. Free text is
/// always available: the list covers ISO 3166-1, and anything the user types
/// that matches no country is returned as a code-less [Country] rather than
/// being rejected. Blocking a name we did not think of would be worse than
/// storing one.
Future<Country?> pickCountry(BuildContext context, {String? initialCode}) {
  return showCountryPicker(context, initialCode: initialCode);
}

/// See [pickCountry].
Future<Country?> showCountryPicker(
  BuildContext context, {
  String? initialCode,
}) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder: (BuildContext context) =>
        _SearchSheet<Country>(initialCode: initialCode),
  );
}

/// Searchable airport picker.
///
/// Returns the chosen [Airport]. Free text lets a user type an IATA code or
/// airport name that is not in the bundled major-airport list.
Future<Airport?> pickAirport(BuildContext context, {String? initialCode}) {
  return showModalBottomSheet<Airport>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder: (BuildContext context) => _SearchSheet<Airport>(
      initialCode: initialCode,
    ),
  );
}

/// Shared searchable-list sheet for countries and airports.
///
/// Generic over the item type so both pickers behave identically; only the
/// label, subtitle and search function differ.
class _SearchSheet<T> extends StatefulWidget {
  const _SearchSheet({this.initialCode});

  final String? initialCode;

  @override
  State<_SearchSheet<T>> createState() => _SearchSheetState<T>();
}

class _SearchSheetState<T> extends State<_SearchSheet<T>> {
  late final TextEditingController _query = TextEditingController();
  late List<T> _results = _search('');

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _isCountry => T == Country;
  bool get _isAirport => T == Airport;

  List<T> _search(String q) {
    if (_isCountry) {
      return searchCountries(q).cast<T>();
    }
    if (_isAirport) {
      return searchAirports(q).cast<T>();
    }
    return const <Never>[];
  }

  void _submitFreeText() {
    final String raw = _query.text.trim();
    if (raw.isEmpty) return;
    if (_isCountry) {
      // An exact match wins; otherwise keep what the user typed with no code,
      // so the destination still records what they meant.
      final Country? exact = countryByCode(raw) ?? countryByName(raw);
      Navigator.of(context).pop(exact ?? Country('', raw));
      return;
    }
    if (_isAirport) {
      final Airport? known = airportByCode(raw);
      if (known != null) {
        Navigator.of(context).pop(known);
        return;
      }
      final String upper = raw.toUpperCase();
      Navigator.of(context).pop(
        Airport(
          upper.length == 3 ? upper : upper.padRight(3, ' ').substring(0, 3),
          raw,
          raw,
          '',
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String title = _isCountry ? 'Choose a country' : 'Choose an airport';
    final String hint = _isCountry
        ? 'Search a country, or type one'
        : 'Search by code, airport or city';

    return Padding(
      // Lifts the sheet above the keyboard so the list stays visible while
      // typing, which is the whole point of a searchable picker.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (String v) => setState(() => _results = _search(v)),
              onSubmitted: (_) => _submitFreeText(),
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _query.clear();
                          setState(() => _results = _search(''));
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: _results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: <Widget>[
                        Text(
                          'No match in the list.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Press enter to use "${_query.text.trim()}".',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (BuildContext context, int i) {
                      final T item = _results[i];
                      return ListTile(
                        leading: Text(
                          _flagFor(item),
                          style: theme.textTheme.titleLarge,
                        ),
                        title: Text(_titleFor(item)),
                        subtitle: Text(_subtitleFor(item)),
                        trailing: Text(
                          _codeFor(item),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  String _flagFor(T item) {
    if (item is Country) return item.flagEmoji;
    if (item is Airport) {
      final Country? c = countryByCode(item.countryCode);
      return c?.flagEmoji ?? '';
    }
    return '';
  }

  String _titleFor(T item) {
    if (item is Country) return item.name;
    if (item is Airport) return item.city;
    return '';
  }

  String _subtitleFor(T item) {
    if (item is Country) return '';
    if (item is Airport) {
      final Country? c = countryByCode(item.countryCode);
      final String place = c == null ? '' : ' · ${c.name}';
      return '${item.name}$place';
    }
    return '';
  }

  String _codeFor(T item) {
    if (item is Country) return item.code;
    if (item is Airport) return item.code;
    return '';
  }
}