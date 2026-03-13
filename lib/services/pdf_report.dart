import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../db/database.dart';

class PdfReportService {
  static Future<void> printPnL(
    Map<String, double> pnl,
    DateTime from,
    DateTime to,
    Company company,
  ) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fmt = NumberFormat('#,##0.00', 'ru_RU');
    final dateFmt = DateFormat('dd.MM.yyyy');

    final income = pnl.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final expense = pnl.entries.where((e) => e.value < 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final totalIncome = income.fold(0.0, (s, e) => s + e.value);
    final totalExpense = expense.fold(0.0, (s, e) => s + e.value.abs());
    final profit = totalIncome - totalExpense;

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            pw.Text(
              company.name,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Отчёт о прибылях и убытках (P&L)',
              style: const pw.TextStyle(fontSize: 12),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${dateFmt.format(from)} — ${dateFmt.format(to)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
            pw.Divider(height: 20, color: PdfColors.grey400),

            // ── Summary row ─────────────────────────────────────────────────
            pw.Row(
              children: [
                _summaryBox('Доходы', fmt.format(totalIncome), PdfColors.green800),
                pw.SizedBox(width: 10),
                _summaryBox('Расходы', fmt.format(totalExpense), PdfColors.red800),
                pw.SizedBox(width: 10),
                _summaryBox(
                  'Прибыль',
                  fmt.format(profit),
                  profit >= 0 ? PdfColors.blue800 : PdfColors.deepOrange,
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── Table ────────────────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th('Категория', left: true),
                    _th('Доход'),
                    _th('Расход'),
                  ],
                ),
                // Income rows
                ...income.map((e) => pw.TableRow(children: [
                      _td(e.key, left: true),
                      _td(fmt.format(e.value), color: PdfColors.green800),
                      _td(''),
                    ])),
                // Expense rows
                ...expense.map((e) => pw.TableRow(children: [
                      _td(e.key, left: true),
                      _td(''),
                      _td(fmt.format(e.value.abs()), color: PdfColors.red800),
                    ])),
                // Totals row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _td('Итого', bold: true, left: true),
                    _td(fmt.format(totalIncome), bold: true, color: PdfColors.green800),
                    _td(fmt.format(totalExpense), bold: true, color: PdfColors.red800),
                  ],
                ),
                // Profit row
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: profit >= 0 ? PdfColors.lightBlue50 : PdfColors.deepOrange50,
                  ),
                  children: [
                    _td('Чистая прибыль', bold: true, left: true),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: pw.Text(
                        fmt.format(profit),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: profit >= 0 ? PdfColors.blue800 : PdfColors.deepOrange,
                        ),
                      ),
                    ),
                    _td(''),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  static Future<void> printPayroll(
    List<PayrollRecord> records,
    Map<int, Employee> employeeMap,
    DateTime period,
    Company company,
    String sym,
  ) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fmt = NumberFormat('#,##0.##', 'ru_RU');
    final totalNet = records.fold(0.0, (s, r) => s + r.netAmount);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              company.name,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Ведомость заработной платы',
              style: const pw.TextStyle(fontSize: 12),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              DateFormat('LLLL yyyy', 'ru').format(period),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
            pw.Divider(height: 20, color: PdfColors.grey400),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th('Сотрудник', left: true),
                    _th('Оклад'),
                    _th('Бонус'),
                    _th('Вычет'),
                    _th('К выплате'),
                    _th('Статус'),
                  ],
                ),
                ...records.map((r) {
                  final name = employeeMap[r.employeeId]?.name ?? '?';
                  return pw.TableRow(children: [
                    _td(name, left: true),
                    _td('$sym ${fmt.format(r.baseSalary)}'),
                    _td(r.bonuses > 0 ? '+$sym ${fmt.format(r.bonuses)}' : '—',
                        color: r.bonuses > 0 ? PdfColors.green800 : PdfColors.grey600),
                    _td(r.deductions > 0 ? '-$sym ${fmt.format(r.deductions)}' : '—',
                        color: r.deductions > 0 ? PdfColors.red800 : PdfColors.grey600),
                    _td('$sym ${fmt.format(r.netAmount)}', bold: true),
                    _td(r.paidAt != null ? 'Выплачено' : 'Ожидает',
                        color: r.paidAt != null ? PdfColors.green800 : PdfColors.orange),
                  ]);
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _td('Итого', bold: true, left: true),
                    _td(''),
                    _td(''),
                    _td(''),
                    _td('$sym ${fmt.format(totalNet)}', bold: true),
                    _td(''),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static pw.Widget _summaryBox(String label, String value, PdfColor color) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.SizedBox(height: 3),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
            ],
          ),
        ),
      );

  static pw.Widget _th(String label, {bool left = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Text(
          label,
          textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800),
        ),
      );

  static pw.Widget _td(String value,
          {bool bold = false, bool left = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: pw.Text(
          value,
          textAlign: left ? pw.TextAlign.left : pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : null,
            color: color,
          ),
        ),
      );
}
