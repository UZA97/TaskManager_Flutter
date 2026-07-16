import 'dart:convert';

class AttachmentMeta {
  final String relativePath; // e.g. "Attachments/1/image.png"
  final String checksum; // sha256

  const AttachmentMeta({required this.relativePath, required this.checksum});

  factory AttachmentMeta.fromJson(Map<String, dynamic> json) => AttachmentMeta(
    relativePath: json['relativePath'] as String,
    checksum: json['checksum'] as String,
  );

  Map<String, dynamic> toJson() => {
    'relativePath': relativePath,
    'checksum': checksum,
  };
}

class SyncMeta {
  final DateTime lastSync;
  final String deviceId;
  final String dbChecksum;
  final List<AttachmentMeta> attachments;

  const SyncMeta({
    required this.lastSync,
    required this.deviceId,
    required this.dbChecksum,
    required this.attachments,
  });

  factory SyncMeta.fromJson(Map<String, dynamic> json) => SyncMeta(
    lastSync: DateTime.parse(json['last_sync'] as String),
    deviceId: json['device_id'] as String,
    dbChecksum: json['db_checksum'] as String,
    attachments: (json['attachments'] as List<dynamic>)
        .map((e) => AttachmentMeta.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'last_sync': lastSync.toUtc().toIso8601String(),
    'device_id': deviceId,
    'db_checksum': dbChecksum,
    'attachments': attachments.map((e) => e.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());

  static SyncMeta decode(String json) =>
      SyncMeta.fromJson(jsonDecode(json) as Map<String, dynamic>);
}
