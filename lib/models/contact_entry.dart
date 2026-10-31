class ContactEntry {
  final String id; // unique - timestamp based
  final String number; // wa.me format: 91XXXXXXXXXX
  final String display; // +91 XXXXXXXXXX
  final String? name; // optional, read from the card
  final String? email; // optional, read from the card
  final DateTime scannedAt;

  ContactEntry({
    required this.id,
    required this.number,
    required this.display,
    this.name,
    this.email,
    required this.scannedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'display': display,
        'name': name,
        'email': email,
        'scannedAt': scannedAt.toIso8601String(),
      };

  factory ContactEntry.fromJson(Map<String, dynamic> json) => ContactEntry(
        id: json['id'] ?? json['scannedAt'], // fallback for old entries
        number: json['number'],
        display: json['display'],
        name: json['name'], // null for old entries
        email: json['email'], // null for old entries
        scannedAt: DateTime.parse(json['scannedAt']),
      );
}