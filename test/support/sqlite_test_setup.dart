/// Host-side SQLite setup for tests.
///
/// `flutter test` runs on the desktop, where there is no Android SQLite, so the
/// FFI implementation is used instead. Ubuntu ships `libsqlite3.so.0` but not
/// the unversioned `libsqlite3.so` symlink that comes with the -dev package, so
/// the loader is pointed at the versioned name explicitly. Nothing here affects
/// the app on a device, which uses the platform's own SQLite.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

bool _initialised = false;

/// Candidate library names, most specific first.
const _linuxCandidates = <String>[
  'libsqlite3.so.0',
  'libsqlite3.so',
  '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
];

void initSqliteForTests() {
  if (_initialised) return;
  _initialised = true;

  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, _openLinuxSqlite);
  }
  sqfliteFfiInit();
  // The isolate-based factory would run SQLite where the loader override above
  // does not apply, so the same-isolate factory is used for tests.
  databaseFactory = databaseFactoryFfiNoIsolate;
}

DynamicLibrary _openLinuxSqlite() {
  Object? lastError;
  for (final name in _linuxCandidates) {
    try {
      return DynamicLibrary.open(name);
    } on ArgumentError catch (error) {
      lastError = error;
    }
  }
  throw StateError(
    'No usable libsqlite3 found (tried ${_linuxCandidates.join(', ')}). '
    'Install the sqlite3 runtime library to run database tests. Last error: $lastError',
  );
}
