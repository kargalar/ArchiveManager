import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() async {
  // Try to find the document directory
  try {
    // path_provider doesn't work out of the box in simple scripts without package init,
    // so we'll just check common paths
    final docs = Platform.environment['USERPROFILE']! + r'\Documents\Archive Manager';
    final dir = Directory(docs);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      print('Deleted $docs');
    } else {
      print('Not found: $docs');
    }
    
    final appDocs = Platform.environment['USERPROFILE']! + r'\AppData\Roaming\Archive Manager';
    final dir2 = Directory(appDocs);
    if (dir2.existsSync()) {
      dir2.deleteSync(recursive: true);
      print('Deleted $appDocs');
    }
  } catch (e) {
    print(e);
  }
}
