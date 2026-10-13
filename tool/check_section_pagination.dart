import 'dart:io';
import 'package:bko_app/features/discovery/section_page.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final first = SectionPage.parse({
    'section': {'slug': 'long-episodes'},
    'items': List.generate(20, (i) => {'id': 'episode-$i'}),
    'pagination': {'offset': 0, 'total': 43, 'hasMore': true},
  });
  check(first.total == 43 && first.nextOffset == 20 && first.hasMore,
      'The decoded API payload must replace the eight-item home preview.');
  final last = SectionPage.parse({
    'section': {'slug': 'long-episodes'},
    'items': List.generate(3, (i) => {'id': 'episode-${40 + i}'}),
    'pagination': {'offset': 40, 'total': 43, 'hasMore': false},
  });
  check(last.nextOffset == 43 && !last.hasMore, 'Last page must terminate pagination.');
  var rejected = false;
  try {
    SectionPage.parse({
      'section': {}, 'items': [],
      'pagination': {'offset': 0, 'total': 43, 'hasMore': true},
    });
  } on FormatException {
    rejected = true;
  }
  check(rejected, 'An empty page cannot silently keep requesting more.');
  stdout.writeln('Section pagination: 3 checks passed.');
}
