import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../providers/database_provider.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/priority_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(selectedCompanyProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final db = ref.watch(databaseProvider);

    if (company == null) {
      return const Center(child: Text('Нет компаний. Создайте компанию.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          accountsAsync.when(
            data: (accounts) {
              final totalBalance = accounts.fold(0.0, (s, a) => s + a.balance);
              return transactionsAsync.when(
                data: (txs) {
                  final income = txs
                      .where((t) => t.type == 'income')
                      .fold(0.0, (s, t) => s + t.amount);
                  final expense = txs
                      .where((t) => t.type == 'expense')
                      .fold(0.0, (s, t) => s + t.amount);
                  final isWide = MediaQuery.of(context).size.width >= 500;
                  final cards = [
                    SummaryCard(
                      title: 'Общий баланс',
                      amount: totalBalance,
                      icon: Icons.account_balance_wallet,
                      color: Colors.blue,
                      currency: company.currency,
                    ),
                    SummaryCard(
                      title: 'Доходы месяца',
                      amount: income,
                      icon: Icons.trending_up,
                      color: Colors.green,
                      currency: company.currency,
                    ),
                    SummaryCard(
                      title: 'Расходы месяца',
                      amount: expense,
                      icon: Icons.trending_down,
                      color: Colors.red,
                      currency: company.currency,
                    ),
                  ];
                  if (isWide) {
                    return Row(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    );
                  }
                  // На узком экране — 2 колонки: баланс на всю ширину, доходы+расходы рядом
                  return Column(
                    children: [
                      cards[0],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: cards[1]),
                          const SizedBox(width: 10),
                          Expanded(child: cards[2]),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Ошибка: $e'),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Ошибка: $e'),
          ),

          const SizedBox(height: 12),
          const _LowStockCard(),
          const _HealthScoreCard(),
          const SizedBox(height: 12),
          const _CashFlowCard(),
          const _BudgetAlertsCard(),
          const SizedBox(height: 12),
          const _PeriodComparisonCard(),
          const SizedBox(height: 12),
          const _BreakEvenCard(),
          const SizedBox(height: 24),

          // Chart
          Text(
            'Доходы и расходы за 6 месяцев',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, double>>(
            future: db.getMonthlyTotals(company.id, 6),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _MonthlyChart(data: snap.data!);
            },
          ),

          const SizedBox(height: 24),

          // Upcoming tasks
          Text(
            'Ближайшие задачи',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          tasksAsync.when(
            data: (tasks) {
              final open = tasks
                  .where((t) => t.status != 'done' && t.status != 'cancelled')
                  .take(5)
                  .toList();
              if (open.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Нет активных задач'),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: open
                      .map((task) => _TaskTile(task: task))
                      .toList(),
                ),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Ошибка: $e'),
          ),

          const SizedBox(height: 24),

          // KPI: overdue invoices + top expenses + expiring contracts
          FutureBuilder<List<dynamic>>(
            future: Future.wait([
              db.watchInvoicesByCompany(company.id).first,
              db.getPnLByCategory(
                company.id,
                DateTime(DateTime.now().year, DateTime.now().month, 1),
                DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
              ),
              db.getContractsByCompany(company.id),
            ]),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox();
              final invoices = snap.data![0] as List;
              final pnl = snap.data![1] as Map<String, double>;
              final contracts = snap.data![2] as List<Contract>;

              final now = DateTime.now();
              final in30 = now.add(const Duration(days: 30));
              final expiring = contracts
                  .where((c) =>
                      c.endDate != null &&
                      c.endDate!.isAfter(now) &&
                      c.endDate!.isBefore(in30) &&
                      c.status == 'active')
                  .toList()
                ..sort((a, b) => a.endDate!.compareTo(b.endDate!));

              final overdue = invoices
                  .where((inv) =>
                      inv.dueDate != null &&
                      inv.dueDate!.isBefore(now) &&
                      inv.status != 'paid' &&
                      inv.status != 'cancelled')
                  .length;

              final expenses = pnl.entries
                  .where((e) => e.value < 0)
                  .map((e) =>
                      MapEntry(e.key, e.value.abs()))
                  .toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final topExpenses = expenses.take(3).toList();
              final totalExpense =
                  expenses.fold(0.0, (s, e) => s + e.value);

              final clientMap = <String, double>{};
              for (final inv in invoices) {
                if (inv.status != 'cancelled') {
                  final name = inv.clientName as String;
                  clientMap[name] =
                      (clientMap[name] ?? 0.0) + (inv.totalAmount as double);
                }
              }
              final topClients = (clientMap.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .take(3)
                  .toList();
              final fmtNum = NumberFormat('#,##0', 'ru_RU');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overdue > 0) ...[
                    Text(
                      'Просроченные сделки',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.red.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber,
                            color: Colors.red),
                        title: Text(
                          '$overdue просроченных инвойсов',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red),
                        ),
                        subtitle: const Text(
                            'Требуют внимания'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (expiring.isNotEmpty) ...[
                    Text(
                      'Истекающие договоры (30 дней)',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.orange.shade50,
                      child: Column(
                        children: expiring.map((c) => ListTile(
                          leading: const Icon(Icons.description,
                              color: Colors.orange),
                          title: Text(
                            c.counterparty,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Истекает: ${DateFormat('dd.MM.yyyy').format(c.endDate!)}${c.number != null ? ' · №${c.number}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          dense: true,
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (topExpenses.isNotEmpty) ...[
                    Text(
                      'Топ расходов месяца',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: topExpenses.map((e) {
                            final pct = totalExpense > 0
                                ? e.value / totalExpense
                                : 0.0;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(e.key,
                                            style: const TextStyle(
                                                fontSize: 13))),
                                    Text(
                                      '${(pct * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                  ]),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      backgroundColor:
                                          Colors.grey.shade200,
                                      minHeight: 5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  if (topClients.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Топ клиентов',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: topClients
                            .map((e) => ListTile(
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor:
                                        Colors.purple.shade100,
                                    child: const Icon(Icons.person,
                                        size: 16,
                                        color: Colors.purple),
                                  ),
                                  title: Text(e.key,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14)),
                                  trailing: Text(
                                    fmtNum.format(e.value),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  dense: true,
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const _ExpenseGrowthCard(),
        ],
      ),
    );
  }
}

List<FlSpot> _rollingAvg(List<FlSpot> spots) {
  return List.generate(spots.length, (i) {
    final from = (i - 1).clamp(0, spots.length - 1);
    final to = (i + 1).clamp(0, spots.length - 1);
    var sum = 0.0;
    var count = 0;
    for (var j = from; j <= to; j++) {
      sum += spots[j].y;
      count++;
    }
    return FlSpot(spots[i].x, sum / count);
  });
}

class _MonthlyChart extends StatelessWidget {
  final Map<String, double> data;

  const _MonthlyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - 5 + i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];

    for (int i = 0; i < months.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), data['income_${months[i]}'] ?? 0));
      expenseSpots.add(FlSpot(i.toDouble(), data['expense_${months[i]}'] ?? 0));
    }

    final monthLabels = months.map((m) {
      final parts = m.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat.MMM('ru').format(d);
    }).toList();

    final hasData = incomeSpots.any((s) => s.y > 0);
    final avgSpots = hasData ? _rollingAvg(incomeSpots) : <FlSpot>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, m) {
                      final i = v.toInt();
                      if (i < 0 || i >= monthLabels.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(monthLabels[i], style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: incomeSpots,
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.green.withValues(alpha: 0.1),
                  ),
                ),
                LineChartBarData(
                  spots: expenseSpots,
                  isCurved: true,
                  color: Colors.red,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.red.withValues(alpha: 0.1),
                  ),
                ),
                if (avgSpots.isNotEmpty)
                  LineChartBarData(
                    spots: avgSpots,
                    isCurved: true,
                    color: Colors.green.withValues(alpha: 0.55),
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                    dashArray: [6, 4],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ChartLegendItem(color: Colors.green, label: 'Доходы'),
            const SizedBox(width: 16),
            _ChartLegendItem(color: Colors.red, label: 'Расходы'),
            if (avgSpots.isNotEmpty) ...[
              const SizedBox(width: 16),
              _ChartLegendItem(
                  color: Colors.green.withValues(alpha: 0.6),
                  label: 'Скольз. ср.'),
            ],
          ],
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(task.title),
      subtitle: task.dueDate != null
          ? Text(
              'Срок: ${DateFormat('dd.MM.yyyy').format(task.dueDate!)}',
              style: const TextStyle(fontSize: 12),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PriorityBadge(priority: task.priority),
          const SizedBox(width: 8),
          StatusBadge(status: task.status),
        ],
      ),
    );
  }
}

// ─── Cash Flow Card ───────────────────────────────────────────────────────────

String _currencySymbol(String code) {
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

class _CashFlowCard extends ConsumerWidget {
  const _CashFlowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(selectedCompanyProvider);
    final txsAsync = ref.watch(transactionsProvider);
    if (company == null) return const SizedBox();

    return txsAsync.when(
      data: (txs) {
        final income = txs
            .where((t) => t.type == 'income')
            .fold(0.0, (s, t) => s + t.amount);
        final expense = txs
            .where((t) => t.type == 'expense')
            .fold(0.0, (s, t) => s + t.amount);
        final net = income - expense;
        final isPositive = net >= 0;
        final fmt = NumberFormat('#,##0', 'ru_RU');
        final sym = _currencySymbol(company.currency);

        return Card(
          color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? Colors.green[700] : Colors.red[700],
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Денежный поток (месяц)',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        '${isPositive ? "+" : ""}${fmt.format(net)} $sym',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isPositive
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '↑ ${fmt.format(income)} $sym',
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '↓ ${fmt.format(expense)} $sym',
                      style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}

// ─── Budget Alerts Card ───────────────────────────────────────────────────────

class _BudgetAlertsCard extends ConsumerWidget {
  const _BudgetAlertsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(selectedCompanyProvider);
    if (company == null) return const SizedBox();
    final db = ref.watch(databaseProvider);
    final now = DateTime.now();

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        db.getBudgetsByCompany(company.id),
        db.getCategoriesByCompany(company.id),
        db.getPnLByCategory(
          company.id,
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0),
        ),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final budgets = snap.data![0] as List<Budget>;
        final cats = snap.data![1] as List<Category>;
        final pnl = snap.data![2] as Map<String, double>;
        if (budgets.isEmpty) return const SizedBox();

        final catMap = {for (final c in cats) c.id: c.name};
        final fmt = NumberFormat('#,##0', 'ru_RU');
        final sym = _currencySymbol(company.currency);

        final alerts = <({String name, double spent, double limit})>[];
        for (final b in budgets) {
          final catName = catMap[b.categoryId];
          if (catName == null) continue;
          final spent = (pnl[catName] ?? 0.0).abs();
          if (spent > b.monthlyAmount) {
            alerts.add((name: catName, spent: spent, limit: b.monthlyAmount));
          }
        }
        if (alerts.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Превышение бюджета',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.red.shade50,
              child: Column(
                children: alerts
                    .map((a) => ListTile(
                          leading: const Icon(Icons.warning_amber,
                              color: Colors.red),
                          title: Text(a.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              'Потрачено ${fmt.format(a.spent)} $sym'
                              ' / Бюджет ${fmt.format(a.limit)} $sym'),
                          trailing: Text(
                            '+${((a.spent / a.limit - 1) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          dense: true,
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Period Comparison Card ───────────────────────────────────────────────────

class _PeriodComparisonCard extends ConsumerWidget {
  const _PeriodComparisonCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(selectedCompanyProvider);
    if (company == null) return const SizedBox();
    final db = ref.watch(databaseProvider);

    return FutureBuilder<Map<String, double>>(
      future: db.getMonthlyTotals(company.id, 2),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final data = snap.data!;
        final now = DateTime.now();
        final thisKey =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final last = DateTime(now.year, now.month - 1);
        final lastKey =
            '${last.year}-${last.month.toString().padLeft(2, '0')}';

        final thisIncome = data['income_$thisKey'] ?? 0;
        final thisExpense = data['expense_$thisKey'] ?? 0;
        final lastIncome = data['income_$lastKey'] ?? 0;
        final lastExpense = data['expense_$lastKey'] ?? 0;

        if (lastIncome == 0 && lastExpense == 0) return const SizedBox();

        final fmt = NumberFormat('#,##0', 'ru_RU');
        final sym = _currencySymbol(company.currency);

        double pct(double cur, double prev) =>
            prev == 0 ? 0 : (cur - prev) / prev * 100;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Сравнение с прошлым месяцем',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CompareItem(
                        label: 'Доходы',
                        current: thisIncome,
                        pct: pct(thisIncome, lastIncome),
                        fmt: fmt,
                        sym: sym,
                        positiveIsGood: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _CompareItem(
                        label: 'Расходы',
                        current: thisExpense,
                        pct: pct(thisExpense, lastExpense),
                        fmt: fmt,
                        sym: sym,
                        positiveIsGood: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompareItem extends StatelessWidget {
  final String label;
  final double current;
  final double pct;
  final NumberFormat fmt;
  final String sym;
  final bool positiveIsGood;

  const _CompareItem({
    required this.label,
    required this.current,
    required this.pct,
    required this.fmt,
    required this.sym,
    required this.positiveIsGood,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = pct > 0;
    final isNeutral = pct == 0;
    final isGood = isUp == positiveIsGood;
    final color = isNeutral
        ? Colors.grey
        : (isGood ? Colors.green[700]! : Colors.red[700]!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(
          '${fmt.format(current)} $sym',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15),
        ),
        if (!isNeutral)
          Row(
            children: [
              Icon(
                isUp ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: color,
              ),
              Text(
                '${pct.abs().toStringAsFixed(1)}%',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                ' vs прошлый',
                style:
                    TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          )
        else
          Text('= как прошлый',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}

// ─── Chart Legend Item ────────────────────────────────────────────────────────

class _ChartLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 14,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
    ]);
  }
}

// ─── Break-Even Card ──────────────────────────────────────────────────────────

class _BreakEvenCard extends ConsumerWidget {
  const _BreakEvenCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(selectedCompanyProvider);
    if (company == null) return const SizedBox();
    final txsAsync = ref.watch(transactionsProvider);

    return txsAsync.when(
      data: (txs) {
        final income = txs
            .where((t) => t.type == 'income')
            .fold(0.0, (s, t) => s + t.amount);
        final expense = txs
            .where((t) => t.type == 'expense')
            .fold(0.0, (s, t) => s + t.amount);
        if (expense == 0) return const SizedBox();

        final pct = (income / expense).clamp(0.0, 1.0);
        final isBreakEven = income >= expense;
        final fmt = NumberFormat('#,##0', 'ru_RU');
        final sym = _currencySymbol(company.currency);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                    isBreakEven
                        ? Icons.check_circle_outline
                        : Icons.timelapse,
                    color: isBreakEven ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Точка безубыточности (месяц)',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                        isBreakEven ? Colors.green : Colors.orange),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                isBreakEven
                    ? Text(
                        'Достигнута! Прибыль: ${fmt.format(income - expense)} $sym',
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                            fontSize: 13),
                      )
                    : Text(
                        'До безубыточности: ${fmt.format(expense - income)} $sym'
                        '  (${(pct * 100).toStringAsFixed(0)}% покрыто)',
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                            fontSize: 13),
                      ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}

// ─── Expense Growth Card ──────────────────────────────────────────────────────

class _ExpenseGrowthCard extends ConsumerWidget {
  const _ExpenseGrowthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(selectedCompanyProvider);
    if (company == null) return const SizedBox();
    final db = ref.watch(databaseProvider);
    final now = DateTime.now();

    return FutureBuilder<List<Map<String, double>>>(
      future: Future.wait([
        db.getPnLByCategory(
          company.id,
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0),
        ),
        db.getPnLByCategory(
          company.id,
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month, 0),
        ),
      ]).then((r) => [r[0], r[1]]),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final cur = snap.data![0];
        final prev = snap.data![1];

        final growth =
            <({String name, double cur, double prev, double pct})>[];
        for (final e in cur.entries) {
          if (e.value >= 0) continue;
          final curAbs = e.value.abs();
          final prevAbs = (prev[e.key] ?? 0).abs();
          if (prevAbs == 0) continue;
          final p = (curAbs - prevAbs) / prevAbs * 100;
          if (p > 0) {
            growth.add((name: e.key, cur: curAbs, prev: prevAbs, pct: p));
          }
        }
        if (growth.isEmpty) return const SizedBox();
        growth.sort((a, b) => b.pct.compareTo(a.pct));
        final top = growth.take(3).toList();
        final fmt = NumberFormat('#,##0', 'ru_RU');
        final sym = _currencySymbol(company.currency);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Рост расходов (vs прошлый месяц)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.amber.shade50,
              child: Column(
                children: top
                    .map((e) => ListTile(
                          leading: const Icon(Icons.trending_up,
                              color: Colors.orange),
                          title: Text(e.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              '${fmt.format(e.cur)} $sym  ←  ${fmt.format(e.prev)} $sym'),
                          trailing: Text(
                            '+${e.pct.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          dense: true,
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Low Stock Card ───────────────────────────────────────────────────────────

class _LowStockCard extends ConsumerWidget {
  const _LowStockCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).valueOrNull ?? [];
    final lowStock = products
        .where((p) => p.minQuantity > 0 && p.quantity <= p.minQuantity)
        .toList();

    if (lowStock.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Склад: низкий остаток',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          color: Colors.orange.shade50,
          child: Column(
            children: lowStock
                .map((p) => ListTile(
                      leading: const Icon(Icons.inventory_2_outlined,
                          color: Colors.orange),
                      title: Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        'Остаток: ${_fmtQty(p.quantity)} / мин. ${_fmtQty(p.minQuantity)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Заказать',
                          style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      dense: true,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

String _fmtQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

// ─── Health Score Card ────────────────────────────────────────────────────────

class _HealthScoreCard extends ConsumerWidget {
  const _HealthScoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(selectedCompanyProvider);
    if (company == null) return const SizedBox();

    final txs = ref.watch(transactionsProvider).valueOrNull ?? [];
    final tasks = ref.watch(tasksProvider).valueOrNull ?? [];
    final db = ref.watch(databaseProvider);

    final income = txs.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
    final expense = txs.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);

    // Profit score: 0–40
    final profitScore = income <= 0
        ? (expense > 0 ? 0.0 : 20.0)
        : (((income - expense) / income).clamp(0.0, 1.0) * 40);

    // Task score: 0–30
    final taskScore = tasks.isEmpty
        ? 15.0
        : (tasks.where((t) => t.status == 'done' || t.status == 'cancelled').length /
                tasks.length *
                30);

    return FutureBuilder<List<Invoice>>(
      future: db.watchInvoicesByCompany(company.id).first,
      builder: (ctx, snap) {
        final invoices = snap.data ?? [];
        final now = DateTime.now();
        final nonCancelled =
            invoices.where((inv) => inv.status != 'cancelled').toList();
        final overdue = nonCancelled
            .where((inv) =>
                inv.dueDate != null &&
                inv.dueDate!.isBefore(now) &&
                inv.status != 'paid')
            .length;
        final invoiceScore = nonCancelled.isEmpty
            ? 15.0
            : ((nonCancelled.length - overdue) / nonCancelled.length * 30);

        final total = (profitScore + taskScore + invoiceScore).round();
        final color =
            total < 40 ? Colors.red : total < 70 ? Colors.orange : Colors.green;
        final label = total < 40
            ? 'Критично'
            : total < 70
                ? 'Требует внимания'
                : 'Хорошо';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: total / 100,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                        strokeWidth: 6,
                      ),
                      Text(
                        '$total',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Финансовое здоровье',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(label,
                          style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _ScoreItem('Прибыль', profitScore.round(), 40),
                          const SizedBox(width: 16),
                          _ScoreItem('Инвойсы', invoiceScore.round(), 30),
                          const SizedBox(width: 16),
                          _ScoreItem('Задачи', taskScore.round(), 30),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScoreItem extends StatelessWidget {
  final String label;
  final int score;
  final int max;

  const _ScoreItem(this.label, this.score, this.max);

  @override
  Widget build(BuildContext context) {
    final pct = score / max;
    final color =
        pct < 0.4 ? Colors.red : pct < 0.7 ? Colors.orange : Colors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text('$score/$max',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }
}
