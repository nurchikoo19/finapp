import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../providers/database_provider.dart';
import '../../services/pdf_report.dart';
import '../../services/csv_export.dart';

String _sym(String code) {
  const m = {
    'KGS': 'с',
    'RUB': '₽',
    'USD': '\$',
    'EUR': '€',
    'KZT': '₸',
    'UZS': 'сўм',
  };
  return m[code] ?? code;
}

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  late DateTime _period;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = DateTime(now.year, now.month, 1);
  }

  Future<void> _exportCsv(
    BuildContext context,
    List<PayrollRecord> records,
    List<Employee> employees,
  ) async {
    try {
      final empMap = {for (final e in employees) e.id: e};
      final file = await CsvExport.exportPayroll(records, empMap, _period);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сохранено: ${file.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _printPayroll(
    BuildContext context,
    Company company,
    List<PayrollRecord> records,
    List<Employee> employees,
  ) async {
    try {
      final empMap = {for (final e in employees) e.id: e};
      await PdfReportService.printPayroll(
        records,
        empMap,
        _period,
        company,
        _sym(company.currency),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка PDF: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(selectedCompanyProvider);
    if (company == null) {
      return const Scaffold(body: Center(child: Text('Нет компании')));
    }

    final employeesAsync = ref.watch(employeesProvider);
    final payrollAsync = ref.watch(payrollProvider);

    return Scaffold(
      body: employeesAsync.when(
        data: (employees) {
          final payrollList = payrollAsync.valueOrNull ?? [];
          final periodPayroll = payrollList
              .where((r) =>
                  r.period.year == _period.year &&
                  r.period.month == _period.month)
              .toList();

          final totalNet =
              periodPayroll.fold(0.0, (s, r) => s + r.netAmount);
          final totalPaid =
              periodPayroll.where((r) => r.paidAt != null).fold(0.0, (s, r) => s + r.netAmount);
          final totalPending = totalNet - totalPaid;

          final fmt = NumberFormat.currency(
              locale: 'ru_RU',
              symbol: _sym(company.currency),
              decimalDigits: 0);

          return Column(
            children: [
              // Period selector
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() {
                      _period = DateTime(_period.year, _period.month - 1, 1);
                    }),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        DateFormat('LLLL yyyy', 'ru').format(_period),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() {
                      _period = DateTime(_period.year, _period.month + 1, 1);
                    }),
                  ),
                  if (periodPayroll.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.download_outlined),
                      tooltip: 'Экспорт CSV',
                      onPressed: () => _exportCsv(
                        context,
                        periodPayroll,
                        employees,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      tooltip: 'Выгрузить PDF',
                      onPressed: () => _printPayroll(
                        context,
                        company,
                        periodPayroll,
                        employees,
                      ),
                    ),
                  ],
                ]),
              ),

              // Summary card
              if (periodPayroll.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryItem(
                          label: 'Всего',
                          value: fmt.format(totalNet),
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _SummaryItem(
                          label: 'Выплачено',
                          value: fmt.format(totalPaid),
                          color: Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _SummaryItem(
                          label: 'Ожидает',
                          value: fmt.format(totalPending),
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),

              // Employee list
              Expanded(
                child: employees.isEmpty
                    ? const Center(child: Text('Нет сотрудников'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: employees.length,
                        itemBuilder: (ctx, i) {
                          final emp = employees[i];
                          final record = periodPayroll
                              .where((r) => r.employeeId == emp.id)
                              .firstOrNull;
                          return _EmployeePayrollCard(
                            employee: emp,
                            record: record,
                            period: _period,
                            companyId: company.id,
                            currency: company.currency,
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }
}

class _EmployeePayrollCard extends ConsumerWidget {
  final Employee employee;
  final PayrollRecord? record;
  final DateTime period;
  final int companyId;
  final String currency;

  const _EmployeePayrollCard({
    required this.employee,
    required this.record,
    required this.period,
    required this.companyId,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: _sym(currency), decimalDigits: 0);
    final hasRecord = record != null;
    final isPaid = record?.paidAt != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    Color(employee.color).withValues(alpha: 0.2),
                child: Text(
                  employee.name.isNotEmpty
                      ? employee.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: Color(employee.color),
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    if (employee.role != null)
                      Text(employee.role!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (hasRecord)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPaid ? 'Выплачено' : 'Не выплачено',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPaid
                            ? Colors.green.shade700
                            : Colors.orange.shade700),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            if (!hasRecord)
              Row(children: [
                Expanded(
                  child: Text('Не начислено',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[500])),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Начислить'),
                  onPressed: () => _showPayrollDialog(context, ref),
                ),
              ])
            else ...[
              Row(children: [
                _Chip(
                    label: 'Оклад',
                    value: fmt.format(record!.baseSalary),
                    color: Colors.blue),
                if (record!.bonuses > 0) ...[
                  const SizedBox(width: 6),
                  _Chip(
                      label: 'Бонус',
                      value: '+${fmt.format(record!.bonuses)}',
                      color: Colors.green),
                ],
                if (record!.deductions > 0) ...[
                  const SizedBox(width: 6),
                  _Chip(
                      label: 'Вычет',
                      value: '-${fmt.format(record!.deductions)}',
                      color: Colors.red),
                ],
                const Spacer(),
                Text(fmt.format(record!.netAmount),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              if (record!.notes != null && record!.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(record!.notes!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Изменить'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => _showPayrollDialog(context, ref),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Удалить'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Удалить начисление?'),
                      content: const Text(
                          'Запись о зарплате будет удалена.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Отмена')),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () async {
                            Navigator.pop(context);
                            await ref
                                .read(databaseProvider)
                                .deletePayroll(record!.id);
                          },
                          child: const Text('Удалить'),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  void _showPayrollDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _PayrollDialog(
        companyId: companyId,
        employee: employee,
        period: period,
        record: record,
        currency: currency,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Chip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _PayrollDialog extends ConsumerStatefulWidget {
  final int companyId;
  final Employee employee;
  final DateTime period;
  final PayrollRecord? record;
  final String currency;

  const _PayrollDialog({
    required this.companyId,
    required this.employee,
    required this.period,
    required this.record,
    required this.currency,
  });

  @override
  ConsumerState<_PayrollDialog> createState() => _PayrollDialogState();
}

class _PayrollDialogState extends ConsumerState<_PayrollDialog> {
  late final TextEditingController _salaryCtrl;
  late final TextEditingController _bonusCtrl;
  late final TextEditingController _deductCtrl;
  late final TextEditingController _notesCtrl;
  int? _accountId;
  bool _markPaid = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _salaryCtrl =
        TextEditingController(text: r != null ? r.baseSalary.toStringAsFixed(0) : '');
    _bonusCtrl = TextEditingController(
        text: r != null && r.bonuses > 0 ? r.bonuses.toStringAsFixed(0) : '');
    _deductCtrl = TextEditingController(
        text: r != null && r.deductions > 0
            ? r.deductions.toStringAsFixed(0)
            : '');
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
    _accountId = r?.accountId;
    _markPaid = r?.paidAt != null;
  }

  @override
  void dispose() {
    _salaryCtrl.dispose();
    _bonusCtrl.dispose();
    _deductCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final accounts = accountsAsync.valueOrNull ?? [];

    return AlertDialog(
      title: Text(widget.record == null
          ? 'Начислить зарплату: ${widget.employee.name}'
          : 'Редактировать: ${widget.employee.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _salaryCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                  labelText: 'Оклад *',
                  suffixText: _sym(widget.currency)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _bonusCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Бонус'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _deductCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Вычет'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (accounts.isNotEmpty)
              DropdownButtonFormField<int?>(
                initialValue: _accountId,
                decoration:
                    const InputDecoration(labelText: 'Списать со счёта (необязательно)'),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('Не выбрано')),
                  ...accounts.map((a) =>
                      DropdownMenuItem(value: a.id, child: Text(a.name))),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Отметить как выплачено'),
              value: _markPaid,
              onChanged: (v) => setState(() => _markPaid = v ?? false),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Примечание (необязательно)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  void _save() async {
    final base =
        double.tryParse(_salaryCtrl.text.replaceAll(' ', '').replaceAll(',', '.'));
    if (base == null || base <= 0) return;
    final bonuses =
        double.tryParse(_bonusCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;
    final deductions =
        double.tryParse(_deductCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;
    final net = base + bonuses - deductions;
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
    final paidAt = _markPaid ? DateTime.now() : null;
    final db = ref.read(databaseProvider);

    if (widget.record != null) {
      await db.deletePayroll(widget.record!.id);
    }

    await db.insertPayroll(PayrollRecordsCompanion.insert(
      companyId: widget.companyId,
      employeeId: widget.employee.id,
      period: widget.period,
      baseSalary: base,
      bonuses: Value(bonuses),
      deductions: Value(deductions),
      netAmount: net,
      accountId: Value(_accountId),
      paidAt: Value(paidAt),
      notes: Value(notes),
    ));

    if (mounted) Navigator.pop(context);
  }
}
