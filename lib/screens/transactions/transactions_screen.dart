import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../../providers/database_provider.dart';
import '../../db/database.dart';
import '../../services/csv_export.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _search = '';
  int? _categoryFilter;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(transactionsProvider);
    final company = ref.watch(selectedCompanyProvider);
    final range = ref.watch(transactionDateRangeProvider);
    final cats = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catMap = {for (final c in cats) c.id: c.name};
    final accMap = {
      for (final a in ref.watch(accountsProvider).valueOrNull ?? []) a.id: a.name,
    };

    return Scaffold(
      body: Column(
        children: [
          // Period + search row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('dd.MM.yyyy').format(range.from)} — ${DateFormat('dd.MM.yyyy').format(range.to)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _pickDateRange(context, ref, range),
                  child: const Text('Изменить'),
                ),
                // CSV export
                txsAsync.maybeWhen(
                  data: (txs) => IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Экспорт CSV',
                    onPressed: txs.isEmpty ? null : () => _exportCsv(context, ref, txs),
                  ),
                  orElse: () => const SizedBox(),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Поиск по описанию, категории, счёту...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          // Category filter dropdown
          if (cats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: DropdownButtonFormField<int?>(
                initialValue: _categoryFilter,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Все категории')),
                  ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _categoryFilter = v),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: txsAsync.when(
              data: (txs) {
                var filtered = txs;
                if (_search.isNotEmpty) {
                  filtered = filtered.where((t) =>
                    (t.description?.toLowerCase().contains(_search) ?? false) ||
                    (t.categoryId != null &&
                        (catMap[t.categoryId!]?.toLowerCase().contains(_search) ?? false)) ||
                    (accMap[t.accountId]?.toLowerCase().contains(_search) ?? false)
                  ).toList();
                }
                if (_categoryFilter != null) {
                  filtered = filtered.where((t) => t.categoryId == _categoryFilter).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _search.isNotEmpty
                          ? 'Ничего не найдено'
                          : 'Нет транзакций за выбранный период',
                    ),
                  );
                }
                return _TransactionList(transactions: filtered);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: company != null
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _TransactionDialog(companyId: company.id),
              ),
            )
          : null,
    );
  }

  Future<void> _pickDateRange(
    BuildContext context,
    WidgetRef ref,
    DateRange current,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: current.from, end: current.to),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      ref.read(transactionDateRangeProvider.notifier).state = DateRange(
        from: picked.start,
        to: picked.end,
      );
    }
  }

  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref,
    List<Transaction> txs,
  ) async {
    final cats = ref.read(categoriesProvider).valueOrNull ?? [];
    final accounts = ref.read(accountsProvider).valueOrNull ?? [];
    final catMap = {for (final c in cats) c.id: c.name};
    final accMap = {for (final a in accounts) a.id: a.name};

    try {
      final file = await CsvExport.exportTransactions(txs, catMap, accMap);
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
}

class _TransactionList extends ConsumerWidget {
  final List<Transaction> transactions;

  const _TransactionList({required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return categoriesAsync.when(
      data: (cats) {
        final catMap = {for (final c in cats) c.id: c.name};
        return accountsAsync.when(
          data: (accounts) {
            final accMap = {for (final a in accounts) a.id: a.name};

            // Per-category averages for anomaly detection (needs ≥2 txs)
            final catSums = <int, double>{};
            final catCounts = <int, int>{};
            for (final t in transactions) {
              if (t.categoryId != null) {
                catSums[t.categoryId!] = (catSums[t.categoryId!] ?? 0) + t.amount;
                catCounts[t.categoryId!] = (catCounts[t.categoryId!] ?? 0) + 1;
              }
            }
            final catAvg = {
              for (final e in catSums.entries)
                if ((catCounts[e.key] ?? 0) >= 2) e.key: e.value / catCounts[e.key]!
            };

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              itemBuilder: (ctx, i) => _TxTile(
                tx: transactions[i],
                catMap: catMap,
                accMap: accMap,
                catAvg: catAvg,
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
    );
  }
}

class _TxTile extends ConsumerWidget {
  final Transaction tx;
  final Map<int, String> catMap;
  final Map<int, String> accMap;
  final Map<int, double> catAvg;

  const _TxTile({
    required this.tx,
    required this.catMap,
    required this.accMap,
    required this.catAvg,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,##0.##', 'ru_RU');
    final isIncome = tx.type == 'income';
    final isTransfer = tx.type == 'transfer';

    Color color;
    IconData icon;
    if (isTransfer) {
      color = Colors.blue;
      icon = Icons.swap_horiz;
    } else if (isIncome) {
      color = Colors.green;
      icon = Icons.arrow_downward;
    } else {
      color = Colors.red;
      icon = Icons.arrow_upward;
    }

    final avg = tx.categoryId != null ? catAvg[tx.categoryId!] : null;
    final isAnomaly = avg != null && tx.amount > avg * 3.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                tx.description ?? (tx.categoryId != null ? (catMap[tx.categoryId!] ?? 'Без категории') : 'Без категории'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isAnomaly)
              Tooltip(
                message: 'Необычно высокая сумма для этой категории',
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.warning_amber_rounded, size: 15, color: Colors.amber),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${accMap[tx.accountId] ?? '?'} · ${DateFormat('dd.MM.yyyy').format(tx.date)}'
          '${tx.categoryId != null ? ' · ${catMap[tx.categoryId!]}' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tx.isRecurring)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.repeat, size: 14, color: Colors.grey[500]),
              ),
            Text(
              '${isIncome ? '+' : isTransfer ? '' : '−'}${fmt.format(tx.amount)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        onTap: () => showDialog(
          context: context,
          builder: (_) => _TransactionDialog(
            companyId: tx.companyId,
            existing: tx,
          ),
        ),
        onLongPress: () => _confirmDelete(context, ref),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить транзакцию?'),
        content: const Text('Баланс счёта будет скорректирован.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final db = ref.read(databaseProvider);
              final messenger = ScaffoldMessenger.of(context);
              await db.deleteTransaction(tx.id);
              messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Транзакция удалена'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'Отменить',
                      onPressed: () => db.insertTransaction(
                        TransactionsCompanion.insert(
                          companyId: tx.companyId,
                          accountId: tx.accountId,
                          amount: tx.amount,
                          type: tx.type,
                          date: tx.date,
                          categoryId: Value(tx.categoryId),
                          toAccountId: Value(tx.toAccountId),
                          description: Value(tx.description),
                          isFixed: Value(tx.isFixed),
                          isRecurring: Value(tx.isRecurring),
                          recurrenceInterval: Value(tx.recurrenceInterval),
                        ),
                      ),
                    ),
                  ),
                );
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _TransactionDialog extends ConsumerStatefulWidget {
  final int companyId;
  final Transaction? existing;

  const _TransactionDialog({required this.companyId, this.existing});

  @override
  ConsumerState<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends ConsumerState<_TransactionDialog> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late String _type;
  late int? _accountId;
  late int? _toAccountId;
  late int? _categoryId;
  late DateTime _date;
  late bool _isFixed;
  late bool _isRecurring;
  late String _recurrenceInterval;

  @override
  void initState() {
    super.initState();
    final tx = widget.existing;
    _amountCtrl = TextEditingController(
      text: tx != null ? tx.amount.toStringAsFixed(2) : '',
    );
    _descCtrl = TextEditingController(text: tx?.description ?? '');
    _type = tx?.type ?? 'expense';
    _accountId = tx?.accountId;
    _toAccountId = tx?.toAccountId;
    _categoryId = tx?.categoryId;
    _date = tx?.date ?? DateTime.now();
    _isFixed = tx?.isFixed ?? false;
    _isRecurring = tx?.isRecurring ?? false;
    _recurrenceInterval = tx?.recurrenceInterval ?? 'monthly';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return accountsAsync.when(
      data: (accounts) => categoriesAsync.when(
        data: (allCats) {
          final cats = allCats.where((c) => c.type == _type).toList();
          return AlertDialog(
            title: Text(widget.existing == null ? 'Новая транзакция' : 'Редактировать транзакцию'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'income', label: Text('Доход')),
                      ButtonSegment(value: 'expense', label: Text('Расход')),
                      ButtonSegment(value: 'transfer', label: Text('Перевод')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) =>
                        setState(() => _type = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(labelText: 'Счёт'),
                    items: accounts
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                  if (_type == 'transfer') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _toAccountId,
                      decoration: const InputDecoration(labelText: 'На счёт'),
                      items: accounts
                          .where((a) => a.id != _accountId)
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _toAccountId = v),
                    ),
                  ],
                  if (_type != 'transfer') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(labelText: 'Категория'),
                      items: cats
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Дата: ${DateFormat('dd.MM.yyyy').format(_date)}',
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: _pickDate,
                  ),
                  TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Описание (необязательно)'),
                  ),
                  if (_type == 'expense') ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Постоянный расход (для EBITDA)'),
                      value: _isFixed,
                      onChanged: (v) => setState(() => _isFixed = v!),
                    ),
                  ],
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Повторяющаяся транзакция'),
                    value: _isRecurring,
                    onChanged: (v) => setState(() => _isRecurring = v!),
                  ),
                  if (_isRecurring) ...[
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _recurrenceInterval,
                      decoration: const InputDecoration(labelText: 'Периодичность'),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Ежедневно')),
                        DropdownMenuItem(value: 'weekly', child: Text('Еженедельно')),
                        DropdownMenuItem(value: 'monthly', child: Text('Ежемесячно')),
                      ],
                      onChanged: (v) => setState(() => _recurrenceInterval = v!),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: _save,
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => Text('$e'),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('$e'),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ru'),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0 || _accountId == null) return;

    // Duplicate detection for new transactions only
    if (widget.existing == null) {
      final allTxs = ref.read(transactionsProvider).valueOrNull ?? [];
      final from = _date.subtract(const Duration(days: 3));
      final to = _date.add(const Duration(days: 3));
      final dupes = allTxs.where((t) =>
          t.amount == amount &&
          t.type == _type &&
          t.accountId == _accountId &&
          t.date.isAfter(from) &&
          t.date.isBefore(to)).toList();

      if (dupes.isNotEmpty) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Возможный дубликат'),
            content: Text(
              'Найдена похожая транзакция на ${NumberFormat('#,##0.##', 'ru_RU').format(amount)} '
              'в течение ±3 дней. Добавить всё равно?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Добавить'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    final desc = Value(_descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim());
    final db = ref.read(databaseProvider);

    if (widget.existing != null) {
      db.updateTransaction(
        widget.existing!.id,
        TransactionsCompanion(
          companyId: Value(widget.companyId),
          accountId: Value(_accountId!),
          amount: Value(amount),
          type: Value(_type),
          date: Value(_date),
          categoryId: Value(_categoryId),
          toAccountId: Value(_toAccountId),
          description: desc,
          isFixed: Value(_isFixed),
          isRecurring: Value(_isRecurring),
          recurrenceInterval: Value(_isRecurring ? _recurrenceInterval : null),
        ),
      );
    } else {
      db.insertTransaction(
        TransactionsCompanion.insert(
          companyId: widget.companyId,
          accountId: _accountId!,
          amount: amount,
          type: _type,
          date: _date,
          categoryId: Value(_categoryId),
          toAccountId: Value(_toAccountId),
          description: desc,
          isFixed: Value(_isFixed),
          isRecurring: Value(_isRecurring),
          recurrenceInterval: Value(_isRecurring ? _recurrenceInterval : null),
        ),
      );
    }
    Navigator.pop(context);
  }
}
