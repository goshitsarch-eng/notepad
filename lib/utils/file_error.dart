import 'dart:io';

/// A short reason for a failed file operation, such as "Permission denied", for the
/// message boxes. Uses the system's own wording when it gave one. Returns an empty string
/// when the error carries no usable reason, so the caller can leave the line out.
String describeFileError(Object? error) {
  if (error is! FileSystemException) return '';
  final system = error.osError?.message.trim() ?? '';
  final reason = system.isNotEmpty ? system : error.message.trim();
  if (reason.isEmpty) return '';
  // Windows messages already end with a full stop. Keep every reason without one.
  return reason.endsWith('.') ? reason.substring(0, reason.length - 1) : reason;
}
