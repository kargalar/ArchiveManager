class IndexingState {
  final bool isIndexing;
  final double progress;
  final int processedCount;
  final int totalCount;

  IndexingState({
    required this.isIndexing,
    required this.progress,
    required this.processedCount,
    required this.totalCount,
  });

  String get statusText => isIndexing 
      ? 'İndeksleniyor: ${(progress * 100).toStringAsFixed(1)}% ($processedCount/$totalCount)' 
      : '';
}
