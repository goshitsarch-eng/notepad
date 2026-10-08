/// One entry in the "Files of type" list of the Open and Save As dialogs.
class FileTypeFilter {
  const FileTypeFilter(this.label, this.extensions);

  final String label;

  /// Lower-case extensions including the dot, or null to match every file.
  final List<String>? extensions;

  bool matches(String fileName) {
    final allowed = extensions;
    if (allowed == null) return true;
    final lower = fileName.toLowerCase();
    return allowed.any(lower.endsWith);
  }
}

const textDocumentsFilter = FileTypeFilter('Text Documents (*.txt)', ['.txt']);
const allFilesFilter = FileTypeFilter('All Files (*.*)', null);
