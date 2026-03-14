import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../providers/database_provider.dart';
import '../../services/csv_export.dart';
import '../../services/pdf_report.dart';

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

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(selectedCompanyProvider);

    return Column(
      children: [
        // Period selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('dd.MM.yyyy').format(_from)} — ${DateFormat('dd.MM.yyyy').format(_to)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              TextButton(
                onPressed: _pickPeriod,
                child: const Text('Изменить'),
              ),
              if (company != null) ...[
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Экспорт P&L в CSV',
                  onPressed: () => _exportPnL(context, company.id),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Печать P&L',
                  onPressed: () => _printPnL(context, company),
                ),
              ],
            ],
          ),
        ),
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'P&L'),
            Tab(text: 'EBITDA'),
            Tab(text: 'Безубыточность'),
            Tab(text: 'Прогноз'),
            Tab(text: 'Бюджет'),
            Tab(text: 'Налоги'),
            Tab(text: 'Дебиторка'),
          ],
        ),
        Expanded(
          child: company == null
              ? const Center(child: Text('Нет компании'))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _PnLTab(companyId: company.id, from: _from, to: _to, currency: company.currency),
                    _EbitdaTab(companyId: company.id, from: _from, to: _to, currency: company.currency),
                    _BreakevenTab(companyId: company.id, from: _from, to: _to, currency: company.currency),
                    _CashFlowTab(companyId: company.id, currency: company.currency),
                    _BudgetTab(companyId: company.id, from: _from, to: _to, currency: company.currency),
                    _TaxTab(companyId: company.id, from: _from, to: _to, currency: company.currency),
                    _ArAgingTab(companyId: company.id, currency: company.currency),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _exportPnL(BuildContext context, int companyId) async {
    try {
      final db = ref.read(databaseProvider);
      final data = await db.getPnLByCategory(companyId, _from, _to);
      final file = await CsvExport.exportPnL(data, _from, _to);
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

  Future<void> _printPnL(BuildContext context, Company company) async {
    try {
      final db = ref.read(databaseProvider);
      final data = await db.getPnLByCategory(company.id, _from, _to);
      await PdfReportService.printPnL(data, _from, _to, company);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }
}

class _PnLTab extends ConsumerWidget {
  final int companyId;
  final DateTime from;
  final DateTime to;
  final String currency;

  const _PnLTab({required this.companyId, required this.from, required this.to, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final fmt = NumberFormat.currency(locale: 'ru_RU', symbol: _sym(currency), decimalDigits: 0);

    return FutureBuilder<Map<String, double>>(
      future: db.getPnLByCategory(companyId, from, to),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        final income = data.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final expense = data.entries.where((e) => e.value < 0).toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        final totalIncome = income.fold(0.0, (s, e) => s + e.value);
        final totalExpense = expense.fold(0.0, (s, e) => s + e.value.abs());
        final profit = totalIncome - totalExpense;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary
              Row(
                children: [
                  Expanded(
                    child: _ReportCard(
                      label: 'Доходы',
                      value: fmt.format(totalIncome),
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ReportCard(
                      label: 'Расходы',
                      value: fmt.format(totalExpense),
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ReportCard(
                      label: 'Прибыль',
                      value: fmt.format(profit),
                      color: profit >= 0 ? Colors.blue : Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (income.isNotEmpty) ...[
                Text('Доходы по категориям',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 8),
                ...income.map((e) => _CategoryRow(
                      name: e.key,
                      amount: e.value,
                      total: totalIncome,
                      color: Colors.green,
                      currency: currency,
                    )),
              ],

              if (expense.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Расходы по категориям',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 8),
                ...expense.map((e) => _CategoryRow(
                      name: e.key,
                      amount: e.value.abs(),
                      total: totalExpense,
                      color: Colors.red,
                      currency: currency,
                    )),
              ],

              // Pie chart
              if (expense.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Структура расходов',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: _ExpensePieChart(
                    data: {
                      for (final e in expense) e.key: e.value.abs()
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EbitdaTab extends ConsumerWidget {
  final int companyId;
  final DateTime from;
  final DateTime to;
  final String currency;

  const _EbitdaTab({required this.companyId, required this.from, required this.to, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final fmt = NumberFormat.currency(locale: 'ru_RU', symbol: _sym(currency), decimalDigits: 0);

    return FutureBuilder<double>(
      future: db.getEBITDA(companyId, from, to),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final ebitda = snap.data!;
        return FutureBuilder<Map<String, double>>(
          future: db.getPnLByCategory(companyId, from, to),
          builder: (context, pnlSnap) {
            if (!pnlSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final pnl = pnlSnap.data!;
            final totalIncome = pnl.values.where((v) => v > 0).fold(0.0, (s, v) => s + v);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReportCard(
                    label: 'EBITDA',
                    value: fmt.format(ebitda),
                    color: ebitda >= 0 ? Colors.blue : Colors.red,
                    subtitle: totalIncome > 0
                        ? 'Маржа: ${(ebitda / totalIncome * 100).toStringAsFixed(1)}%'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.blue.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Как рассчитывается EBITDA?',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'EBITDA = Доходы − Переменные расходы\n'
                            'Фиксированные расходы (аренда, зарплата и т.д.) '
                            'исключены из расчёта. Отметьте транзакции как '
                            '"постоянный расход" при добавлении.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BreakevenTab extends ConsumerWidget {
  final int companyId;
  final DateTime from;
  final DateTime to;
  final String currency;

  const _BreakevenTab({
    required this.companyId,
    required this.from,
    required this.to,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final fmt = NumberFormat.currency(locale: 'ru_RU', symbol: _sym(currency), decimalDigits: 0);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        db.getTransactionsByCompany(companyId, from: from, to: to),
        db.getPnLByCategory(companyId, from, to),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final txs = snap.data![0] as List;
        // pnl data reserved for future category breakdown
        snap.data![1] as Map<String, double>;

        double fixedCosts = 0;
        double variableCosts = 0;
        double totalRevenue = 0;

        for (final tx in txs) {
          if (tx.type == 'income') {
            totalRevenue += tx.amount as double;
          } else if (tx.type == 'expense') {
            if (tx.isFixed as bool) {
              fixedCosts += tx.amount as double;
            } else {
              variableCosts += tx.amount as double;
            }
          }
        }

        final grossMargin = totalRevenue > 0
            ? (totalRevenue - variableCosts) / totalRevenue
            : 0.0;
        final breakeven = grossMargin > 0 ? fixedCosts / grossMargin : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ReportCard(
                      label: 'Постоянные расходы',
                      value: fmt.format(fixedCosts),
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ReportCard(
                      label: 'Переменные расходы',
                      value: fmt.format(variableCosts),
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ReportCard(
                      label: 'Валовая маржа',
                      value: '${(grossMargin * 100).toStringAsFixed(1)}%',
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ReportCard(
                      label: 'Точка безубыточности',
                      value: fmt.format(breakeven),
                      color: breakeven <= totalRevenue ? Colors.green : Colors.red,
                      subtitle: totalRevenue > 0
                          ? 'Текущая выручка: ${fmt.format(totalRevenue)}'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: breakeven <= totalRevenue
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        breakeven <= totalRevenue
                            ? Icons.check_circle
                            : Icons.warning,
                        color: breakeven <= totalRevenue
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          breakeven <= totalRevenue
                              ? 'Выручка превышает точку безубыточности на ${fmt.format(totalRevenue - breakeven)}'
                              : 'До точки безубыточности не хватает ${fmt.format(breakeven - totalRevenue)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  const _ReportCard({
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String name;
  final double amount;
  final double total;
  final Color color;
  final String currency;

  const _CategoryRow({
    required this.name,
    required this.amount,
    required this.total,
    required this.color,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: _sym(currency), decimalDigits: 0);
    final pct = total > 0 ? amount / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
              Text(
                '${fmt.format(amount)} (${(pct * 100).toStringAsFixed(1)}%)',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ],
      ),
    );
  }
}

class _BudgetTab extends ConsumerStatefulWidget {
  final int companyId;
  final DateTime from;
  final DateTime to;
  final String currency;

  const _BudgetTab({
    required this.companyId,
    required this.from,
    required this.to,
    required this.currency,
  });

  @override
  ConsumerState<_BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends ConsumerState<_BudgetTab> {
  int get _months =>
      (widget.to.year - widget.from.year) * 12 +
      (widget.to.month - widget.from.month) +
      1;

  Future<void> _editBudget(
      BuildContext context, Category cat, double? existing) async {
    final ctrl = TextEditingController(
      text: existing != null && existing > 0 ? existing.toStringAsFixed(0) : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Бюджет: ${cat.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Сумма в месяц',
            suffixText: _sym(widget.currency),
            hintText: '0 = убрать бюджет',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(
                      ctrl.text.replaceAll(' ', '').replaceAll(',', '.')) ??
                  0.0;
              Navigator.pop(context, v);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) {
      await ref
          .read(databaseProvider)
          .upsertBudget(widget.companyId, cat.id, result);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: _sym(widget.currency), decimalDigits: 0);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        db.getCategoriesByCompany(widget.companyId),
        db.getBudgetsByCompany(widget.companyId),
        db.getPnLByCategory(widget.companyId, widget.from, widget.to),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snap.data![0] as List<Category>;
        final budgetList = snap.data![1] as List<Budget>;
        final pnl = snap.data![2] as Map<String, double>;

        final budgetMap = {for (final b in budgetList) b.categoryId: b.monthlyAmount};
        final expenseCats = categories.where((c) => c.type == 'expense').toList();

        double totalBudget = 0;
        double totalActual = 0;

        final rows = <Widget>[];
        for (final cat in expenseCats) {
          final monthlyBudget = budgetMap[cat.id] ?? 0.0;
          final periodBudget = monthlyBudget * _months;
          final actual = (pnl[cat.name] ?? 0.0).abs();
          final overBudget = periodBudget > 0 && actual > periodBudget;
          final ratio = periodBudget > 0
              ? (actual / periodBudget).clamp(0.0, 1.0)
              : 0.0;

          totalBudget += periodBudget;
          totalActual += actual;

          rows.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(cat.name,
                          style: const TextStyle(fontSize: 13))),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Изменить бюджет',
                    onPressed: () =>
                        _editBudget(context, cat, budgetMap[cat.id]),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Факт: ${fmt.format(actual)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: periodBudget > 0
                                ? (overBudget ? Colors.red : Colors.green)
                                : Colors.grey[700],
                          ),
                        ),
                        if (periodBudget > 0)
                          Text(
                            'Бюджет: ${fmt.format(periodBudget)}'
                            '  ${overBudget ? "+" : ""}${fmt.format(actual - periodBudget)}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          )
                        else
                          Text('Бюджет не задан',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  if (periodBudget > 0)
                    Text(
                      '${(ratio * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: overBudget ? Colors.red : Colors.green,
                      ),
                    ),
                ]),
                if (periodBudget > 0) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                          overBudget ? Colors.red : Colors.green),
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ));
        }

        final totalOverBudget = totalBudget > 0 && totalActual > totalBudget;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (totalBudget > 0) ...[
                Row(children: [
                  Expanded(
                      child: _ReportCard(
                          label: 'Бюджет (период)',
                          value: fmt.format(totalBudget),
                          color: Colors.blue)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _ReportCard(
                          label: 'Факт (период)',
                          value: fmt.format(totalActual),
                          color: totalOverBudget ? Colors.red : Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _ReportCard(
                          label: 'Отклонение',
                          value: fmt.format(totalActual - totalBudget),
                          color: totalOverBudget ? Colors.red : Colors.green)),
                ]),
                const SizedBox(height: 16),
              ],
              Row(children: [
                Text(
                  'Расходы по категориям',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('$_months мес.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600])),
              ]),
              const SizedBox(height: 12),
              if (expenseCats.isEmpty)
                const Text('Нет категорий расходов')
              else ...[
                ...rows,
                const SizedBox(height: 8),
                Text(
                  'Нажмите ✏ рядом с категорией, чтобы задать месячный бюджет',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CashFlowTab extends ConsumerWidget {
  final int companyId;
  final String currency;

  const _CashFlowTab({required this.companyId, required this.currency});

  String _compact(double v) {
    if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final fmt = NumberFormat.currency(locale: 'ru_RU', symbol: _sym(currency), decimalDigits: 0);
    final now = DateTime.now();

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        db.getMonthlyTotals(companyId, 3),
        db.getTotalBalance(companyId),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final monthly = snap.data![0] as Map<String, double>;
        final currentBalance = snap.data![1] as double;

        double totalIncome = 0, totalExpense = 0;
        for (int i = 0; i < 3; i++) {
          final m = DateTime(now.year, now.month - i, 1);
          final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
          totalIncome += monthly['income_$key'] ?? 0.0;
          totalExpense += monthly['expense_$key'] ?? 0.0;
        }

        final avgIncome = totalIncome / 3;
        final avgExpense = totalExpense / 3;
        final avgNet = avgIncome - avgExpense;

        String runwayText;
        Color runwayColor;
        if (avgNet >= 0) {
          runwayText = 'Положительный поток';
          runwayColor = Colors.green;
        } else if (currentBalance <= 0) {
          runwayText = 'Недостаток средств';
          runwayColor = Colors.red;
        } else {
          final months = currentBalance / avgNet.abs();
          if (months < 1) {
            runwayText = '< 1 месяца';
            runwayColor = Colors.red;
          } else {
            runwayText = '${months.toStringAsFixed(1)} мес.';
            runwayColor = months < 3 ? Colors.orange : Colors.blue;
          }
        }

        // 7 points: current month + 6 months forward
        final spots = List.generate(7, (i) {
          return FlSpot(i.toDouble(), currentBalance + i * avgNet);
        });

        final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
        final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
        final padding = (maxY - minY).abs() * 0.15 + 1;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: _ReportCard(
                    label: 'Ср. доход/мес',
                    value: fmt.format(avgIncome),
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ReportCard(
                    label: 'Ср. расход/мес',
                    value: fmt.format(avgExpense),
                    color: Colors.red,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _ReportCard(
                    label: 'Чистый поток/мес',
                    value: fmt.format(avgNet),
                    color: avgNet >= 0 ? Colors.blue : Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ReportCard(
                    label: 'Runway',
                    value: runwayText,
                    color: runwayColor,
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              Text(
                'Прогноз баланса на 6 месяцев',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: minY - padding,
                    maxY: maxY + padding,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: avgNet >= 0 ? Colors.blue : Colors.orange,
                        barWidth: 2,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: (avgNet >= 0 ? Colors.blue : Colors.orange)
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: 0,
                          color: Colors.red.withValues(alpha: 0.4),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ],
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            final m = DateTime(
                                now.year, now.month + value.toInt(), 1);
                            return Text(
                              DateFormat('MMM', 'ru').format(m),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 56,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.min || value == meta.max) {
                              return const SizedBox();
                            }
                            return Text(
                              _compact(value),
                              style: const TextStyle(fontSize: 9),
                            );
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(
                        show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Прогноз основан на средних значениях за последние 3 мес.',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── УСН — строка вида деятельности с разбивкой по типу оплаты ───────────────

class _UsnEntry {
  final nameCtrl = TextEditingController();
  final cashCtrl = TextEditingController();
  final nonCashCtrl = TextEditingController();
  final cashRateCtrl = TextEditingController();
  final nonCashRateCtrl = TextEditingController();

  _UsnEntry({
    String name = '',
    String cashRate = '4',
    String nonCashRate = '2',
  }) {
    nameCtrl.text = name;
    cashRateCtrl.text = cashRate;
    nonCashRateCtrl.text = nonCashRate;
  }

  double get cash =>
      double.tryParse(cashCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ??
      0;
  double get nonCash =>
      double.tryParse(
          nonCashCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ??
      0;
  double get cashRatePct =>
      (double.tryParse(cashRateCtrl.text.replaceAll(',', '.')) ?? 0)
          .clamp(0, 100) /
      100;
  double get nonCashRatePct =>
      (double.tryParse(nonCashRateCtrl.text.replaceAll(',', '.')) ?? 0)
          .clamp(0, 100) /
      100;
  double get tax => cash * cashRatePct + nonCash * nonCashRatePct;

  void dispose() {
    nameCtrl.dispose();
    cashCtrl.dispose();
    nonCashCtrl.dispose();
    cashRateCtrl.dispose();
    nonCashRateCtrl.dispose();
  }
}

// ─── Tax Calculator Tab (КР) ──────────────────────────────────────────────────

class _TaxTab extends ConsumerStatefulWidget {
  final int companyId;
  final DateTime from;
  final DateTime to;
  final String currency;

  const _TaxTab({
    required this.companyId,
    required this.from,
    required this.to,
    required this.currency,
  });

  @override
  ConsumerState<_TaxTab> createState() => _TaxTabState();
}

class _TaxTabState extends ConsumerState<_TaxTab> {
  // 'osn' | 'usn' | 'patent'
  String? _regime;
  // Патент — ежемесячный платёж, вводится вручную
  final _patentCtrl = TextEditingController();
  // ОРС: ФОТ за период вводится вручную или вычисляется из payroll
  final _fotCtrl = TextEditingController();
  // УСН: строки видов деятельности с разбивкой наличные / безналичные
  late List<_UsnEntry> _usnEntries;
  // НсП: включить расчёт налога с продаж (ст. 392 НК КР)
  bool _nspEnabled = false;

  @override
  void initState() {
    super.initState();
    final company = ref.read(selectedCompanyProvider);
    _regime = company?.taxRegime ?? 'osn';
    // Предзаполнение видами деятельности пользователя:
    //   объект с землей  — безнал 4%, наличные 6%
    //   капсульный/модульный дом (собственное производство) — безнал 2%, наличные 4%
    _usnEntries = [
      _UsnEntry(name: 'Продажа объекта с землей', cashRate: '6', nonCashRate: '4'),
      _UsnEntry(name: 'Капсульный / модульный дом (производство)', cashRate: '4', nonCashRate: '2'),
    ];
  }

  @override
  void dispose() {
    _patentCtrl.dispose();
    _fotCtrl.dispose();
    for (final e in _usnEntries) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: _sym(widget.currency), decimalDigits: 0);

    return FutureBuilder<List<Transaction>>(
      future: db.getTransactionsByCompany(widget.companyId,
          from: widget.from, to: widget.to),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final txs = snap.data!;
        double revenue = 0;
        double expenses = 0;
        for (final tx in txs) {
          if (tx.type == 'income') revenue += tx.amount;
          if (tx.type == 'expense') expenses += tx.amount;
        }
        final netProfit = revenue - expenses;

        // ─── Социальные взносы ──────────────────────────────────────────
        final fot = double.tryParse(
                _fotCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ??
            0.0;
        // Работодатель: 17.25% от ФОТ (ОРС 15% + ФОМС 2% + ОМС 0.25%)
        final orsEmployer = fot * 0.1725;
        // Работник: ОРС 10% (ст. 16 Закона КР об ОПС)
        final orsEmployee = fot * 0.10;
        // НДФЛ: база = ФОТ − ОРС (ОРС исключена из налогооблагаемого дохода,
        // ст. 163 НК КР). Было ФОТ × 10%, стало (ФОТ − ОРС) × 10% = ФОТ × 9%.
        final ndfl = (fot - orsEmployee) * 0.10;

        // ─── Налог с продаж (ст. 392 НК КР) ─────────────────────────────
        // 2% от выручки при расчётах наличными. Не применяется к безналичным.
        final nsp = revenue * 0.02;

        // ─── УСН итог по всем строкам ─────────────────────────────────────
        final usnTotal = _usnEntries.fold(0.0, (s, e) => s + e.tax);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Base metrics
              Row(children: [
                Expanded(child: _ReportCard(
                    label: 'Выручка', value: fmt.format(revenue), color: Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _ReportCard(
                    label: 'Расходы', value: fmt.format(expenses), color: Colors.red)),
                const SizedBox(width: 8),
                Expanded(child: _ReportCard(
                    label: 'Прибыль',
                    value: fmt.format(netProfit),
                    color: netProfit >= 0 ? Colors.blue : Colors.orange)),
              ]),
              const SizedBox(height: 20),

              // Regime selector
              Text('Налоговый режим',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                _RegimeChip(
                    label: 'ОСН',
                    selected: _regime == 'osn',
                    onTap: () => setState(() => _regime = 'osn')),
                const SizedBox(width: 8),
                _RegimeChip(
                    label: 'УСН',
                    selected: _regime == 'usn',
                    onTap: () => setState(() => _regime = 'usn')),
                const SizedBox(width: 8),
                _RegimeChip(
                    label: 'Патент',
                    selected: _regime == 'patent',
                    onTap: () => setState(() => _regime = 'patent')),
              ]),
              const SizedBox(height: 16),

              // Regime-specific taxes
              if (_regime == 'osn') ...[
                _TaxInfoBanner(
                    text: 'ОСН: НДС 12% (ст. 211 НК КР) + Налог на прибыль 10% (ст. 219 НК КР).\n'
                        'Обязателен при обороте от 30 млн сом/год.\n'
                        'НДС к уплате = НДС начисленный − НДС к зачёту (вычет входящего НДС).'),
                const SizedBox(height: 12),
                _TaxRow(
                  icon: Icons.percent,
                  title: 'НДС начисленный',
                  subtitle: '12% в т.ч. от выручки (Выручка × 12/112)',
                  amount: revenue * 12 / 112,
                  fmt: fmt,
                  color: Colors.deepOrange,
                ),
                const SizedBox(height: 8),
                _TaxRow(
                  icon: Icons.account_balance,
                  title: 'Налог на прибыль',
                  subtitle: '10% от налогооблагаемой прибыли (ст. 219 НК КР)',
                  amount: netProfit > 0 ? netProfit * 0.10 : 0,
                  fmt: fmt,
                  color: Colors.red,
                ),
                const SizedBox(height: 8),
                // ─── Налог с продаж (НсП) ────────────────────────────────
                Row(
                  children: [
                    Switch(
                      value: _nspEnabled,
                      onChanged: (v) => setState(() => _nspEnabled = v),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Добавить НсП (Налог с продаж, ст. 392 НК КР) — 2% от наличной выручки',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (_nspEnabled) ...[
                  const SizedBox(height: 4),
                  _TaxRow(
                    icon: Icons.point_of_sale,
                    title: 'Налог с продаж (НсП)',
                    subtitle: '2% от выручки (только наличные расчёты)',
                    amount: nsp,
                    fmt: fmt,
                    color: Colors.brown,
                  ),
                  const SizedBox(height: 8),
                ],
                _TaxRow(
                  icon: Icons.calculate,
                  title: 'Итого налогов (ОСН)',
                  subtitle: _nspEnabled
                      ? 'НДС + Налог на прибыль + НсП'
                      : 'НДС + Налог на прибыль',
                  amount: revenue * 12 / 112 +
                      (netProfit > 0 ? netProfit * 0.10 : 0) +
                      (_nspEnabled ? nsp : 0),
                  fmt: fmt,
                  color: Colors.red.shade800,
                  isBold: true,
                ),
              ],

              if (_regime == 'usn') ...[
                _TaxInfoBanner(
                    text: 'УСН (Единый налог, Раздел IX НК КР).\n'
                        'Без НДС и налога на прибыль. Порог: до 30 млн сом/год.\n'
                        'Ставка зависит от вида деятельности и типа оплаты:\n'
                        '  • Производство / с/х:  2% безнал,  4% наличные\n'
                        '  • Торговля:             2% безнал,  4% наличные\n'
                        '  • Строительство/недвиж: 4% безнал,  6% наличные\n'
                        'Введите приходы по каждому виду деятельности отдельно.'),
                const SizedBox(height: 12),

                // ─ Таблица видов деятельности ────────────────────────────
                ..._usnEntries.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: e.nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Вид деятельности',
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'Удалить',
                              onPressed: _usnEntries.length > 1
                                  ? () => setState(() {
                                        e.dispose();
                                        _usnEntries.removeAt(i);
                                      })
                                  : null,
                            ),
                          ]),
                          const SizedBox(height: 10),
                          // Наличные
                          Row(children: [
                            const Icon(Icons.payments_outlined,
                                size: 16, color: Colors.deepOrange),
                            const SizedBox(width: 6),
                            const SizedBox(
                                width: 80,
                                child: Text('Наличные',
                                    style: TextStyle(fontSize: 12))),
                            Expanded(
                              child: TextField(
                                controller: e.cashCtrl,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Сумма прихода',
                                  suffixText: _sym(widget.currency),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: TextField(
                                controller: e.cashRateCtrl,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Ставка',
                                  suffixText: '%',
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: Text(
                                e.cash > 0
                                    ? fmt.format(e.cash * e.cashRatePct)
                                    : '—',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          // Безналичные
                          Row(children: [
                            const Icon(Icons.account_balance_outlined,
                                size: 16, color: Colors.teal),
                            const SizedBox(width: 6),
                            const SizedBox(
                                width: 80,
                                child: Text('Безналичные',
                                    style: TextStyle(fontSize: 12))),
                            Expanded(
                              child: TextField(
                                controller: e.nonCashCtrl,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Сумма прихода',
                                  suffixText: _sym(widget.currency),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: TextField(
                                controller: e.nonCashRateCtrl,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Ставка',
                                  suffixText: '%',
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: Text(
                                e.nonCash > 0
                                    ? fmt.format(e.nonCash * e.nonCashRatePct)
                                    : '—',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ]),
                          if (e.tax > 0) ...[
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text('Налог по строке: ',
                                    style: TextStyle(fontSize: 12)),
                                Text(fmt.format(e.tax),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

                // Добавить строку
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить вид деятельности'),
                  onPressed: () => setState(() =>
                      _usnEntries.add(_UsnEntry())),
                ),
                const SizedBox(height: 8),

                // Итого
                if (usnTotal > 0)
                  _TaxRow(
                    icon: Icons.calculate,
                    title: 'Итого единый налог (УСН)',
                    subtitle: 'Сумма по всем видам и типам оплаты',
                    amount: usnTotal,
                    fmt: fmt,
                    color: Colors.orange.shade800,
                    isBold: true,
                  ),
              ],

              if (_regime == 'patent') ...[
                _TaxInfoBanner(
                    text: 'Патент: фиксированный ежемесячный платёж.\n'
                        'Размер зависит от вида деятельности и региона.\n'
                        'Уплачивается авансом за каждый месяц.'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.receipt_long, size: 18),
                          const SizedBox(width: 8),
                          const Text('Стоимость патента/мес.',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _patentCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Сумма в месяц',
                            suffixText: _sym(widget.currency),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final monthly = double.tryParse(_patentCtrl.text
                          .replaceAll(' ', '')
                          .replaceAll(',', '.')) ??
                      0;
                  final months = widget.to.difference(widget.from).inDays / 30.0;
                  final total = monthly * months.ceil();
                  return _TaxRow(
                    icon: Icons.calculate,
                    title: 'Патент за период',
                    subtitle: '${monthly > 0 ? fmt.format(monthly) : "—"}/мес × ${months.ceil()} мес.',
                    amount: total,
                    fmt: fmt,
                    color: Colors.purple,
                    isBold: true,
                  );
                }),
              ],

              // ─── ОРС / ФОМС (для всех режимов) ──────────────────────────
              const SizedBox(height: 24),
              Text('Социальные взносы (ОРС / ФОМС)',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _TaxInfoBanner(
                  text: 'Работодатель: 17.25% от ФОТ (ОРС 15% + ФОМС 2% + ОМС 0.25%)\n'
                      'Работник: ОРС 10% + НДФЛ 10% от (ФОТ − ОРС)\n'
                      '  → НДФЛ = ФОТ × 9% (ОРС исключается из базы, ст. 163 НК КР)'),
              const SizedBox(height: 10),
              TextField(
                controller: _fotCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'ФОТ за период (фонд оплаты труда)',
                  suffixText: _sym(widget.currency),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (fot > 0) ...[
                const SizedBox(height: 8),
                _TaxRow(
                  icon: Icons.business,
                  title: 'Взносы работодателя',
                  subtitle: '17.25% от ФОТ',
                  amount: orsEmployer,
                  fmt: fmt,
                  color: Colors.teal,
                ),
                const SizedBox(height: 4),
                _TaxRow(
                  icon: Icons.person,
                  title: 'ОРС работника',
                  subtitle: '10% от ФОТ (ст. 16 Закона КР об ОПС)',
                  amount: orsEmployee,
                  fmt: fmt,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 4),
                _TaxRow(
                  icon: Icons.person,
                  title: 'НДФЛ (удержать с работника)',
                  subtitle: '10% от (ФОТ − ОРС) = ФОТ × 9% (ст. 163 НК КР)',
                  amount: ndfl,
                  fmt: fmt,
                  color: Colors.indigo,
                ),
              ],

              // ─── Экспорт справки об изменениях ───────────────────────────
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Справка об изменениях (PDF)'),
                  onPressed: () => PdfReportService.printTaxChangelog(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _RegimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RegimeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label,
          style: TextStyle(fontWeight: selected ? FontWeight.bold : null)),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}

class _TaxInfoBanner extends StatelessWidget {
  final String text;
  const _TaxInfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900)),
        ),
      ]),
    );
  }
}

class _TaxRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double amount;
  final NumberFormat fmt;
  final Color color;
  final bool isBold;

  const _TaxRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.fmt,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight:
                            isBold ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13)),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
          Text(
            amount > 0 ? fmt.format(amount) : '—',
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: amount > 0 ? color : Colors.grey,
            ),
          ),
        ]),
      ),
    );
  }
}

class _ExpensePieChart extends StatelessWidget {
  final Map<String, double> data;

  const _ExpensePieChart({required this.data});

  static const _colors = [
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.brown,
    Colors.cyan,
  ];

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0.0, (s, v) => s + v);
    final entries = data.entries.toList();

    return PieChart(
      PieChartData(
        sections: List.generate(entries.length, (i) {
          final e = entries[i];
          final pct = total > 0 ? e.value / total * 100 : 0.0;
          return PieChartSectionData(
            value: e.value,
            title: pct > 5 ? '${pct.toStringAsFixed(0)}%' : '',
            color: _colors[i % _colors.length],
            radius: 80,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          );
        }),
        sectionsSpace: 2,
        centerSpaceRadius: 30,
      ),
    );
  }
}

// ─── AR Aging Tab ─────────────────────────────────────────────────────────────

class _ArAgingTab extends ConsumerWidget {
  final int companyId;
  final String currency;

  const _ArAgingTab({required this.companyId, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<List<Invoice>>(
      future: db.watchInvoicesByCompany(companyId).first,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final now = DateTime.now();
        final fmt = NumberFormat('#,##0', 'ru_RU');
        final sym = _sym(currency);

        // Unpaid, non-cancelled invoices with a due date
        final unpaid = snap.data!.where((inv) =>
            inv.status != 'paid' &&
            inv.status != 'cancelled' &&
            inv.dueDate != null).toList();

        if (unpaid.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                  SizedBox(height: 12),
                  Text('Нет просроченной дебиторки!',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }

        // Group by aging bucket
        final buckets = <String, List<Invoice>>{
          'Текущие': [],
          '1–30 дней': [],
          '31–60 дней': [],
          '61–90 дней': [],
          '90+ дней': [],
        };

        for (final inv in unpaid) {
          final days = now.difference(inv.dueDate!).inDays;
          if (days <= 0) {
            buckets['Текущие']!.add(inv);
          } else if (days <= 30) {
            buckets['1–30 дней']!.add(inv);
          } else if (days <= 60) {
            buckets['31–60 дней']!.add(inv);
          } else if (days <= 90) {
            buckets['61–90 дней']!.add(inv);
          } else {
            buckets['90+ дней']!.add(inv);
          }
        }

        final bucketColors = {
          'Текущие': Colors.blue,
          '1–30 дней': Colors.orange.shade300,
          '31–60 дней': Colors.orange,
          '61–90 дней': Colors.deepOrange,
          '90+ дней': Colors.red,
        };

        final totalUnpaid = unpaid.fold(0.0, (s, inv) => s + inv.totalAmount);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary card
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance, color: Colors.red, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Всего дебиторская задолженность',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            '$sym ${fmt.format(totalUnpaid)}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red),
                          ),
                          Text('${unpaid.length} неоплаченных инвойсов',
                              style:
                                  const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Buckets
            ...buckets.entries
                .where((e) => e.value.isNotEmpty)
                .map((bucket) {
              final bucketTotal = bucket.value
                  .fold(0.0, (s, inv) => s + inv.totalAmount);
              final bColor = bucketColors[bucket.key] ?? Colors.grey;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: bColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(bucket.key,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: bColor)),
                      const Spacer(),
                      Text(
                        '$sym ${fmt.format(bucketTotal)} · ${bucket.value.length} инв.',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: bColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Card(
                    child: Column(
                      children: bucket.value.map((inv) {
                        final days = now.difference(inv.dueDate!).inDays;
                        return ListTile(
                          dense: true,
                          title: Text(inv.clientName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13)),
                          subtitle: Text(
                            '${inv.invoiceNumber != null ? '№${inv.invoiceNumber} · ' : ''}'
                            'Срок: ${DateFormat('dd.MM.yyyy').format(inv.dueDate!)}'
                            '${days > 0 ? ' · $days дн. просрочки' : ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            '$sym ${fmt.format(inv.totalAmount)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: bColor,
                                fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}
