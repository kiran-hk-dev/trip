import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Base class for every persisted model in TripSplit World.
///
/// Models are hand-written value types rather than generated code so that the
/// JSON contract with Postgres stays explicit and reviewable — a silent
/// field-name mismatch in generated `fromJson` is one of the most common
/// causes of a broken financial screen.
@immutable
abstract class Model {
  const Model();

  Map<String, dynamic> toJson();
}

DateTime _dateTime(Object? value) {
  if (value == null) return DateTime.now();
  return DateTime.parse(value as String).toLocal();
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.parse(value as String).toLocal();
}

DateTime _dateOnly(Object? value) {
  final DateTime parsed = _dateTime(value);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _dateOnlyOrNull(Object? value) {
  if (value == null) return null;
  return _dateOnly(value);
}

int _int(Object? value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

List<String> _stringList(Object? value) {
  if (value is List) return value.map((e) => '$e').toList();
  return const <String>[];
}

List<String> _stringListOrEmpty(Object? value) => _stringList(value);

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

/// JSON decoding helper that keeps `DateTime` handling consistent.
DateTime decodeDateTime(Object? v) => _dateTime(v);
DateTime? decodeDateTimeOrNull(Object? v) => _dateTimeOrNull(v);
DateTime decodeDate(Object? v) => _dateOnly(v);
DateTime? decodeDateOrNull(Object? v) => _dateOnlyOrNull(v);
int decodeInt(Object? v, [int fallback = 0]) => _int(v, fallback);
double? decodeDouble(Object? v) => _doubleOrNull(v);
List<String> decodeStringList(Object? v) => _stringListOrEmpty(v);
Map<String, dynamic> decodeMap(Object? v) => _map(v);

String encodeJson(Object value) => jsonEncode(value);
Map<String, dynamic> decodeJsonMap(String value) =>
    Map<String, dynamic>.from(jsonDecode(value) as Map);
