class ChatAttachmentModel {
  final String id;
  final String type;
  final String filename;
  final String mimeType;
  final int fileSize;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String displaySize;

  ChatAttachmentModel({
    required this.id,
    required this.type,
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.displaySize,
    String? originalFilename,
  }) : this.originalFilename = originalFilename ?? filename;

  final String originalFilename;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'filename': filename,
      'originalFilename': originalFilename,
      'mimeType': mimeType,
      'size': fileSize,
      'url': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'displaySize': displaySize,
    };
  }

  factory ChatAttachmentModel.fromMap(Map<String, dynamic> map) {
    final path = map['file_path']?.toString() ?? '';
    final size = map['file_size'] is int ? map['file_size'] : int.tryParse(map['file_size']?.toString() ?? '0') ?? 0;
    
    // Simple display size calculation
    String displaySize = '${size} B';
    if (size > 1024 * 1024) displaySize = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    else if (size > 1024) displaySize = '${(size / 1024).toStringAsFixed(1)} KB';

    return ChatAttachmentModel(
      id: map['id']?.toString() ?? '',
      type: map['type'] ?? 'file',
      filename: map['filename'] ?? '',
      originalFilename: map['original_filename'] ?? map['filename'] ?? '',
      mimeType: map['mime_type'] ?? 'application/octet-stream',
      fileSize: size,
      mediaUrl: path.startsWith('http') ? path : '/media/${path.split('/').last}',
      thumbnailUrl: map['thumbnail_path'] != null 
          ? (map['thumbnail_path'].toString().startsWith('http') ? map['thumbnail_path'].toString() : '/media/${map['thumbnail_path'].toString().split('/').last}')
          : null,
      displaySize: displaySize,
    );
  }
}
