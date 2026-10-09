import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:xp_notepad/data/services/file_system_service.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/file_filter.dart';
import 'package:xp_notepad/ui/core/xp_button.dart';
import 'package:xp_notepad/ui/core/xp_dialog.dart';
import 'package:xp_notepad/ui/core/xp_fields.dart';
import 'package:xp_notepad/ui/core/xp_icons.dart';
import 'package:xp_notepad/ui/core/xp_scrollbar.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';
import 'package:xp_notepad/utils/file_error.dart';

/// The Open and Save As dialogs. They list folders and files with the XP columns, and
/// provide "Look in", "File name", "Files of type" and, for saving, "Encoding".
class FileDialog extends StatefulWidget {
  const FileDialog({super.key, required this.request});

  final FileRequest request;

  @override
  State<FileDialog> createState() => _FileDialogState();
}

class _FileDialogState extends State<FileDialog> {
  static const _width = 510.0;
  static const _labelWidth = 72.0;
  static const _listHeight = 200.0;

  late final FileSystemService _fileSystem;
  late String _directory = widget.request.startDirectory;
  late FileEncoding _encoding = widget.request.encoding;

  /// What the Open dialog reads the file as. Null is to detect it from the file.
  FileEncoding? _openAs;
  FileTypeFilter _filter = textDocumentsFilter;
  List<DirectoryEntry> _entries = const [];
  int? _selected;

  /// Why the current folder cannot be shown, or null when it listed normally.
  String? _problem;
  int _loadSerial = 0;
  final _name = TextEditingController();
  final _nameFocus = FocusNode(debugLabel: 'file name');

  bool get _isSave => widget.request.mode == FileDialogMode.save;

  @override
  void initState() {
    super.initState();
    _fileSystem = context.read<FileSystemService>();
    _name.text = widget.request.suggestedName ?? '';
    unawaited(_load());
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final serial = ++_loadSerial;
    var directory = _directory;
    var entries = const <DirectoryEntry>[];
    String? problem;
    while (true) {
      try {
        entries = await _fileSystem.listDirectory(directory, _filter);
        break;
      } on PathNotFoundException catch (error) {
        // A folder that has been deleted or moved since it was last used: show the nearest
        // folder above it that still exists, rather than an empty list.
        final parent = p.dirname(directory);
        if (parent != directory) {
          directory = parent;
          continue;
        }
        problem = _folderProblem(error);
        break;
      } on FileSystemException catch (error) {
        // An empty list with no explanation looks like an empty folder, so say why.
        problem = _folderProblem(error);
        break;
      }
    }
    if (!mounted || serial != _loadSerial) return;
    setState(() {
      _directory = directory;
      _entries = entries;
      _problem = problem;
      _selected = null;
    });
  }

  static String _folderProblem(FileSystemException error) {
    final reason = describeFileError(error);
    return reason.isEmpty
        ? 'This folder cannot be opened.'
        : 'This folder cannot be opened.\n$reason';
  }

  void _navigate(String directory) {
    setState(() => _directory = directory);
    unawaited(_load());
  }

  /// Opens a folder that was named in the File name box. The name typed to get here is
  /// cleared, so it is not taken for a file name in the new folder.
  void _enter(String directory) {
    _name.clear();
    _navigate(directory);
  }

  void _goUp() {
    final parent = p.dirname(_directory);
    if (parent != _directory) _navigate(parent);
  }

  void _cancel() => widget.request.complete(null);

  void _activate(DirectoryEntry entry) {
    if (entry.isDirectory) {
      // Going into a folder from the list keeps what was typed, as Up and Look in do.
      _navigate(entry.path);
      // Keep typing in the file name box after entering a folder, as XP does.
      _nameFocus.requestFocus();
      return;
    }
    widget.request.complete(
      FileChoice(entry.path, _encoding, openAs: _isSave ? null : _openAs),
    );
  }

  void _select(int index) {
    final entry = _entries[index];
    setState(() {
      _selected = index;
      if (!entry.isDirectory) _name.text = entry.name;
    });
  }

  DirectoryEntry? _entryNamed(String name, {required bool directory}) {
    for (final entry in _entries) {
      if (entry.isDirectory == directory && entry.name == name) return entry;
    }
    return null;
  }

  Future<void> _submit() async {
    final typed = _name.text.trim();
    if (typed.isEmpty) {
      final index = _selected;
      if (index != null) _activate(_entries[index]);
      return;
    }
    final folder = _entryNamed(typed, directory: true);
    if (folder != null) {
      _enter(folder.path);
      return;
    }
    final target = p.join(_directory, typed);
    // A typed path that names a folder opens the folder, as XP does. Without this a
    // folder path typed into Save As was saved as a file with that name.
    if (await _fileSystem.directoryExists(target)) {
      if (mounted) _enter(p.normalize(target));
      return;
    }
    if (!mounted) return;
    if (!_isSave) {
      // A missing file is reported by the view model, so the user is told why nothing
      // opened.
      widget.request.complete(FileChoice(target, _encoding, openAs: _openAs));
      return;
    }
    final extension = _filter.extensions?.first;
    final path = extension != null && p.extension(typed).isEmpty
        ? '$target$extension'
        : target;
    widget.request.complete(FileChoice(path, _encoding));
  }

  /// Folder hierarchy from the root down to the current folder, for "Look in".
  List<XpOption<String>> get _folderOptions {
    final options = <XpOption<String>>[];
    var current = '';
    for (final part in p.split(_directory)) {
      current = current.isEmpty ? part : p.join(current, part);
      options.add(XpOption(part, current));
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    return XpDialogWindow(
      title: _isSave ? 'Save As' : 'Open',
      width: _width,
      onClose: _cancel,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Text(
                    _isSave ? 'Save in:' : 'Look in:',
                    style: XpText.ui(),
                  ),
                ),
                Expanded(
                  child: XpComboBox<String>(
                    semanticLabel: _isSave ? 'Save in' : 'Look in',
                    options: _folderOptions,
                    value: _directory,
                    onChanged: _navigate,
                  ),
                ),
                const SizedBox(width: 6),
                XpButton(label: 'Up', width: 40, onPressed: _goUp),
              ],
            ),
            const SizedBox(height: 8),
            _FileList(
              entries: _entries,
              problem: _problem,
              selected: _selected,
              height: _listHeight,
              onSelect: _select,
              onActivate: _activate,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: _labelWidth,
                            child: Text('File name:', style: XpText.ui()),
                          ),
                          Expanded(
                            child: XpTextBox(
                              controller: _name,
                              focusNode: _nameFocus,
                              autofocus: true,
                              semanticLabel: 'File name',
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: _labelWidth,
                            child: Text('Files of type:', style: XpText.ui()),
                          ),
                          Expanded(
                            child: XpComboBox<FileTypeFilter>(
                              semanticLabel: 'Files of type',
                              options: const [
                                XpOption(
                                  'Text Documents (*.txt)',
                                  textDocumentsFilter,
                                ),
                                XpOption('All Files (*.*)', allFilesFilter),
                              ],
                              value: _filter,
                              onChanged: (filter) {
                                setState(() => _filter = filter);
                                unawaited(_load());
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: _labelWidth,
                            child: Text('Encoding:', style: XpText.ui()),
                          ),
                          Expanded(
                            child: _isSave
                                ? XpComboBox<FileEncoding>(
                                    semanticLabel: 'Encoding',
                                    options: [
                                      for (final encoding
                                          in FileEncoding.values)
                                        XpOption(encoding.label, encoding),
                                    ],
                                    value: _encoding,
                                    onChanged: (encoding) =>
                                        setState(() => _encoding = encoding),
                                  )
                                : XpComboBox<FileEncoding?>(
                                    semanticLabel: 'Encoding',
                                    options: [
                                      const XpOption(
                                        'Detect automatically',
                                        null,
                                      ),
                                      for (final encoding
                                          in FileEncoding.values)
                                        XpOption(encoding.label, encoding),
                                    ],
                                    value: _openAs,
                                    onChanged: (encoding) =>
                                        setState(() => _openAs = encoding),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    XpButton(
                      label: _isSave ? 'Save' : 'Open',
                      isDefault: true,
                      onPressed: () => unawaited(_submit()),
                    ),
                    const SizedBox(height: 6),
                    XpButton(label: 'Cancel', onPressed: _cancel),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The XP file list: a header with the four columns and a lazily built list of rows.
class _FileList extends StatefulWidget {
  const _FileList({
    required this.entries,
    required this.problem,
    required this.selected,
    required this.height,
    required this.onSelect,
    required this.onActivate,
  });

  final List<DirectoryEntry> entries;

  /// Shown in place of the rows when the folder could not be listed.
  final String? problem;
  final int? selected;
  final double height;
  final ValueChanged<int> onSelect;
  final ValueChanged<DirectoryEntry> onActivate;

  @override
  State<_FileList> createState() => _FileListState();
}

class _FileListState extends State<_FileList> {
  static const _sizeWidth = 58.0;
  static const _typeWidth = 100.0;
  static const _dateWidth = 124.0;
  static const _rowHeight = 16.0;

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime moment) {
    final hour = moment.hour % 12 == 0 ? 12 : moment.hour % 12;
    final minute = moment.minute.toString().padLeft(2, '0');
    final period = moment.hour < 12 ? 'AM' : 'PM';
    return '${moment.month}/${moment.day}/${moment.year} $hour:$minute $period';
  }

  static String _typeOf(DirectoryEntry entry) {
    if (entry.isDirectory) return 'File Folder';
    return p.extension(entry.name).toLowerCase() == '.txt'
        ? 'Text Document'
        : 'File';
  }

  static String _sizeOf(DirectoryEntry entry) {
    if (entry.isDirectory) return '';
    return '${(entry.size / 1024).ceil()} KB';
  }

  @override
  Widget build(BuildContext context) {
    // The border and padding take 4 logical pixels. The bar is shown only when the rows
    // do not fit, as in XP.
    final overflows = widget.entries.length * _rowHeight > widget.height - 4;
    final problem = widget.problem;
    return SizedBox(
      height: widget.height + 18,
      child: Column(
        children: [
          _header(),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: XpColors.paper,
                border: Border.all(color: XpColors.editBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: problem != null
                    ? Center(
                        child: Text(
                          problem,
                          textAlign: TextAlign.center,
                          style: XpText.ui(color: XpColors.grayText),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              controller: _scroll,
                              itemExtent: _rowHeight,
                              itemCount: widget.entries.length,
                              itemBuilder: (context, index) => _row(index),
                            ),
                          ),
                          if (overflows)
                            XpScrollBar(
                              controller: _scroll,
                              axis: Axis.vertical,
                              lineStep: _rowHeight,
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 18,
      color: XpColors.face,
      child: Row(
        children: [
          Expanded(child: _cell('Name', XpColors.text)),
          SizedBox(width: _sizeWidth, child: _cell('Size', XpColors.text)),
          SizedBox(width: _typeWidth, child: _cell('Type', XpColors.text)),
          SizedBox(
            width: _dateWidth,
            child: _cell('Date Modified', XpColors.text),
          ),
          const SizedBox(width: XpMetrics.scrollbar),
        ],
      ),
    );
  }

  Widget _cell(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: XpText.ui(color: color),
        ),
      ),
    );
  }

  Widget _row(int index) {
    final entry = widget.entries[index];
    final selected = widget.selected == index;
    final color = selected ? XpColors.highlightText : XpColors.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Select on tap-down, so a single click does not wait out the double-click window.
      onTapDown: (_) => widget.onSelect(index),
      onDoubleTap: () => widget.onActivate(entry),
      child: Container(
        color: selected ? XpColors.highlight : null,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Row(
                  children: [
                    CustomPaint(
                      size: const Size.square(16),
                      painter: entry.isDirectory
                          ? const FolderIconPainter()
                          : const DocumentIconPainter(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: XpText.ui(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: _sizeWidth,
              child: Text(
                _sizeOf(entry),
                maxLines: 1,
                style: XpText.ui(color: color),
              ),
            ),
            SizedBox(
              width: _typeWidth,
              child: Text(
                _typeOf(entry),
                maxLines: 1,
                style: XpText.ui(color: color),
              ),
            ),
            SizedBox(
              width: _dateWidth,
              child: Text(
                _formatDate(entry.modified),
                maxLines: 1,
                style: XpText.ui(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
