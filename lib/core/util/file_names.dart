import 'dart:io';

/// A book ID (`pages:<sha1>`, `file:<hash>`) as a file or folder name.
/// Windows doesn't allow `:` in names, so there it becomes `_`; elsewhere
/// IDs are used as they are (keeping existing covers).
String idFileName(String bookId, {bool? windows}) =>
    (windows ?? Platform.isWindows) ? bookId.replaceFirst(':', '_') : bookId;

/// The book ID an [idFileName] stands for.
String idFromFileName(String name, {bool? windows}) =>
    (windows ?? Platform.isWindows) ? name.replaceFirst('_', ':') : name;

/// [name] (from another computer) made valid on this one: on Windows,
/// characters it refuses become `-` (`:` as ` -`), and a trailing dot or
/// space goes.
String localFileName(String name, {bool? windows}) {
  if (!(windows ?? Platform.isWindows)) return name;
  final safe = name
      .replaceAll(RegExp(r'\s*:\s*'), ' - ')
      .replaceAll(RegExp(r'[<>"/\\|?*\x00-\x1f]'), '-')
      .replaceAll(RegExp(r'[. ]+$'), '');
  return safe.isEmpty ? 'comic' : safe;
}
