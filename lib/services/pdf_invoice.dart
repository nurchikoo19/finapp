import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../db/database.dart';
import '../utils/num_to_words.dart';

class PdfInvoiceService {
  static const _monthsRu = [
    '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  static String _dateRu(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthsRu[d.month]} ${d.year} г.';

  static Future<void> printInvoice(
    Invoice invoice,
    List<InvoicePayment> payments,
    List<InvoiceItem> items, {
    Company? company,
    // Section 1 overrides
    String? sellerName,
    String? sellerInn,
    String? sellerAddress,
    String? sellerBankDetails,
    // Section 7 overrides
    String? signerSeller,
    String? signerBuyer,
  }) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fmt = NumberFormat('#,##0.00', 'ru_RU');

    // Compute totals
    double subtotal = 0;
    double vatTotal = 0;
    if (items.isNotEmpty) {
      for (final it in items) {
        final lineSubtotal = it.qty * it.unitPrice;
        final lineVat = lineSubtotal * it.vatRate / 100;
        subtotal += lineSubtotal;
        vatTotal += lineVat;
      }
    } else {
      subtotal = invoice.totalAmount;
    }
    final grandTotal = subtotal + vatTotal;

    // Padded invoice number
    final invNum = invoice.invoiceNumber != null && invoice.invoiceNumber!.isNotEmpty
        ? invoice.invoiceNumber!.padLeft(8, '0')
        : invoice.id.toString().padLeft(8, '0');

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Section 1: Company header (centered) ──────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                  top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    [
                      if ((sellerName ?? company?.name ?? '').isNotEmpty)
                        sellerName ?? company!.name,
                      if ((sellerInn ?? company?.inn ?? '').isNotEmpty)
                        'ИНН ${sellerInn ?? company!.inn}',
                    ].join(', '),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  if ((sellerAddress ?? company?.address ?? '').isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      sellerAddress ?? company!.address!,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                  if ((sellerBankDetails ?? company?.bankDetails ?? '').isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      sellerBankDetails ?? company!.bankDetails!,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // ── Section 2: Title row ───────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Счет на оплату № $invNum',
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  _dateRu(invoice.createdAt),
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey800),
                ),
              ],
            ),
            pw.Divider(height: 8, color: PdfColors.grey400),

            // ── Section 3: Buyer row ───────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    [
                      invoice.clientName,
                      if (invoice.clientDetails != null &&
                          invoice.clientDetails!.isNotEmpty)
                        'ИНН: ${invoice.clientDetails}',
                    ].join('  '),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Text(
                  invoice.dueDate != null
                      ? 'Дата оплаты: ${DateFormat('dd.MM.yy').format(invoice.dueDate!)}'
                      : '',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // ── Section 4: Items table ─────────────────────────────────────
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(18),   // №
                1: const pw.FlexColumnWidth(4),      // Наименование
                2: const pw.FixedColumnWidth(36),    // Ед.изм.
                3: const pw.FixedColumnWidth(36),    // Кол-во
                4: const pw.FixedColumnWidth(60),    // Цена без НДС
                5: const pw.FixedColumnWidth(64),    // Сумма без НДС
                6: const pw.FixedColumnWidth(44),    // Ставка НДС %
                7: const pw.FixedColumnWidth(54),    // Сумма НДС
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th('№'),
                    _th('Наименование услуги', align: pw.TextAlign.left),
                    _th('Ед.\nизм.'),
                    _th('Кол-\nво'),
                    _th('Цена без\nНДС'),
                    _th('Сумма\nбез НДС'),
                    _th('Ставка\nНДС %'),
                    _th('Сумма\nНДС'),
                  ],
                ),
                // Data rows (or one empty row if no items)
                if (items.isEmpty)
                  pw.TableRow(children: List.generate(8, (_) => _td('')))
                else
                  ...items.asMap().entries.map((e) {
                    final i = e.key;
                    final it = e.value;
                    final lineSub = it.qty * it.unitPrice;
                    final lineVat = lineSub * it.vatRate / 100;
                    return pw.TableRow(children: [
                      _td('${i + 1}'),
                      _td(it.description, align: pw.TextAlign.left),
                      _td(it.unit),
                      _td(_fmtQty(it.qty)),
                      _td(fmt.format(it.unitPrice)),
                      _td(fmt.format(lineSub)),
                      _td(it.vatRate > 0 ? '${it.vatRate.toInt()}' : '0'),
                      _td(lineVat > 0 ? fmt.format(lineVat) : '0,00'),
                    ]);
                  }),
              ],
            ),
            pw.SizedBox(height: 6),

            // ── Section 5: Totals block (right-aligned) ───────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _totalLine('Итого без НДС:', fmt.format(subtotal)),
                    _totalLine('Итого НДС:', fmt.format(vatTotal)),
                    _totalLine(
                      'Итого к оплате:',
                      '${fmt.format(grandTotal)} ${invoice.currency}',
                      bold: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400, height: 6),

            // ── Section 6: Amount in words ────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
                ),
              ),
              child: pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(
                    text: 'К оплате: ',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.TextSpan(
                    text: numToWordsSom(grandTotal),
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey800),
                  ),
                ]),
              ),
            ),
            pw.SizedBox(height: 16),

            // ── Section 7: Signature lines ────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _signatureLine('Отпустил', name: signerSeller),
                pw.Text('М.П.',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                _signatureLine('Получил', name: signerBuyer),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static pw.Widget _th(String label,
          {pw.TextAlign align = pw.TextAlign.center}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: pw.Text(label,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800)),
      );

  static pw.Widget _td(String value,
          {pw.TextAlign align = pw.TextAlign.center}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Text(value,
            textAlign: align,
            style: const pw.TextStyle(fontSize: 9)),
      );

  static pw.Widget _totalLine(String label, String value,
          {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 160,
            child: pw.Text(label,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: bold ? pw.FontWeight.bold : null,
                    color: PdfColors.grey800)),
          ),
          pw.SizedBox(width: 10),
          pw.SizedBox(
            width: 100,
            child: pw.Text(value,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: bold ? 11 : 10,
                    fontWeight: bold ? pw.FontWeight.bold : null)),
          ),
        ]),
      );

  static pw.Widget _signatureLine(String label, {String? name}) =>
      pw.Row(children: [
        pw.Text('$label ', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(
          width: 160,
          child: pw.Container(
            alignment: pw.Alignment.bottomCenter,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
              ),
            ),
            height: 14,
            child: name != null && name.isNotEmpty
                ? pw.Text(name,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9))
                : null,
          ),
        ),
      ]);

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
}
