import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/domain/text/text_search.dart';
import 'package:xp_notepad/ui/core/xp_status_bar.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';

import '../support/fakes.dart';

/// F-15: the interface used to expose nothing to a screen reader. These tests read the
/// semantics tree the way an assistive technology does, so a control that loses its name,
/// role or state fails here. They cannot replace a trial with a real screen reader.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async =>
              call.method == 'Clipboard.getData' ? {'text': ''} : null,
        );
  });

  /// A widget test with semantics switched on. The handle must be released inside the test,
  /// before the framework's end-of-test checks, so a teardown would be too late.
  void semantic(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await body(tester);
      } finally {
        handle.dispose();
      }
    });
  }

  Future<NotepadViewModel> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(600, 404)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      XpNotepadApp(
        dependencies: AppDependencies(
          documents: FakeDocumentRepository(),
          settings: FakeSettingsRepository(),
          fileSystem: FakeFileSystemService(),
          printing: FakePrintingService(),
          window: FakeWindowService(),
        ),
        settings: const NotepadSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();
    return Provider.of<NotepadViewModel>(
      tester.element(find.byType(NotepadScreen)),
      listen: false,
    );
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Every node of the semantics tree, walked from the root as an assistive technology
  /// would. `find.bySemanticsLabel` is not used because it also sees nodes that were
  /// dropped from the tree, such as the ones a modal dialog hides.
  List<SemanticsNode> allNodes(WidgetTester tester) {
    final nodes = <SemanticsNode>[];
    void visit(SemanticsNode node) {
      nodes.add(node);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(tester.binding.renderViews.first.debugSemantics!);
    return nodes;
  }

  /// The first node in the tree whose label is exactly [label].
  SemanticsNode node(WidgetTester tester, String label) {
    return allNodes(tester).firstWhere(
      (n) => n.getSemanticsData().label == label,
      orElse: () => fail('No node is labelled "$label"'),
    );
  }

  /// True when some node's label is exactly [label], or matches it when it is a RegExp.
  bool has(WidgetTester tester, Pattern label) {
    return allNodes(tester).any((n) {
      final text = n.getSemanticsData().label;
      return label is RegExp ? label.hasMatch(text) : text == label;
    });
  }

  group('the window', () {
    semantic('the caption buttons are named buttons', (tester) async {
      await pump(tester);

      for (final name in ['Minimize', 'Maximize', 'Close']) {
        expect(
          node(tester, name),
          isSemantics(isButton: true, hasTapAction: true),
          reason: name,
        );
      }
    });

    semantic('the menu bar names its menus as menu items', (tester) async {
      await pump(tester);

      for (final name in ['File', 'Edit', 'Format', 'View', 'Help']) {
        expect(
          node(tester, name),
          isSemantics(role: SemanticsRole.menuItem, hasTapAction: true),
          reason: name,
        );
      }
    });

    semantic('the menu bar says which menu is open', (tester) async {
      final vm = await pump(tester);

      expect(
        node(tester, 'File'),
        isSemantics(hasExpandedState: true, isExpanded: false),
      );
      vm.openMenuAt(0, byClick: true);
      await frames(tester);
      expect(
        node(tester, 'File'),
        isSemantics(hasExpandedState: true, isExpanded: true),
      );
      expect(
        node(tester, 'Save'),
        isSemantics(role: SemanticsRole.menuItem, hasTapAction: true),
      );
    });

    semantic('the text editor is named', (tester) async {
      await pump(tester);

      expect(has(tester, 'Text editor'), isTrue);
      expect(
        node(tester, 'Text editor'),
        isSemantics(isTextField: true, isMultiline: true),
      );
    });

    semantic('the status bar has the status role', (tester) async {
      final vm = await pump(tester);
      // Word wrap is on by default, which hides the bar. Turning it off shows the bar.
      vm.toggleWordWrap();
      await frames(tester);

      expect(
        tester.getSemantics(find.byType(XpStatusBar)),
        isSemantics(role: SemanticsRole.status),
      );
      expect(has(tester, RegExp('Ln 1, Col 1')), isTrue);
    });
  });

  group('menus', () {
    semantic('a menu item says its shortcut and whether it is available', (
      tester,
    ) async {
      final vm = await pump(tester);
      vm.openMenuAt(0, byClick: true);
      await frames(tester);

      expect(
        node(tester, 'New'),
        isSemantics(
          role: SemanticsRole.menuItem,
          hint: 'Ctrl+N',
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      vm.closeMenu();
      vm.openMenuAt(1, byClick: true);
      await frames(tester);
      // Nothing is selected, so Cut is unavailable.
      expect(
        node(tester, 'Cut'),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
    });

    semantic(
      'a check item announces its state, and the state follows the setting',
      (tester) async {
        final vm = await pump(tester);
        vm.openMenuAt(2, byClick: true);
        await frames(tester);

        expect(
          node(tester, 'Word Wrap'),
          isSemantics(
            role: SemanticsRole.menuItemCheckbox,
            hasCheckedState: true,
            isChecked: true,
          ),
        );

        vm.toggleWordWrap();
        await frames(tester);
        expect(
          node(tester, 'Word Wrap'),
          isSemantics(hasCheckedState: true, isChecked: false),
        );
      },
    );

    semantic('an item that is not a check item is not announced as one', (
      tester,
    ) async {
      final vm = await pump(tester);
      vm.openMenuAt(2, byClick: true);
      await frames(tester);

      expect(
        node(tester, 'Font...'),
        isSemantics(role: SemanticsRole.menuItem, hasCheckedState: false),
      );
    });
  });

  group('dialogs', () {
    semantic(
      'a dialog is announced by its title, and its fields and buttons are named',
      (tester) async {
        final vm = await pump(tester);
        unawaited(vm.showGoTo());
        await frames(tester);

        expect(
          node(tester, 'Go To Line'),
          isSemantics(
            role: SemanticsRole.dialog,
            namesRoute: true,
            scopesRoute: true,
          ),
        );
        expect(node(tester, 'Line number'), isSemantics(isTextField: true));
        for (final name in ['Go To', 'Cancel']) {
          expect(
            node(tester, name),
            isSemantics(isButton: true, hasTapAction: true),
            reason: name,
          );
        }
        vm.modal!.complete(null);
      },
    );

    semantic('a message box is an alert dialog with named buttons', (
      tester,
    ) async {
      final vm = await pump(tester);
      vm.findNext(const SearchOptions(query: 'missing'));
      await frames(tester);

      expect(vm.modal, isNotNull);
      expect(
        node(tester, 'Notepad'),
        isSemantics(role: SemanticsRole.alertDialog, namesRoute: true),
      );
      expect(
        node(tester, 'OK'),
        isSemantics(isButton: true, hasTapAction: true),
      );
    });

    semantic('check boxes expose their label and state, and follow a click', (
      tester,
    ) async {
      final vm = await pump(tester);
      vm.showFind(replace: false);
      await frames(tester);

      expect(
        node(tester, 'Match case'),
        isSemantics(
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text('Match case'));
      await frames(tester);
      expect(
        node(tester, 'Match case'),
        isSemantics(hasCheckedState: true, isChecked: true),
      );
      expect(has(tester, 'Find what'), isTrue);
    });

    semantic('radio buttons expose their group and which one is chosen', (
      tester,
    ) async {
      final vm = await pump(tester);
      vm.showFind(replace: false);
      await frames(tester);

      expect(
        node(tester, 'Down'),
        isSemantics(
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      expect(
        node(tester, 'Up'),
        isSemantics(
          hasCheckedState: true,
          isChecked: false,
          isInMutuallyExclusiveGroup: true,
        ),
      );

      await tester.tap(find.text('Up'));
      await frames(tester);
      expect(node(tester, 'Up'), isSemantics(isChecked: true));
      expect(node(tester, 'Down'), isSemantics(isChecked: false));
    });

    semantic('the Font dialog names its lists, size box and script box', (
      tester,
    ) async {
      final vm = await pump(tester);
      unawaited(vm.showFont());
      await frames(tester);

      expect(has(tester, 'Font'), isTrue);
      expect(has(tester, 'Font style'), isTrue);
      expect(has(tester, 'Size'), isTrue);
      // The script box is a named button whose value is the script it shows.
      expect(
        node(tester, 'Script'),
        isSemantics(isButton: true, value: 'Western'),
      );
      // The chosen font is marked selected in its list.
      expect(
        node(tester, 'Lucida Console'),
        isSemantics(
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        node(tester, 'Arial'),
        isSemantics(hasSelectedState: true, isSelected: false),
      );
      vm.modal!.complete(null);
    });

    semantic('the Open dialog names its folder, type and file name controls', (
      tester,
    ) async {
      final vm = await pump(tester);
      unawaited(vm.openDocument());
      await frames(tester);

      expect(
        node(tester, 'Look in'),
        isSemantics(isButton: true, value: 'tester'),
      );
      expect(
        node(tester, 'Files of type'),
        isSemantics(isButton: true, value: 'Text Documents (*.txt)'),
      );
      expect(has(tester, 'File name'), isTrue);
      expect(node(tester, 'Open'), isSemantics(role: SemanticsRole.dialog));
      vm.modal!.complete(null);
    });

    semantic('the Page Setup fields are named', (tester) async {
      final vm = await pump(tester);
      unawaited(vm.editPageSetup());
      await frames(tester);

      for (final name in [
        'Header',
        'Footer',
        'Left margin',
        'Right margin',
        'Top margin',
        'Bottom margin',
      ]) {
        expect(has(tester, name), isTrue, reason: name);
      }
      vm.modal!.complete(null);
    });
  });

  group('what a screen reader can reach', () {
    semantic(
      'the buttons of a message box are separate, individually tappable nodes',
      (tester) async {
        final vm = await pump(tester);
        vm.text.value = const TextEditingValue(text: 'changed');
        unawaited(vm.newDocument());
        await frames(tester);

        // The Save changes box has three buttons. Merged into one node, a screen reader
        // could not tell which of them a tap would press.
        for (final name in ['Yes', 'No', 'Cancel']) {
          expect(
            node(tester, name),
            isSemantics(label: name, isButton: true, hasTapAction: true),
            reason: name,
          );
        }
        expect(
          has(tester, RegExp('Do you want to save the changes')),
          isTrue,
          reason: 'the question is its own node, not merged into a button',
        );
        vm.modal!.complete(MessageChoice.cancel);
        await frames(tester);
      },
    );

    semantic(
      'the window behind an open dialog is hidden from assistive technology',
      (tester) async {
        final vm = await pump(tester);
        expect(has(tester, 'File'), isTrue);
        expect(has(tester, 'Text editor'), isTrue);

        unawaited(vm.showAbout());
        await frames(tester);

        expect(has(tester, 'File'), isFalse);
        expect(has(tester, 'Text editor'), isFalse);
        expect(has(tester, 'About Notepad'), isTrue);

        vm.modal!.complete(true);
        await frames(tester);
        expect(has(tester, 'File'), isTrue);
      },
    );

    semantic('drag-only areas are not offered as scrollable nodes', (
      tester,
    ) async {
      await pump(tester);

      final scrollable = <SemanticsNode>[];
      void visit(SemanticsNode n) {
        final data = n.getSemanticsData();
        final scrolls =
            data.hasAction(SemanticsAction.scrollUp) ||
            data.hasAction(SemanticsAction.scrollDown);
        if (scrolls) scrollable.add(n);
        n.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(tester.getSemantics(find.byType(NotepadScreen)));
      // The editor is the one scrollable thing in the window. The caption, the eight
      // resize edges and the size grip are not.
      expect(scrollable.length, lessThanOrEqualTo(1), reason: '$scrollable');
    });
  });
}
