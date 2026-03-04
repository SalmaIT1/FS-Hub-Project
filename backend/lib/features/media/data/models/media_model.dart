class MediaModel {
  final String id;
  final String originalFilename;
  final String storedFilename;
  final String filePath;
  final int fileSize;
  final String mimeType;
  final String uploadedBy;
  final bool isPublic;
  final int downloadCount;
  final String? createdAt;
  final String? expiresAt;

  MediaModel({
    required this.id,
    required this.originalFilename,
    required this.storedFilename,
    required this.filePath,
    required this.fileSize,
    required this.mimeType,
    required this.uploadedBy,
    required this.isPublic,
    required this.downloadCount,
    this.createdAt,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'original_filename': originalFilename,
      'stored_filename': storedFilename,
      'file_path': filePath,
      'file_size': fileSize,
      'mime_type': mimeType,
      'uploaded_by': uploadedBy,
      'is_public': isPublic,
      'download_count': downloadCount,
      'created_at': createdAt,
      'expires_at': expiresAt,
    };
  }

  factory MediaModel.fromMap(Map<String, dynamic> map) {
    return MediaModel(
      id: map['id']?.toString() ?? '',
      originalFilename: map['original_filename']?.toString() ?? '',
      storedFilename: map['stored_filename']?.toString() ?? '',
      filePath: map['file_path']?.toString() ?? '',
      fileSize: map['file_size'] != null ? int.tryParse(map['file_size'].toString()) ?? 0 : 0,
      mimeType: map['mime_type']?.toString() ?? 'application/octet-stream',
      uploadedBy: map['uploaded_by']?.toString() ?? '',
      isPublic: map['is_public']?.toString() == '1' || map['is_public']?.toString() == 'true',
      downloadCount: map['download_count'] != null ? int.tryParse(map['download_count'].toString()) ?? 0 : 0,
      createdAt: map['created_at']?.toString(),
      expiresAt: map['expires_at']?.toString(),
    );
  }
}
