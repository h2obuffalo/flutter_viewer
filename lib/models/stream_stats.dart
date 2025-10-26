class StreamStats {
  final int p2pPeers;
  final int chunksLoaded;
  final int totalChunksDownloaded;
  final int p2pDownloadedMB;
  final int httpDownloadedMB;
  final double liveLatencySeconds;
  final String bufferHealth;
  final double p2pRatio; // Percentage of data from P2P vs HTTP

  StreamStats({
    this.p2pPeers = 0,
    this.chunksLoaded = 0,
    this.totalChunksDownloaded = 0,
    this.p2pDownloadedMB = 0,
    this.httpDownloadedMB = 0,
    this.liveLatencySeconds = 0,
    this.bufferHealth = '--',
    this.p2pRatio = 0,
  });

  StreamStats copyWith({
    int? p2pPeers,
    int? chunksLoaded,
    int? totalChunksDownloaded,
    int? p2pDownloadedMB,
    int? httpDownloadedMB,
    double? liveLatencySeconds,
    String? bufferHealth,
    double? p2pRatio,
  }) {
    return StreamStats(
      p2pPeers: p2pPeers ?? this.p2pPeers,
      chunksLoaded: chunksLoaded ?? this.chunksLoaded,
      totalChunksDownloaded: totalChunksDownloaded ?? this.totalChunksDownloaded,
      p2pDownloadedMB: p2pDownloadedMB ?? this.p2pDownloadedMB,
      httpDownloadedMB: httpDownloadedMB ?? this.httpDownloadedMB,
      liveLatencySeconds: liveLatencySeconds ?? this.liveLatencySeconds,
      bufferHealth: bufferHealth ?? this.bufferHealth,
      p2pRatio: p2pRatio ?? this.p2pRatio,
    );
  }
}
