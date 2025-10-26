import 'dart:io' show Platform;

class PlatformUtils {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isTV => false; // TODO: Detect TV device
}
