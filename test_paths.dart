import 'dart:io';

void main() {
  print('USERPROFILE: ${Platform.environment['USERPROFILE']!}');
  print('APPDATA: ${Platform.environment['APPDATA']!}');
  print('LOCALAPPDATA: ${Platform.environment['LOCALAPPDATA']!}');
}
