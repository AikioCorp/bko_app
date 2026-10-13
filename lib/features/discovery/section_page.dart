/// BkoApi already unwraps the response envelope. A section page is not a
/// second {success, data} response and must contain real pagination metadata.
class SectionPage {
  final Map<String, dynamic> section;
  final List<Map<String, dynamic>> items;
  final int total;
  final int nextOffset;
  final bool hasMore;

  SectionPage._(this.section, this.items, this.total, this.nextOffset, this.hasMore);

  factory SectionPage.parse(dynamic payload) {
    if (payload is! Map || payload['section'] is! Map ||
        payload['items'] is! List || payload['pagination'] is! Map) {
      throw const FormatException('Réponse de section invalide');
    }
    final pagination = payload['pagination'] as Map;
    final offset = (pagination['offset'] as num?)?.toInt();
    final total = (pagination['total'] as num?)?.toInt();
    final items = (payload['items'] as List).map((item) {
      if (item is! Map) throw const FormatException('Contenu de section invalide');
      return Map<String, dynamic>.from(item);
    }).toList();
    if (offset == null || offset < 0 || total == null || total < 0 ||
        pagination['hasMore'] is! bool ||
        (items.isEmpty && pagination['hasMore'] == true)) {
      throw const FormatException('Pagination de section invalide');
    }
    return SectionPage._(Map<String, dynamic>.from(payload['section']),
      items, total, offset + items.length, pagination['hasMore'] == true);
  }
}
