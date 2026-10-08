import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
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
        onLayout: (format) => buildPdf(
          text: text,
          documentName: documentName,
          setup: usable,
          format: format,
        ),
      );
      return const Success<void>(null);
    } on Object catch (error, stack) {
      return Failure(error, stack);
    }
  }
}

/// Builds the PDF bytes. Pure Dart, so the layout can be checked without a printer.
Future<Uint8List> buildPdf({
  required String text,
  required String documentName,
  required PageSetup setup,
  required PdfPageFormat format,
}) async {
  const pointsPerInch = 72.0;
  final pageFormat = format.copyWith(
    marginLeft: setup.leftInches * pointsPerInch,
    marginRight: setup.rightInches * pointsPerInch,
    marginTop: setup.topInches * pointsPerInch,
    marginBottom: setup.bottomInches * pointsPerInch,
  );
  final font = pw.Font.courier();
  final bodyStyle = pw.TextStyle(font: font, fontSize: 10);
  final lines = text.replaceAll('\t', '    ').split('\n');
  final headerText = setup.header.replaceAll('&f', documentName);

  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      header: (context) => pw.Text(
        headerText,
        style: pw.TextStyle(font: font, fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
      footer: (context) => pw.Text(
        setup.footer.replaceAll('&p', '${context.pageNumber}'),
        style: pw.TextStyle(font: font, fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
      build: (context) => [
        for (final line in lines)
          pw.Text(line.isEmpty ? ' ' : line, style: bodyStyle),
      ],
    ),
  );
  return document.save();
}
