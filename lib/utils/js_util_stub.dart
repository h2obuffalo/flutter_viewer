// Stub file for non-web platforms
// This file is only used when dart:js_util is not available
// Provides stub functions matching dart:js_util API
// Note: dart:js_util uses top-level functions, but when imported as js_util,
// we need to match the namespace pattern used in code

class JsUtilNamespace {
  dynamic getProperty(dynamic object, String property) => null;
  dynamic callMethod(dynamic object, String method, List<dynamic> args) => null;
}

// Export as namespace to match usage pattern: js_util.getProperty()
final js_util = JsUtilNamespace();
