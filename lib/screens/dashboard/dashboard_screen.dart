import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/tabys_theme.dart';
import '../../widgets/priority_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(selectedCompanyProvider);
    if (company == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_outlined,
                size: 56, color: TColors.muted),
            const SizedBox(height: 16),
            Text('Нет компаний',
                style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: TColors.text)),
            const SizedBox(height: 8),
            Text('Создайте компанию через меню',
                style: GoogleFonts.inter(fontSize: 13, color: TColors.muted)),
          ],
        ),
      );
    }

    final accountsAsync = ref.watch(accountsProvider);
    final txAsync = ref.watch(transactionsProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final chartAsync = ref.watch(last6MonthsTransactionsProvider);
    final invoicesAsync = ref.watch(invoicesProvider);

    return Container(
      color: TColors.ink,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KPI row ──────────────────────────────────────────────────────
            _KpiRow(
              currency: company.currency,
              accountsAsync: accountsAsync,
              txAsync: txAsync,
            ),
            const SizedBox(height: 18),

            // ── Mid row: Chart + Accounts ─────────────────────────────────
            LayoutBuilder(builder: (ctx, bc) {
              if (bc.maxWidth > 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PnlChartPanel(chartAsync: chartAsync),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 300,
                      child: _AccountsPanel(
                          accountsAsync: accountsAsync,
                          currency: company.currency),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _PnlChartPanel(chartAsync: chartAsync),
                  const SizedBox(height: 14),
                  _AccountsPanel(
                      accountsAsync: accountsAsync, currency: company.currency),
                ],
              );
            }),
            const SizedBox(height: 18),

            // ── Bottom row: Transactions + (AR aging + Tasks) ─────────────
            LayoutBuilder(builder: (ctx, bc) {
              if (bc.maxWidth > 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TransactionsPanel(
                          txAsync: txAsync, currency: company.currency),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 300,
                      child: Column(
                        children: [
                          _ArAgingPanel(invoicesAsync: invoicesAsync),
                          const SizedBox(height: 14),
                          _TasksPanel(tasksAsync: tasksAsync),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _TransactionsPanel(
                      txAsync: txAsync, currency: company.currency),
                  const SizedBox(height: 14),
                  _ArAgingPanel(invoicesAsync: invoicesAsync),
                  const SizedBox(height: 14),
                  _TasksPanel(tasksAsync: tasksAsync),
                ],
              );
            }),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── KPI Row ──────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final String currency;
  final AsyncValue<List<Account>> accountsAsync;
  final AsyncValue<List<Transaction>> txAsync;

  const _KpiRow(
      {required this.currency,
      required this.accountsAsync,
      required this.txAsync});

  @override
  Widget build(BuildContext context) {
    return accountsAsync.when(
      loading: () => const SizedBox(height: 100, child: _KpiSkeleton()),
      error: (_, __) => const SizedBox(),
      data: (accounts) => txAsync.when(
        loading: () => const SizedBox(height: 100, child: _KpiSkeleton()),
        error: (_, __) => const SizedBox(),
        data: (txs) {
          final totalBalance =
              accounts.fold(0.0, (s, a) => s + a.balance);
          final income = txs
              .where((t) => t.type == 'income')
              .fold(0.0, (s, t) => s + t.amount);
          final expense = txs
              .where((t) => t.type == 'expense')
              .fold(0.0, (s, t) => s + t.amount);
          final profit = income - expense;

          return LayoutBuilder(builder: (ctx, bc) {
            final cols = bc.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: bc.maxWidth > 600 ? 2.0 : 1.7,
              children: [
                _KpiCard(
                  label: 'Общий баланс',
                  value: totalBalance,
                  currency: currency,
                  accentColor: TColors.gold,
                  glowColor: TColors.goldGlow,
                ),
                _KpiCard(
                  label: 'Доходы / месяц',
                  value: income,
                  currency: currency,
                  accentColor: TColors.green,
                  glowColor: TColors.greenGlow,
                  changePositive: true,
                ),
                _KpiCard(
                  label: 'Расходы / месяц',
                  value: expense,
                  currency: currency,
                  accentColor: TColors.red,
                  glowColor: TColors.redGlow,
                ),
                _KpiCard(
                  label: 'Чистая прибыль',
                  value: profit,
                  currency: currency,
                  accentColor: TColors.blue,
                  glowColor: TColors.blueGlow,
                  changePositive: profit >= 0,
                ),
              ],
            );
          });
        },
      ),
    );
  }
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
          4,
          (_) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: TColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TColors.border),
                  ),
                ),
              )),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final Color accentColor;
  final Color glowColor;
  final bool? changePositive;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.currency,
    required this.accentColor,
    required this.glowColor,
    this.changePositive,
  });

  static final _fmt = NumberFormat('#,##0', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    final fmt = _fmt;
    final absValue = value.abs();
    final isNeg = value < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TColors.border),
      ),
      child: Stack(
        children: [
          // Glow blob
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [glowColor, Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: TColors.muted,
                    letterSpacing: .5,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$currency ',
                      style: TabysTheme.mono(
                          size: 13, color: TColors.muted),
                    ),
                    TextSpan(
                      text: isNeg
                          ? '−${fmt.format(absValue)}'
                          : fmt.format(absValue),
                      style: TabysTheme.mono(
                          size: 20,
                          color: isNeg ? TColors.red : TColors.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (changePositive != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: changePositive!
                        ? TColors.greenBg
                        : TColors.redBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    changePositive! ? '↑ прибыль' : '↓ убыток',
                    style: TabysTheme.mono(
                        size: 10,
                        color: changePositive!
                            ? TColors.green
                            : TColors.red),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: TColors.goldBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('текущий месяц',
                      style: TabysTheme.mono(
                          size: 10, color: TColors.gold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── P&L Chart Panel ──────────────────────────────────────────────────────────

class _PnlChartPanel extends StatelessWidget {
  final AsyncValue<List<Transaction>> chartAsync;

  const _PnlChartPanel({required this.chartAsync});

  @override
  Widget build(BuildContext context) {
    return _DashPanel(
      title: 'Доходы и расходы',
      subtitle: 'Последние 6 месяцев',
      child: SizedBox(
        height: 200,
        child: chartAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(
                  color: TColors.gold, strokeWidth: 2)),
          error: (_, __) => Center(
              child: Text('Ошибка загрузки',
                  style: GoogleFonts.inter(color: TColors.muted))),
          data: (txs) => _PnlChart(transactions: txs),
        ),
      ),
    );
  }
}

class _PnlChart extends StatelessWidget {
  final List<Transaction> transactions;

  const _PnlChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Build 6-month bucket list (ordered oldest → newest)
    final months = List.generate(6, (i) {
      final m = now.month - 5 + i;
      final y = now.year + (m - 1) ~/ 12;
      final month = ((m - 1) % 12) + 1;
      return DateTime(y, month);
    });

    // Single-pass bucketing — O(n) instead of O(n × 6 × 3)
    final incomeMap = <int, double>{};
    final expenseMap = <int, double>{};
    for (final t in transactions) {
      final key = t.date.year * 100 + t.date.month;
      if (t.type == 'income') {
        incomeMap[key] = (incomeMap[key] ?? 0) + t.amount;
      } else if (t.type == 'expense') {
        expenseMap[key] = (expenseMap[key] ?? 0) + t.amount;
      }
    }

    final income = months.map((m) => incomeMap[m.year * 100 + m.month] ?? 0.0).toList();
    final expense = months.map((m) => expenseMap[m.year * 100 + m.month] ?? 0.0).toList();

    final maxY = [...income, ...expense]
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity) *
        1.2;

    final monthLabels = months
        .map((m) => DateFormat('MMM', 'ru').format(m))
        .toList();

    final barGroups = List.generate(6, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: income[i],
            color: TColors.green.withValues(alpha: .7),
            width: 10,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: expense[i],
            color: TColors.red.withValues(alpha: .6),
            width: 10,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        barsSpace: 3,
      );
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          barGroups: barGroups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
                color: TColors.border,
                strokeWidth: .8,
                dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (v, _) => Text(
                  v >= 1000
                      ? '${(v / 1000).toStringAsFixed(0)}K'
                      : v.toStringAsFixed(0),
                  style: TabysTheme.mono(size: 9, color: TColors.muted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= monthLabels.length) {
                    return const SizedBox();
                  }
                  return Text(
                    monthLabels[idx],
                    style: TabysTheme.mono(size: 10, color: TColors.muted),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => TColors.card2,
              getTooltipItem: (group, _, rod, rodIdx) {
                final label = rodIdx == 0 ? 'Доход' : 'Расход';
                final fmt = NumberFormat('#,##0', 'ru_RU');
                return BarTooltipItem(
                  '$label\n${fmt.format(rod.toY)}',
                  TabysTheme.mono(
                      size: 11,
                      color: rodIdx == 0 ? TColors.green : TColors.red),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Accounts Panel ───────────────────────────────────────────────────────────

class _AccountsPanel extends StatelessWidget {
  final AsyncValue<List<Account>> accountsAsync;
  final String currency;

  const _AccountsPanel(
      {required this.accountsAsync, required this.currency});

  @override
  Widget build(BuildContext context) {
    return _DashPanel(
      title: 'Счета',
      subtitle: accountsAsync.valueOrNull != null
          ? '${accountsAsync.valueOrNull!.length} активных'
          : '',
      child: accountsAsync.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(
                color: TColors.gold, strokeWidth: 2)),
        error: (_, __) => const SizedBox(),
        data: (accounts) => Column(
          children: accounts.map((a) => _AccountItem(account: a)).toList(),
        ),
      ),
    );
  }
}

class _AccountItem extends StatelessWidget {
  final Account account;
  const _AccountItem({required this.account});

  static const _icons = {
    'cash': ('💵', TColors.goldBg),
    'bank': ('🏦', TColors.blueBg),
    'card': ('💳', TColors.greenBg),
  };

  static final _fmt = NumberFormat('#,##0.##', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    final isNeg = account.balance < 0;
    final fmt = _fmt;
    final iconData = _icons[account.type] ?? ('💰', TColors.card2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconData.$2,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(iconData.$1, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: TColors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  account.type == 'cash'
                      ? 'Наличные'
                      : account.type == 'bank'
                          ? 'Банк'
                          : 'Карта',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: TColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isNeg
                    ? '−${fmt.format(account.balance.abs())}'
                    : fmt.format(account.balance),
                style: TabysTheme.mono(
                    size: 13,
                    color: isNeg ? TColors.red : TColors.text),
              ),
              Text(account.currency,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: TColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Transactions Panel ───────────────────────────────────────────────────────

class _TransactionsPanel extends StatelessWidget {
  final AsyncValue<List<Transaction>> txAsync;
  final String currency;

  const _TransactionsPanel(
      {required this.txAsync, required this.currency});

  @override
  Widget build(BuildContext context) {
    return _DashPanel(
      title: 'Последние транзакции',
      subtitle: DateFormat('d MMMM yyyy', 'ru').format(DateTime.now()),
      child: txAsync.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(
                color: TColors.gold, strokeWidth: 2)),
        error: (_, __) => const SizedBox(),
        data: (txs) {
          final recent = [...txs]
            ..sort((a, b) => b.date.compareTo(a.date));
          final shown = recent.take(6).toList();
          if (shown.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Нет транзакций за период',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: TColors.muted)),
            );
          }
          return Column(
            children: shown
                .map((t) =>
                    _TxItem(tx: t, currency: currency))
                .toList(),
          );
        },
      ),
    );
  }
}

class _TxItem extends StatelessWidget {
  final Transaction tx;
  final String currency;
  const _TxItem({required this.tx, required this.currency});

  static final _fmt = NumberFormat('#,##0.##', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == 'income';
    final isTransfer = tx.type == 'transfer';
    final color = isTransfer
        ? TColors.blue
        : isIncome
            ? TColors.green
            : TColors.red;
    final fmt = _fmt;
    final sign = isIncome ? '+' : isTransfer ? '' : '−';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: TColors.border.withValues(alpha: .5))),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: .4), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description?.isNotEmpty == true
                      ? tx.description!
                      : _typeLabel(tx.type),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: TColors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('dd.MM · HH:mm', 'ru').format(tx.date),
                  style: GoogleFonts.inter(
                      fontSize: 10, color: TColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '$sign${fmt.format(tx.amount)} $currency',
            style: TabysTheme.mono(size: 13, color: color),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'income' => 'Доход',
      'expense' => 'Расход',
      'transfer' => 'Перевод',
      _ => type,
    };
  }
}

// ─── AR Aging Panel ───────────────────────────────────────────────────────────

class _ArAgingPanel extends StatelessWidget {
  final AsyncValue<List<Invoice>> invoicesAsync;

  const _ArAgingPanel({required this.invoicesAsync});

  @override
  Widget build(BuildContext context) {
    return invoicesAsync.when(
      loading: () => _DashPanel(
        title: 'Дебиторка',
        subtitle: '',
        child: const SizedBox(height: 60),
      ),
      error: (_, __) => const SizedBox(),
      data: (invoices) {
        final pending = invoices
            .where((i) =>
                i.status == 'pending' || i.status == 'partial')
            .toList();

        final now = DateTime.now();
        double current = 0, days30 = 0, days60 = 0;
        for (final inv in pending) {
          if (inv.dueDate == null || inv.dueDate!.isAfter(now)) {
            current += inv.totalAmount;
          } else {
            final overdue = now.difference(inv.dueDate!).inDays;
            if (overdue <= 30) {
              days30 += inv.totalAmount;
            } else {
              days60 += inv.totalAmount;
            }
          }
        }
        final total = current + days30 + days60;

        return _DashPanel(
          title: 'Дебиторка',
          subtitle: total > 0
              ? 'Итого: ${NumberFormat('#,##0', 'ru_RU').format(total)}'
              : 'Нет задолженностей',
          child: total == 0
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Всё оплачено',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: TColors.muted)),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    children: [
                      _AgingBar('Текущие', current, total, TColors.blue),
                      const SizedBox(height: 10),
                      _AgingBar(
                          '1–30 дней', days30, total, const Color(0xFFF5A524)),
                      const SizedBox(height: 10),
                      _AgingBar(
                          '31–60 дней', days60, total, TColors.red),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _AgingBar extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  final Color color;

  const _AgingBar(this.label, this.value, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    final fmt = NumberFormat('#,##0', 'ru_RU');

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: TColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            fmt.format(value),
            style: TabysTheme.mono(size: 11, color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ─── Tasks Panel ──────────────────────────────────────────────────────────────

class _TasksPanel extends StatelessWidget {
  final AsyncValue<List<Task>> tasksAsync;
  const _TasksPanel({required this.tasksAsync});

  @override
  Widget build(BuildContext context) {
    return tasksAsync.when(
      loading: () => _DashPanel(
          title: 'Задачи', subtitle: '', child: const SizedBox(height: 60)),
      error: (_, __) => const SizedBox(),
      data: (tasks) {
        final active = tasks
            .where((t) => t.status != 'done' && t.status != 'cancelled')
            .take(4)
            .toList();
        final done =
            tasks.where((t) => t.status == 'done').take(1).toList();
        final shown = [...active, ...done];

        return _DashPanel(
          title: 'Задачи',
          subtitle: '${active.length} активных',
          child: Column(
            children: shown.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Задач нет',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: TColors.muted)),
                    )
                  ]
                : shown.map((t) => _TaskItem(task: t)).toList(),
          ),
        );
      },
    );
  }
}

class _TaskItem extends StatelessWidget {
  final Task task;
  const _TaskItem({required this.task});

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'done';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: TColors.border.withValues(alpha: .5))),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isDone ? TColors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: isDone ? TColors.green : TColors.border2,
                  width: 1.5),
            ),
            child: isDone
                ? const Icon(Icons.check, size: 10, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDone ? TColors.muted : TColors.text,
                    decoration:
                        isDone ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.dueDate != null)
                  Text(
                    'Срок: ${DateFormat('d MMM', 'ru').format(task.dueDate!)}',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: TColors.muted),
                  ),
              ],
            ),
          ),
          isDone
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: TColors.greenBg,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('Готово',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: TColors.green)),
                )
              : PriorityBadge(priority: task.priority),
        ],
      ),
    );
  }
}

// ─── Shared panel shell ───────────────────────────────────────────────────────

class _DashPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _DashPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.syne(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: TColors.text)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: TColors.muted)),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}
