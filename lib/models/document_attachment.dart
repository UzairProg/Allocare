class DocumentAttachment {
  const DocumentAttachment({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSizeBytes,
    required this.base64Data,
    this.uploadedAt,
    this.label,
    this.localPath,
  });

  final String id;
  final String fileName;
  final String fileType; // 'image/jpeg', 'application/pdf', etc.
  final int fileSizeBytes;
  final String base64Data;
  final DateTime? uploadedAt;
  final String? label;
  final String? localPath;

  factory DocumentAttachment.fromMap(String id, Map<String, dynamic> map) {
    return DocumentAttachment(
      id: id,
      fileName: (map['fileName'] as String?) ?? 'Attachment',
      fileType: (map['fileType'] as String?) ?? 'application/octet-stream',
      fileSizeBytes: _toInt(map['fileSizeBytes']),
      base64Data: (map['base64Data'] as String?) ?? '',
      uploadedAt: _asDateTime(map['uploadedAt']),
      label: (map['label'] as String?)?.trim(),
      localPath: (map['localPath'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'fileType': fileType,
      'fileSizeBytes': fileSizeBytes,
      'base64Data': base64Data,
      'uploadedAt': uploadedAt?.toIso8601String(),
      if (label != null && label!.trim().isNotEmpty) 'label': label,
    };
  }

  // Firestore document-safe map: excludes raw file payload and local path.
  Map<String, dynamic> toFirestoreMetadataMap() {
    return {
      'fileName': fileName,
      'fileType': fileType,
      'fileSizeBytes': fileSizeBytes,
      'uploadedAt': uploadedAt?.toIso8601String(),
      if (label != null && label!.trim().isNotEmpty) 'label': label,
    };
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  String get fileSizeDisplay {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isImage => fileType.startsWith('image/');
  bool get isPdf => fileType == 'application/pdf';
}
