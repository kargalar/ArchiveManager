/// Stub (non-IO platforms like web).
///
/// Returns -1 (unknown) so callers can persist "analyzed but unavailable".
class PhotoColorAnalyzer {
  static Future<int> computeColorCategoryCode(String path) async {
    return -1;
  }
}
