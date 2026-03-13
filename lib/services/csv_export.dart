import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../db/database.dart';

class CsvExport {
  static final _dateFmt = DateFormat('dd.MM.yyyy');
  static final _timeFmt = DateFormat('yyyyMMdd_HHmm');

  static Future<File> exportTransactions(
    List<Transaction> txs,
    Map<int, String> catMap,
    Map<int, String> accMap,
  ) async {
    final buf = StringBuffer('\uFEFF');
    buf.writeln('Дата,Тип,Счёт,Категория,Сумма,Описание');
    for (final tx in txs) {
      final type = switch (tx.type) {
        'income' => 'Доход',
        'expense' => 'Расход',
        _ => 'Перевод',
      };
      final cat = tx.categoryId != null ? (catMap[tx.categoryId!] ?? '') : '';
      final acc = accMap[tx.accountId] ?? '';
      buf.writeln(
        '${_dateFmt.format(tx.date)},$type,${_esc(acc)},${_esc(cat)},${tx.amount},${_esc(tx.description ?? '')}',
      );
    }
    return _save('transactions', buf.toString());
  }

  static Future<File> exportPnL(
    Map<String, double> data,
    DateTime from,
    DateTime to,
  ) async {
    final buf = StringBuffer('\uFEFF');
    buf.writeln('Категория,Сумма');
    for (final e in data.entries) {
      buf.writeln('${_esc(e.key)},${e.value}');
    }
    return _save(
      'pnl_${_dateFmt.format(from)}_${_dateFmt.format(to)}',
      buf.toString(),
    );
  }

  static Future<File> exportInvoices(List<Invoice> invoices) async {
    const statusLabels = {
      'pending': 'Ожидает',
      'partial': 'Частично',
      'paid': 'Оплачен',
      'cancelled': 'Отменён',
    };
    final buf = StringBuffer('\uFEFF');
    buf.writeln('Клиент,Сумма,Валюта,Статус,Срок оплаты,Описание');
    for (final inv in invoices) {
      final status = statusLabels[inv.status] ?? inv.status;
      final due = inv.dueDate != null ? _dateFmt.format(inv.dueDate!) : '';
      buf.writeln(
        '${_esc(inv.clientName)},${inv.totalAmount},${inv.currency},$status,$due,${_esc(inv.description ?? '')}',
      );
    }
    return _save('invoices', buf.toString());
  }

  static Future<File> exportPayroll(
    List<PayrollRecord> records,
    Map<int, Employee> empMap,
    DateTime period,
  ) async {
    final buf = StringBuffer('\uFEFF');
    buf.writeln('Сотрудник,Оклад,Бонус,Вычет,Итого,Статус,Период,Примечание');
    for (final r in records) {
      final name = empMap[r.employeeId]?.name ?? '?';
      final status = r.paidAt != null ? 'Выплачено' : 'Ожидает';
      final per = DateFormat('yyyy-MM').format(r.period);
      buf.writeln(
        '${_esc(name)},${r.baseSalary},${r.bonuses},${r.deductions},${r.netAmount},${_esc(status)},${_esc(per)},${_esc(r.notes ?? '')}',
      );
    }
    return _save('payroll_${_timeFmt.format(period)}', buf.toString());
  }

  static String _esc(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static Future<File> _save(String name, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = _timeFmt.format(DateTime.now());
    final file = File('${dir.path}/${name}_$ts.csv');
    await file.writeAsBytes(utf8.encode(content));
    return file;
  }
}
