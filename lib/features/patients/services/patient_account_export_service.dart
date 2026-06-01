import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../utils/patient_account_utils.dart';

class PatientAccountExportService {
  const PatientAccountExportService._();

  static Future<void> exportPdf({
    required bool isArabic,
    required String patientId,
    required String patientName,
    required Map<String, dynamic> patientData,
    required List<QueryDocumentSnapshot> treatmentDocs,
    required List<QueryDocumentSnapshot> paymentDocs,
  }) async {
    final bytes = await _buildPatientPdfBytes(
      isArabic: isArabic,
      patientId: patientId,
      patientName: patientName,
      patientData: patientData,
      treatmentDocs: treatmentDocs,
      paymentDocs: paymentDocs,
    );

    _downloadBytes(
      bytes: bytes,
      fileName: PatientAccountUtils.exportFileName(
        patientName: patientName,
        extension: 'pdf',
      ),
      mimeType: 'application/pdf',
    );
  }

  static Future<void> exportExcel({
    required bool isArabic,
    required String patientId,
    required String patientName,
    required Map<String, dynamic> patientData,
    required List<QueryDocumentSnapshot> treatmentDocs,
    required List<QueryDocumentSnapshot> paymentDocs,
  }) async {
    final excel = xls.Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) excel.delete(defaultSheet);

    final summarySheet = excel[_tr(isArabic, 'ملخص المريض', 'Patient Summary')];
    final treatmentsSheet = excel[_tr(isArabic, 'المعالجات', 'Treatments')];
    final paymentsSheet = excel[_tr(isArabic, 'الدفعات', 'Payments')];

    final fileNumber = patientData['file_number']?.toString() ?? patientId;
    final req = PatientAccountUtils.toDouble(patientData['required_amount']);
    final disc = PatientAccountUtils.toDouble(patientData['discount']);
    final paid = PatientAccountUtils.toDouble(patientData['paid_amount']);
    final remaining = PatientAccountUtils.toDouble(patientData['remaining_amount']);

    _excelRow(summarySheet, [_tr(isArabic, 'تقرير ملف المريض', 'Patient Account Report')]);
    _excelRow(summarySheet, [
      _tr(isArabic, 'تاريخ التصدير', 'Export Date'),
      DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now()),
    ]);
    _excelRow(summarySheet, []);
    _excelRow(summarySheet, [_tr(isArabic, 'الاسم', 'Name'), patientName]);
    _excelRow(summarySheet, [_tr(isArabic, 'رقم الملف', 'File No.'), fileNumber]);
    _excelRow(summarySheet, [_tr(isArabic, 'الهاتف', 'Phone'), patientData['phone']?.toString() ?? '']);
    _excelRow(summarySheet, [_tr(isArabic, 'الجنس', 'Gender'), patientData['gender']?.toString() ?? '']);
    _excelRow(summarySheet, [_tr(isArabic, 'تاريخ الميلاد', 'Birth Date'), PatientAccountUtils.formatDate(patientData['birth_date'])]);
    _excelRow(summarySheet, [_tr(isArabic, 'التنبيهات', 'Alerts'), patientData['alert']?.toString() ?? '']);
    _excelRow(summarySheet, []);
    _excelRow(summarySheet, [_tr(isArabic, 'إجمالي المعالجات', 'Treatments'), req.toStringAsFixed(2)]);
    _excelRow(summarySheet, [_tr(isArabic, 'إجمالي الخصم', 'Discount'), disc.toStringAsFixed(2)]);
    _excelRow(summarySheet, [_tr(isArabic, 'إجمالي المدفوع', 'Paid'), paid.toStringAsFixed(2)]);
    _excelRow(summarySheet, [_tr(isArabic, 'الرصيد المتبقي', 'Remaining'), remaining.toStringAsFixed(2)]);

    _excelRow(treatmentsSheet, [
      _tr(isArabic, 'التاريخ', 'Date'),
      _tr(isArabic, 'التصنيف', 'Category'),
      _tr(isArabic, 'المعالجة', 'Treatment'),
      _tr(isArabic, 'السن', 'Tooth'),
      _tr(isArabic, 'العدد', 'Qty'),
      _tr(isArabic, 'السعر', 'Price'),
      _tr(isArabic, 'الخصم', 'Discount'),
      _tr(isArabic, 'الإجمالي', 'Total'),
    ]);

    for (final docSnap in treatmentDocs) {
      final data = docSnap.data() as Map<String, dynamic>;
      final price = PatientAccountUtils.toDouble(data['price']);
      final discount = PatientAccountUtils.toDouble(data['discount']);
      final qty = _quantityValue(data['quantity']);
      final total = (price * qty) - discount;
      final treatmentName = data['detail']?.toString().trim().isNotEmpty == true
          ? '${data['treatmentName'] ?? ''} - ${data['detail'] ?? ''}'
          : '${data['treatmentName'] ?? ''}';

      _excelRow(treatmentsSheet, [
        PatientAccountUtils.formatDate(data['date']),
        data['category']?.toString() ?? '',
        treatmentName,
        data['toothId']?.toString() ?? '',
        qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1),
        price.toStringAsFixed(2),
        discount.toStringAsFixed(2),
        total.toStringAsFixed(2),
      ]);
    }

    _excelRow(paymentsSheet, [
      _tr(isArabic, 'التاريخ', 'Date'),
      _tr(isArabic, 'المبلغ', 'Amount'),
      _tr(isArabic, 'الخصم', 'Discount'),
      _tr(isArabic, 'طريقة الدفع', 'Method'),
      _tr(isArabic, 'ملاحظة', 'Note'),
    ]);

    for (final docSnap in paymentDocs) {
      final data = docSnap.data() as Map<String, dynamic>;
      _excelRow(paymentsSheet, [
        PatientAccountUtils.formatDate(data['date']),
        PatientAccountUtils.toDouble(data['amount']).toStringAsFixed(2),
        PatientAccountUtils.toDouble(data['discount']).toStringAsFixed(2),
        PatientAccountUtils.paymentMethodLabel(
          isArabic: isArabic,
          method: data['method']?.toString() ?? '',
        ),
        data['note']?.toString() ?? '',
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel encode returned null');

    _downloadBytes(
      bytes: bytes,
      fileName: PatientAccountUtils.exportFileName(
        patientName: patientName,
        extension: 'xlsx',
      ),
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static Future<List<int>> _buildPatientPdfBytes({
    required bool isArabic,
    required String patientId,
    required String patientName,
    required Map<String, dynamic> patientData,
    required List<QueryDocumentSnapshot> treatmentDocs,
    required List<QueryDocumentSnapshot> paymentDocs,
  }) async {
    final doc = pw.Document();
    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    final textDirection = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final fileNumber = patientData['file_number']?.toString() ?? patientId;
    final phone = patientData['phone']?.toString() ?? '';
    final gender = patientData['gender']?.toString() ?? '';
    final birthDate = PatientAccountUtils.formatDate(patientData['birth_date']);
    final alert = patientData['alert']?.toString() ?? '';
    final req = PatientAccountUtils.toDouble(patientData['required_amount']);
    final disc = PatientAccountUtils.toDouble(patientData['discount']);
    final paid = PatientAccountUtils.toDouble(patientData['paid_amount']);
    final remaining = PatientAccountUtils.toDouble(patientData['remaining_amount']);

    pw.TextStyle style(double size, {bool bold = false, PdfColor? color}) {
      return pw.TextStyle(
        font: bold ? boldFont : regularFont,
        fontSize: size,
        color: color,
      );
    }

    pw.Widget title(String text) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#EAF2FB'),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          text,
          style: style(13, bold: true, color: PdfColors.blue800),
          textDirection: textDirection,
        ),
      );
    }

    pw.Widget keyValue(String label, String value) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 90,
              child: pw.Text(
                label,
                style: style(10, bold: true),
                textDirection: textDirection,
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value.isEmpty ? '—' : value,
                style: style(10),
                textDirection: textDirection,
              ),
            ),
          ],
        ),
      );
    }

    final treatmentRows = treatmentDocs.map((docSnap) {
      final data = docSnap.data() as Map<String, dynamic>;
      final price = PatientAccountUtils.toDouble(data['price']);
      final discount = PatientAccountUtils.toDouble(data['discount']);
      final qty = _quantityValue(data['quantity']);
      final total = (price * qty) - discount;
      final treatmentName = data['detail']?.toString().trim().isNotEmpty == true
          ? '${data['treatmentName'] ?? ''} - ${data['detail'] ?? ''}'
          : '${data['treatmentName'] ?? ''}';
      return [
        PatientAccountUtils.formatDate(data['date']),
        data['category']?.toString() ?? '',
        treatmentName,
        data['toothId']?.toString() ?? '',
        qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1),
        price.toStringAsFixed(2),
        discount.toStringAsFixed(2),
        total.toStringAsFixed(2),
      ];
    }).toList();

    final paymentRows = paymentDocs.map((docSnap) {
      final data = docSnap.data() as Map<String, dynamic>;
      return [
        PatientAccountUtils.formatDate(data['date']),
        PatientAccountUtils.toDouble(data['amount']).toStringAsFixed(2),
        PatientAccountUtils.toDouble(data['discount']).toStringAsFixed(2),
        PatientAccountUtils.paymentMethodLabel(
          isArabic: isArabic,
          method: data['method']?.toString() ?? '',
        ),
        data['note']?.toString() ?? '',
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        textDirection: textDirection,
        build: (context) => [
          pw.Directionality(
            textDirection: textDirection,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  _tr(isArabic, 'تقرير ملف المريض', 'Patient Account Report'),
                  style: style(20, bold: true, color: PdfColors.blue900),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now()),
                  style: style(9, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 18),
                title(_tr(isArabic, 'معلومات المريض', 'Patient Information')),
                pw.SizedBox(height: 8),
                keyValue(_tr(isArabic, 'الاسم', 'Name'), patientName),
                keyValue(_tr(isArabic, 'رقم الملف', 'File No.'), fileNumber),
                keyValue(_tr(isArabic, 'الهاتف', 'Phone'), phone),
                keyValue(_tr(isArabic, 'الجنس', 'Gender'), gender),
                keyValue(_tr(isArabic, 'تاريخ الميلاد', 'Birth Date'), birthDate),
                keyValue(_tr(isArabic, 'التنبيهات', 'Alerts'), alert),
                pw.SizedBox(height: 14),
                title(_tr(isArabic, 'الملخص المالي', 'Financial Summary')),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _pdfCell(_tr(isArabic, 'إجمالي المعالجات', 'Treatments'), style, textDirection, bold: true),
                        _pdfCell(_tr(isArabic, 'إجمالي الخصم', 'Discount'), style, textDirection, bold: true),
                        _pdfCell(_tr(isArabic, 'إجمالي المدفوع', 'Paid'), style, textDirection, bold: true),
                        _pdfCell(_tr(isArabic, 'الرصيد المتبقي', 'Remaining'), style, textDirection, bold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _pdfCell('${req.toStringAsFixed(2)} JD', style, textDirection),
                        _pdfCell('${disc.toStringAsFixed(2)} JD', style, textDirection),
                        _pdfCell('${paid.toStringAsFixed(2)} JD', style, textDirection),
                        _pdfCell('${remaining.toStringAsFixed(2)} JD', style, textDirection),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                title(_tr(isArabic, 'سجل المعالجات السريرية', 'Clinical Treatments Record')),
                pw.SizedBox(height: 8),
                _pdfTextTable(
                  emptyText: _tr(isArabic, 'لا توجد بيانات', 'No data'),
                  headers: [
                    _tr(isArabic, 'التاريخ', 'Date'),
                    _tr(isArabic, 'التصنيف', 'Category'),
                    _tr(isArabic, 'المعالجة', 'Treatment'),
                    _tr(isArabic, 'السن', 'Tooth'),
                    _tr(isArabic, 'العدد', 'Qty'),
                    _tr(isArabic, 'السعر', 'Price'),
                    _tr(isArabic, 'الخصم', 'Disc.'),
                    _tr(isArabic, 'الإجمالي', 'Total'),
                  ],
                  rows: treatmentRows,
                  styleBuilder: style,
                  textDirection: textDirection,
                ),
                pw.SizedBox(height: 14),
                title(_tr(isArabic, 'سجل الدفعات', 'Payments Record')),
                pw.SizedBox(height: 8),
                _pdfTextTable(
                  emptyText: _tr(isArabic, 'لا توجد بيانات', 'No data'),
                  headers: [
                    _tr(isArabic, 'التاريخ', 'Date'),
                    _tr(isArabic, 'المبلغ', 'Amount'),
                    _tr(isArabic, 'الخصم', 'Discount'),
                    _tr(isArabic, 'الطريقة', 'Method'),
                    _tr(isArabic, 'ملاحظة', 'Note'),
                  ],
                  rows: paymentRows,
                  styleBuilder: style,
                  textDirection: textDirection,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfCell(
    String text,
    pw.TextStyle Function(double size, {bool bold, PdfColor? color}) styleBuilder,
    pw.TextDirection textDirection, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: styleBuilder(8.5, bold: bold),
        textDirection: textDirection,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _pdfTextTable({
    required String emptyText,
    required List<String> headers,
    required List<List<String>> rows,
    required pw.TextStyle Function(double size, {bool bold, PdfColor? color}) styleBuilder,
    required pw.TextDirection textDirection,
  }) {
    if (rows.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
        child: pw.Text(
          emptyText,
          style: styleBuilder(10),
          textDirection: textDirection,
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers
              .map((h) => _pdfCell(h, styleBuilder, textDirection, bold: true))
              .toList(),
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: row
                .map((cell) => _pdfCell(cell, styleBuilder, textDirection))
                .toList(),
          ),
        ),
      ],
    );
  }

  static void _downloadBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none'
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static void _excelRow(xls.Sheet sheet, List<String> values) {
    sheet.appendRow(values.map((value) => xls.TextCellValue(value)).toList());
  }

  static double _quantityValue(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 1.0;
  }

  static String _tr(bool isArabic, String ar, String en) {
    return PatientAccountUtils.tr(isArabic, ar, en);
  }
}
