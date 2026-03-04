class VoiceMessageModel {
  final String fileId;
  final int durationSeconds;
  final List<double> waveform;
  final String? transcription;
  final String mediaUrl;

  VoiceMessageModel({
    required this.fileId,
    required this.durationSeconds,
    required this.waveform,
    this.transcription,
    required this.mediaUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'duration': durationSeconds.toString(), // Client expects String
      'waveform': waveform,
      'transcription': transcription,
      'url': mediaUrl,
    };
  }

  factory VoiceMessageModel.fromMap(Map<String, dynamic> map) {
    return VoiceMessageModel(
      fileId: map['fileId']?.toString() ?? '',
      durationSeconds: map['duration_seconds'] ?? 0,
      waveform: List<double>.from(map['waveform'] ?? []),
      transcription: map['transcription'],
      mediaUrl: map['media_url'] ?? '',
    );
  }
}
