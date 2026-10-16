/// Modèle de notification pour l'application Bamako Podcast.
/// Conforme au contrat serveur : { id, type, title, body, link, readAt, createdAt }.
class BkoNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final String? link;
  final String? actionLabel;
  final DateTime? readAt;
  final DateTime createdAt;

  const BkoNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.link,
    this.actionLabel,
    this.readAt,
    required this.createdAt,
  });

  /// Une notification est lue dès que [readAt] est renseigné côté serveur.
  bool get isRead => readAt != null;

  factory BkoNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final title = json['title']?.toString() ?? '';

    if (id.isEmpty) {
      throw const FormatException('Champ "id" manquant dans la notification.');
    }
    if (title.isEmpty) {
      throw const FormatException('Champ "title" manquant dans la notification.');
    }

    DateTime? parsedReadAt;
    final rawReadAt = json['readAt'];
    if (rawReadAt != null && rawReadAt.toString().trim().isNotEmpty) {
      parsedReadAt = DateTime.tryParse(rawReadAt.toString());
    }

    DateTime parsedCreatedAt;
    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt != null && rawCreatedAt.toString().trim().isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt.toString()) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    final parsedType = json['type']?.toString() ?? 'GENERIC';
    final parsedLink = json['link']?.toString();

    String? parsedActionLabel = json['actionLabel']?.toString();
    if (parsedActionLabel == null && json['metadata'] is Map) {
      parsedActionLabel = (json['metadata'] as Map)['actionLabel']?.toString();
    }
    if (parsedActionLabel == null && (parsedType == 'TEAM_MEMBER_ADDED' || (parsedLink != null && parsedLink.contains('/studio/podcasts')))) {
      parsedActionLabel = 'Ouvrir l’émission';
    }

    return BkoNotification(
      id: id,
      type: parsedType,
      title: title,
      body: json['body']?.toString(),
      link: parsedLink,
      actionLabel: parsedActionLabel,
      readAt: parsedReadAt,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'link': link,
      'actionLabel': actionLabel,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  BkoNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    String? link,
    String? actionLabel,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return BkoNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      link: link ?? this.link,
      actionLabel: actionLabel ?? this.actionLabel,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Contrat réel renvoyé par l'endpoint /me/notifications :
/// { items: BkoNotification[], unread: int }
class NotificationListResponse {
  final List<BkoNotification> items;
  final int unread;

  const NotificationListResponse({
    required this.items,
    required this.unread,
  });

  factory NotificationListResponse.fromResponse(dynamic data) {
    if (data is! Map) {
      throw const FormatException('Réponse invalide du serveur pour les notifications.');
    }

    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const FormatException('Format de liste de notifications invalide (champ "items" manquant).');
    }

    final items = <BkoNotification>[];
    for (final raw in rawItems) {
      if (raw is Map<String, dynamic>) {
        items.add(BkoNotification.fromJson(raw));
      } else if (raw is Map) {
        items.add(BkoNotification.fromJson(Map<String, dynamic>.from(raw)));
      } else {
        throw const FormatException('Élément de notification non analysable.');
      }
    }

    final unreadCount = data['unread'];
    final unread = unreadCount is num ? unreadCount.toInt() : 0;

    return NotificationListResponse(
      items: items,
      unread: unread,
    );
  }
}
