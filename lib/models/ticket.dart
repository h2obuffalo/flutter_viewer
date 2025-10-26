class Ticket {
  final String ticketNumber;
  final String sessionId;
  final String? streamUrl;
  final DateTime issuedAt;
  final DateTime expiresAt;

  Ticket({
    required this.ticketNumber,
    required this.sessionId,
    this.streamUrl,
    required this.issuedAt,
    required this.expiresAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      ticketNumber: json['ticket_number'] as String,
      sessionId: json['session_id'] as String,
      streamUrl: json['stream_url'] as String?,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticket_number': ticketNumber,
      'session_id': sessionId,
      'stream_url': streamUrl,
      'issued_at': issuedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());
}
