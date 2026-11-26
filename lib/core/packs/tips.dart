/// One note from the `tips` content pack: a card tip or warning from the
/// Pulse team that arrives without an app update.
class PackTip {
  const PackTip({required this.id, required this.title, required this.body, this.url});
  final String id;
  final String title;
  final String body;

  /// Optional https link ("Read more").
  final String? url;

  static PackTip? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final body = raw['body'];
    if (id is! String || title is! String || body is! String || title.isEmpty) return null;
    final audience = raw['audience'];
    if (audience is String && audience != 'all') return null; // only 'all' exists today
    final url = raw['url'];
    return PackTip(
      id: id,
      title: title,
      body: body,
      url: url is String && url.startsWith('https://') ? url : null,
    );
  }
}

/// The tips in [pack], newest first as listed, skipping malformed entries.
List<PackTip> tipsFromPack(Map<String, Object?>? pack) => [
  for (final raw in (pack?['items'] as List?) ?? const [])
    ?PackTip.tryParse(raw),
];
