class VideoChunk {
  final int sequence;
  final String filename;
  final String? magnetURI;
  final String? httpUrl;
  final String? r2Url;
  final String? infoHash;
  final int? size;
  final DateTime timestamp;
  
  VideoChunk({
    required this.sequence,
    required this.filename,
    this.magnetURI,
    this.httpUrl,
    this.r2Url,
    this.infoHash,
    this.size,
    required this.timestamp,
  });
  
  factory VideoChunk.fromJson(Map<String, dynamic> json) {
    return VideoChunk(
      sequence: json['seq'] as int,
      filename: json['filename'] as String,
      magnetURI: json['magnet'] as String?,
      httpUrl: json['http'] as String?,
      r2Url: json['r2'] as String?,
      infoHash: json['infoHash'] as String?,
      size: json['size'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int,
      ),
    );
  }
  
  // Get the best available URL (prefer R2, fallback to HTTP)
  String? get bestUrl => r2Url ?? httpUrl;
  
  // Check if chunk is available via P2P
  bool get hasP2P => magnetURI != null && magnetURI!.isNotEmpty;
  
  Duration get age => DateTime.now().difference(timestamp);
}
