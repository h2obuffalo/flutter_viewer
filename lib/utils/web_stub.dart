// Stub file for non-web platforms
// This file is only used when dart:html is not available

class Window {
  Document get document => Document();
}

class Document {
  dynamic get defaultView => null;
}

// Stub window object - matches dart:html's window structure
final Window window = Window();
