// Stub file for non-web platforms
// This file is only used when dart:html is not available

class Window {
  Document get document => Document();
}

class Document {
  dynamic get defaultView => null;
  dynamic getElementById(String id) => null;
  dynamic get documentElement => null;
  dynamic get fullscreenElement => null;
}

// Stub window object - matches dart:html's window structure
final Window window = Window();

// Stub document object - matches dart:html's top-level document
final Document document = Document();
