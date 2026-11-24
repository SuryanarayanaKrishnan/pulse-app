/// Opens the encrypted on-device database. The real implementation needs
/// `dart:ffi` (SQLite3 Multiple Ciphers), so the web build, which only runs
/// demo data, gets a stub that refuses.
library;

export 'open_native.dart' if (dart.library.js_interop) 'open_web.dart';
