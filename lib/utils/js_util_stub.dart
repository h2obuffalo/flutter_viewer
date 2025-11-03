// Stub file for non-web platforms
// This file is only used when dart:js_util is not available
// dart:js_util exports top-level functions that are accessed via prefix when imported 'as js_util'
// We need to export top-level functions with the same names

// Top-level functions matching dart:js_util API
// When imported 'as js_util', these are accessible as js_util.getProperty() and js_util.callMethod()
dynamic getProperty(dynamic object, String property) => null;
dynamic callMethod(dynamic object, String method, List<dynamic> args) => null;
