import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/domain/text/print_text.dart';
import 'package:xp_notepad/utils/result.dart';

/// Sends a document to the platform print dialog.
abstract interface class PrintingService {
  Future<Result<void>> printDocument({
    required String text,
    required String documentName,
    required PageSetup setup,
  });
}

/// Lays the text out as a PDF with the File > Page Setup margins, header and footer,
/// then hands it to the platform print dialog through the printing plugin.
class PdfPrintingService implements PrintingService {
  const PdfPrintingService();

  @override
  Future<Result<void>> printDocument({
    required String text,
    required String documentName,
    required PageSetup setup,
  }) async {
    // Margins that leave no room would make the PDF layout throw, so the defaults are used
    // for the margins. The header and footer still come from the setup.
    final usable = setup.marginProblem == null
        ? setup
        : setup.copyWith(
            leftInches: const PageSetup().leftInches,
            topInches: const PageSetup().topInches,
            rightInches: const PageSetup().rightInches,
            bottomInches: const PageSetup().bottomInches,
          );
    try {
      await Printing.layoutPdf(
        name: documentName,
        format: PdfPageFormat.letter,
        // Laying out a long document takes seconds, so it runs on its own isolate and the
        // window keeps responding.
        onLayout: (format) => Isolate.run(
          () => buildPdf(
            text: text,
            documentName: documentName,
            setup: usable,
            format: format,
          ),
        ),
      );
      return const Success<void>(null);
    } on Object catch (error, stack) {
      return Failure(error, stack);
    }
  }
}

/// Builds the PDF bytes. Pure Dart, so the layout can be checked without a printer.
/// [now] fills the `&d` and `&t` codes; it is a parameter so a test can fix it.
Future<Uint8List> buildPdf({
  required String text,
  required String documentName,
  required PageSetup setup,
  required PdfPageFormat format,
  DateTime? now,
}) async {
  const pointsPerInch = 72.0;
  final pageFormat = format.copyWith(
    marginLeft: setup.leftInches * pointsPerInch,
    marginRight: setup.rightInches * pointsPerInch,
    marginTop: setup.topInches * pointsPerInch,
    marginBottom: setup.bottomInches * pointsPerInch,
  );
  final moment = now ?? DateTime.now();
  final font = pw.Font.courier();
  final bodyStyle = pw.TextStyle(font: font, fontSize: 10);
  final noteStyle = pw.TextStyle(font: font, fontSize: 9);
  final lines = text.split('\n').map(expandTabs).toList();

  pw.Widget note(String template, int page) {
    final line = expandHeaderFooter(
      template,
      fileName: documentName,
      page: page,
      now: moment,
    );
    // The usual header, centred text only, spans the page. Left and right parts share
    // the width in thirds.
    if (line.left.isEmpty && line.right.isEmpty) {
      return pw.Text(
        line.center,
        style: noteStyle,
        textAlign: pw.TextAlign.center,
      );
    }
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            line.left,
            style: noteStyle,
            textAlign: pw.TextAlign.left,
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            line.center,
            style: noteStyle,
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            line.right,
            style: noteStyle,
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      header: (context) => note(setup.header, context.pageNumber),
      footer: (context) => note(setup.footer, context.pageNumber),
      build: (context) => [
        for (final line in lines)
          pw.Text(line.isEmpty ? ' ' : line, style: bodyStyle),
      ],
    ),
  );
  return document.save();
}
