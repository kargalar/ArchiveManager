import '../models/photo.dart';
import '../models/sort_state.dart';

/// Utility class for sorting photos based on different criteria.
/// This centralizes sorting logic that was previously duplicated across multiple files.
class PhotoSorter {
  /// Sorts a list of photos based on the provided sort states.
  /// Priority: rating > date > resolution
  static List<Photo> sort(
    List<Photo> photos, {
    SortState ratingSortState = SortState.none,
    SortState dateSortState = SortState.none,
    SortState resolutionSortState = SortState.none,
  }) {
    // Create a copy to avoid modifying the original list
    final sortedPhotos = List<Photo>.from(photos);

    // Apply sorting based on priority
    if (ratingSortState != SortState.none) {
      _sortByRating(sortedPhotos, ratingSortState);
    } else if (dateSortState != SortState.none) {
      _sortByDate(sortedPhotos, dateSortState);
    } else if (resolutionSortState != SortState.none) {
      _sortByResolution(sortedPhotos, resolutionSortState);
    }

    return sortedPhotos;
  }

  /// Sorts photos by rating
  static void _sortByRating(List<Photo> photos, SortState sortState) {
    if (sortState == SortState.ascending) {
      photos.sort((a, b) => a.rating.compareTo(b.rating));
    } else {
      photos.sort((a, b) => b.rating.compareTo(a.rating));
    }
  }

  /// Sorts photos by date modified
  static void _sortByDate(List<Photo> photos, SortState sortState) {
    if (sortState == SortState.ascending) {
      photos.sort((a, b) {
        final dateA = a.dateModified;
        final dateB = b.dateModified;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return -1;
        if (dateB == null) return 1;
        return dateA.compareTo(dateB);
      });
    } else {
      photos.sort((a, b) {
        final dateA = a.dateModified;
        final dateB = b.dateModified;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
    }
  }

  /// Sorts photos by resolution
  static void _sortByResolution(List<Photo> photos, SortState sortState) {
    if (sortState == SortState.ascending) {
      photos.sort((a, b) => a.resolution.compareTo(b.resolution));
    } else {
      photos.sort((a, b) => b.resolution.compareTo(a.resolution));
    }
  }
}
