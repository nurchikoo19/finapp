import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../../db/database.dart';
import '../../providers/database_provider.dart';
import '../../services/csv_export.dart';
import '../../services/pdf_invoice.dart';

String _fmtQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

// ─── Providers ────────────────────────────────────────────────────────────────

final invoicesProvider = StreamProvider<List<Invoice>>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchInvoicesByCompany(company.id);
});

// ─── Main Screen ──────────────────────────────────────────────────────────────

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _search = '';
  String? _statusFilter; // null = все
  bool _showLtv = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportCsv(BuildContext context, List<Invoice> list) async {
    try {
      final file = await CsvExport.exportInvoices(list);
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

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final company = ref.watch(selectedCompanyProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Поиск по клиенту, номеру, описанию...',
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
          // View toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Инвойсы'),
                  selected: !_showLtv,
                  onSelected: (_) => setState(() => _showLtv = false),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Клиенты (LTV)'),
                  selected: _showLtv,
                  onSelected: (_) => setState(() => _showLtv = true),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Status filter chips (only in invoice view)
          if (!_showLtv) SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                _StatusChip(
                  label: 'Все',
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: 'Ожидает',
                  color: Colors.blue,
                  selected: _statusFilter == 'pending',
                  onTap: () => setState(() =>
                      _statusFilter = _statusFilter == 'pending' ? null : 'pending'),
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: 'Частично',
                  color: Colors.orange,
                  selected: _statusFilter == 'partial',
                  onTap: () => setState(() =>
                      _statusFilter = _statusFilter == 'partial' ? null : 'partial'),
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: 'Оплачен',
                  color: Colors.green,
                  selected: _statusFilter == 'paid',
                  onTap: () => setState(() =>
                      _statusFilter = _statusFilter == 'paid' ? null : 'paid'),
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: 'Просроченные',
                  color: Colors.red,
                  selected: _statusFilter == 'overdue',
                  onTap: () => setState(() =>
                      _statusFilter = _statusFilter == 'overdue' ? null : 'overdue'),
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: 'Отменён',
                  color: Colors.grey,
                  selected: _statusFilter == 'cancelled',
                  onTap: () => setState(() =>
                      _statusFilter = _statusFilter == 'cancelled' ? null : 'cancelled'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _showLtv
                ? invoicesAsync.when(
                    data: (list) => _ClientLtvView(invoices: list),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                  )
                : invoicesAsync.when(
              data: (list) {
                final now = DateTime.now();
                List<Invoice> filtered = list;
                if (_statusFilter == 'overdue') {
                  filtered = list.where((inv) =>
                      inv.dueDate != null &&
                      inv.dueDate!.isBefore(now) &&
                      inv.status != 'paid' &&
                      inv.status != 'cancelled').toList();
                } else if (_statusFilter != null) {
                  filtered = list.where((inv) => inv.status == _statusFilter).toList();
                }
                if (_search.isNotEmpty) {
                  filtered = filtered.where((inv) =>
                      inv.clientName.toLowerCase().contains(_search) ||
                      (inv.invoiceNumber?.toLowerCase().contains(_search) ?? false) ||
                      (inv.description?.toLowerCase().contains(_search) ?? false)).toList();
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _search.isNotEmpty ? 'Ничего не найдено' : 'Нет счетов',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                        if (_search.isEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Создайте первый счёт для клиента',
                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    _SummaryBar(invoices: filtered),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _InvoiceCard(invoice: filtered[i]),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
      floatingActionButton: !_showLtv && company != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // CSV export
                invoicesAsync.maybeWhen(
                  data: (list) => list.isEmpty
                      ? const SizedBox()
                      : FloatingActionButton.small(
                          heroTag: 'csv',
                          tooltip: 'Экспорт CSV',
                          onPressed: () => _exportCsv(context, list),
                          child: const Icon(Icons.download),
                        ),
                  orElse: () => const SizedBox(),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'add',
                  icon: const Icon(Icons.add),
                  label: const Text('Новый счёт'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _InvoiceDialog(companyId: company.id),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

// ─── Summary Bar ──────────────────────────────────────────────────────────────

class _SummaryBar extends ConsumerWidget {
  final List<Invoice> invoices;
  const _SummaryBar({required this.invoices});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final pending = invoices.where((i) => i.status == 'pending').length;
    final partial = invoices.where((i) => i.status == 'partial').length;
    final paid = invoices.where((i) => i.status == 'paid').length;
    final totalSum = invoices.fold(0.0, (s, i) => s + i.totalAmount);

    return FutureBuilder<double>(
      future: Future.wait(invoices.map((i) => db.getPaidAmountForInvoice(i.id)))
          .then((list) => list.fold<double>(0.0, (s, v) => s + v)),
      builder: (ctx, snap) {
        final totalPaid = snap.data ?? 0;
        final totalRemaining = totalSum - totalPaid;
        final fmt = NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 0);

        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _BarItem(label: 'Всего', value: fmt.format(totalSum), color: Colors.blue)),
                  Expanded(child: _BarItem(label: 'Получено', value: fmt.format(totalPaid), color: Colors.green)),
                  Expanded(child: _BarItem(label: 'Осталось', value: fmt.format(totalRemaining), color: Colors.orange)),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  _StatusCount(label: 'Новые', count: pending, color: Colors.blue),
                  _StatusCount(label: 'Частично', count: partial, color: Colors.orange),
                  _StatusCount(label: 'Оплачено', count: paid, color: Colors.green),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BarItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BarItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _StatusCount extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatusCount({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $count',
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Invoice Card ─────────────────────────────────────────────────────────────

class _InvoiceCard extends ConsumerWidget {
  final Invoice invoice;
  const _InvoiceCard({required this.invoice});

  static const _statusLabels = {
    'pending': 'Ожидает',
    'partial': 'Частично',
    'paid': 'Оплачен',
    'cancelled': 'Отменён',
  };

  static const _statusColors = {
    'pending': Colors.blue,
    'partial': Colors.orange,
    'paid': Colors.green,
    'cancelled': Colors.grey,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final fmt = NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 0);
    final color = _statusColors[invoice.status] ?? Colors.grey;

    return FutureBuilder<double>(
      future: db.getPaidAmountForInvoice(invoice.id),
      builder: (ctx, snap) {
        final paid = snap.data ?? 0;
        final remaining = invoice.totalAmount - paid;
        final pct = invoice.totalAmount > 0 ? paid / invoice.totalAmount : 0.0;
        final isOverdue = invoice.dueDate != null &&
            invoice.dueDate!.isBefore(DateTime.now()) &&
            invoice.status != 'paid' &&
            invoice.status != 'cancelled';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _InvoiceDetailScreen(invoice: invoice),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          invoice.clientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _statusLabels[invoice.status] ?? invoice.status,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (invoice.description != null &&
                      invoice.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(invoice.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  // Amounts row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Сумма сделки',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[600])),
                            Text(
                              '${fmt.format(invoice.totalAmount)} ${invoice.currency}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Внесено',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[600])),
                            Text(
                              '${fmt.format(paid)} ${invoice.currency}',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Остаток',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[600])),
                            Text(
                              '${fmt.format(remaining)} ${invoice.currency}',
                              style: TextStyle(
                                  color: remaining > 0
                                      ? Colors.orange
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          AlwaysStoppedAnimation(pct >= 1 ? Colors.green : Colors.blue),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}% оплачено',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      if (invoice.dueDate != null)
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 12,
                                color: isOverdue ? Colors.red : Colors.grey),
                            const SizedBox(width: 3),
                            Text(
                              DateFormat('dd.MM.yyyy').format(invoice.dueDate!),
                              style: TextStyle(
                                fontSize: 11,
                                color: isOverdue ? Colors.red : Colors.grey[600],
                                fontWeight: isOverdue ? FontWeight.bold : null,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (isOverdue) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 13, color: Colors.red),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text('Просроченный платёж',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.red)),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _copyReminder(context, paid),
                          child: const Text('Напомнить',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _copyReminder(BuildContext context, double paid) {
    final remaining = invoice.totalAmount - paid;
    final number = invoice.invoiceNumber?.isNotEmpty == true
        ? invoice.invoiceNumber!
        : '—';
    final dateStr = DateFormat('dd.MM.yyyy').format(invoice.createdAt);
    final dueStr = invoice.dueDate != null
        ? DateFormat('dd.MM.yyyy').format(invoice.dueDate!)
        : '—';
    final fmt = NumberFormat('#,##0', 'ru_RU');
    final text = 'Уважаемый(ая) ${invoice.clientName}!\n\n'
        'Напоминаем о задолженности по счёту №$number от $dateStr '
        'на сумму ${fmt.format(invoice.totalAmount)} ${invoice.currency}.\n\n'
        'Срок оплаты истёк: $dueStr\n'
        'Остаток к оплате: ${fmt.format(remaining)} ${invoice.currency}\n\n'
        'Просим погасить задолженность в ближайшее время.\n\n'
        'С уважением.';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Письмо-напоминание скопировано в буфер'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── Invoice Detail Screen ────────────────────────────────────────────────────

class _InvoiceDetailScreen extends ConsumerWidget {
  final Invoice invoice;
  const _InvoiceDetailScreen({required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsStream =
        ref.watch(databaseProvider).watchPaymentsByInvoice(invoice.id);
    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.clientName),
        actions: [
          // Print PDF
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Печать PDF',
            onPressed: () => _printPdf(context, ref, invoice),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              final company = ref.read(selectedCompanyProvider);
              if (company == null) return;
              showDialog(
                context: context,
                builder: (_) => _InvoiceDialog(
                  companyId: company.id,
                  existing: invoice,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: StreamBuilder<List<InvoicePayment>>(
        stream: paymentsStream,
        builder: (ctx, snap) {
          final payments = snap.data ?? [];
          final paid = payments.fold(0.0, (s, p) => s + p.amount);
          final remaining = invoice.totalAmount - paid;
          final pct = invoice.totalAmount > 0
              ? (paid / invoice.totalAmount).clamp(0.0, 1.0)
              : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Main info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (invoice.description != null &&
                          invoice.description!.isNotEmpty) ...[
                        Text(invoice.description!,
                            style: TextStyle(color: Colors.grey[700])),
                        const Divider(height: 20),
                      ],
                      Row(
                        children: [
                          _DetailItem(
                            label: 'Сумма сделки',
                            value:
                                '${fmt.format(invoice.totalAmount)} ${invoice.currency}',
                            valueStyle: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (invoice.dueDate != null)
                            _DetailItem(
                              label: 'Дата оплаты',
                              value: DateFormat('dd.MM.yyyy')
                                  .format(invoice.dueDate!),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _DetailItem(
                              label: 'Внесено',
                              value:
                                  '${fmt.format(paid)} ${invoice.currency}',
                              valueStyle: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: _DetailItem(
                              label: 'Остаток',
                              value:
                                  '${fmt.format(remaining)} ${invoice.currency}',
                              valueStyle: TextStyle(
                                  color: remaining > 0
                                      ? Colors.orange
                                      : Colors.green,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                              pct >= 1 ? Colors.green : Colors.blue),
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(pct * 100).toStringAsFixed(1)}% оплачено',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),

                      // Менеджер + комиссия
                      if (invoice.salesPersonId != null) ...[
                        const Divider(height: 20),
                        Consumer(builder: (_, r, __) {
                          final emps =
                              r.watch(employeesProvider).valueOrNull ?? [];
                          final emp = emps
                              .where((e) => e.id == invoice.salesPersonId)
                              .firstOrNull;
                          if (emp == null) return const SizedBox();
                          final commission = invoice.commissionPct > 0
                              ? invoice.totalAmount *
                                  invoice.commissionPct /
                                  100
                              : null;
                          return Row(children: [
                            const Icon(Icons.person_outline,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Менеджер: ${emp.name}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  if (commission != null)
                                    Text(
                                      'Комиссия ${invoice.commissionPct.toStringAsFixed(1)}% = '
                                      '${fmt.format(commission)} ${invoice.currency}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[700]),
                                    ),
                                ],
                              ),
                            ),
                          ]);
                        }),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Items section
              FutureBuilder<List<InvoiceItem>>(
                future: ref.read(databaseProvider).getItemsByInvoice(invoice.id),
                builder: (ctx, itemSnap) {
                  final items = itemSnap.data ?? [];
                  if (items.isEmpty) return const SizedBox();
                  final fmt2 = NumberFormat('#,##0', 'ru_RU');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Позиции счёта',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: items.asMap().entries.map((e) {
                            final it = e.value;
                            final lineTotal = it.qty * it.unitPrice;
                            final lineVat = lineTotal * it.vatRate / 100;
                            return ListTile(
                              dense: true,
                              title: Text(it.description,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: Text(
                                  '${_fmtQty(it.qty)} ${it.unit} × ${fmt2.format(it.unitPrice)}'
                                  '${it.vatRate > 0 ? "  НДС ${it.vatRate.toInt()}%" : ""}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(fmt2.format(lineTotal + lineVat),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  if (lineVat > 0)
                                    Text('НДС: ${fmt2.format(lineVat)}',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600])),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

              // Payments section
              Row(
                children: [
                  Text('История оплат',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (invoice.status != 'paid' &&
                      invoice.status != 'cancelled') ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('→ Транзакция'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        side: BorderSide(color: Colors.green[700]!),
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _InvoiceToTransactionDialog(
                          invoice: invoice,
                          remaining: remaining,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Внести оплату'),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _PaymentDialog(
                          invoice: invoice,
                          remaining: remaining,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              if (payments.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Оплат ещё не было'),
                  ),
                )
              else
                ...payments.map((p) => _PaymentTile(
                      payment: p,
                      currency: invoice.currency,
                    )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _printPdf(
      BuildContext context, WidgetRef ref, Invoice inv) async {
    final db = ref.read(databaseProvider);
    final company = ref.read(selectedCompanyProvider);

    // Show print params dialog first
    if (!context.mounted) return;
    final params = await showDialog<_PrintParams>(
      context: context,
      builder: (_) => _PrintParamsDialog(company: company),
    );
    if (params == null) return; // user cancelled

    final payments = await db.getPaymentsByInvoice(inv.id);
    final items = await db.getItemsByInvoice(inv.id);
    if (!context.mounted) return;
    await PdfInvoiceService.printInvoice(
      inv,
      payments,
      items,
      company: company,
      sellerName: params.sellerName,
      sellerInn: params.sellerInn,
      sellerAddress: params.sellerAddress,
      sellerBankDetails: params.sellerBankDetails,
      signerSeller: params.signerSeller,
      signerBuyer: params.signerBuyer,
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить счёт?'),
        content: const Text('Все оплаты по этому счёту также будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(databaseProvider).deleteInvoice(invoice.id);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _DetailItem({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value,
            style: valueStyle ??
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PaymentTile extends ConsumerWidget {
  final InvoicePayment payment;
  final String currency;
  const _PaymentTile({required this.payment, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 0);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.payments, color: Colors.green, size: 20),
        ),
        title: Text(
          '${fmt.format(payment.amount)} $currency',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.green),
        ),
        subtitle: Text(
          DateFormat('dd.MM.yyyy').format(payment.date) +
              (payment.note != null && payment.note!.isNotEmpty
                  ? ' · ${payment.note}'
                  : ''),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
          onPressed: () => ref
              .read(databaseProvider)
              .deleteInvoicePayment(payment.id),
        ),
      ),
    );
  }
}

// ─── Invoice Dialog ───────────────────────────────────────────────────────────

class _InvoiceDialog extends ConsumerStatefulWidget {
  final int companyId;
  final Invoice? existing;
  const _InvoiceDialog({required this.companyId, this.existing});

  @override
  ConsumerState<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends ConsumerState<_InvoiceDialog> {
  late final TextEditingController _numberCtrl;
  late final TextEditingController _clientCtrl;
  late final TextEditingController _clientDetailsCtrl;
  late final TextEditingController _descCtrl;
  late String _currency;
  DateTime? _dueDate;
  int? _salesPersonId;
  late final TextEditingController _commissionCtrl;

  // Line items
  final List<_ItemRow> _items = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _numberCtrl = TextEditingController(text: e?.invoiceNumber ?? '');
    _clientCtrl = TextEditingController(text: e?.clientName ?? '');
    _clientDetailsCtrl =
        TextEditingController(text: e?.clientDetails ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _currency = e?.currency ?? 'KGS';
    _dueDate = e?.dueDate;
    _salesPersonId = e?.salesPersonId;
    _commissionCtrl = TextEditingController(
      text: e != null && e.commissionPct > 0
          ? e.commissionPct.toStringAsFixed(1)
          : '',
    );

    // Load existing items
    if (e != null) {
      ref.read(databaseProvider).getItemsByInvoice(e.id).then((items) {
        if (mounted) {
          setState(() {
            _items.addAll(items.map((it) => _ItemRow(
                  descCtrl:
                      TextEditingController(text: it.description),
                  qtyCtrl: TextEditingController(
                      text: _fmtQty(it.qty)),
                  unitCtrl:
                      TextEditingController(text: it.unit),
                  priceCtrl: TextEditingController(
                      text: it.unitPrice.toStringAsFixed(0)),
                  vatRate: it.vatRate,
                )));
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _clientCtrl.dispose();
    _clientDetailsCtrl.dispose();
    _commissionCtrl.dispose();
    _descCtrl.dispose();
    for (final r in _items) {
      r.dispose();
    }
    super.dispose();
  }

  double get _computedTotal => _items.fold(0.0, (s, r) {
        final qty = double.tryParse(r.qtyCtrl.text
                .replaceAll(' ', '')
                .replaceAll(',', '.')) ??
            0;
        final price = double.tryParse(r.priceCtrl.text
                .replaceAll(' ', '')
                .replaceAll(',', '.')) ??
            0;
        final vat = qty * price * r.vatRate / 100;
        return s + qty * price + vat;
      });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.existing == null
                ? 'Новый счёт на оплату'
                : 'Редактировать счёт'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              FilledButton(
                onPressed: _save,
                child: const Text('Сохранить'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header fields
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _numberCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Номер счёта',
                          prefixIcon: Icon(Icons.tag)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration:
                          const InputDecoration(labelText: 'Валюта'),
                      items: const [
                        DropdownMenuItem(value: 'KGS', child: Text('с Сом')),
                        DropdownMenuItem(
                            value: 'RUB', child: Text('₽ Рубль')),
                        DropdownMenuItem(
                            value: 'USD', child: Text('\$ Доллар')),
                        DropdownMenuItem(
                            value: 'EUR', child: Text('€ Евро')),
                        DropdownMenuItem(
                            value: 'KZT', child: Text('₸ Тенге')),
                      ],
                      onChanged: (v) => setState(() => _currency = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _clientCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Покупатель *',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _clientDetailsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Реквизиты покупателя (ИНН, адрес...)',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Назначение / описание',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Менеджер по продаже + комиссия
                Consumer(
                  builder: (_, r, __) {
                    final emps = r.watch(employeesProvider).valueOrNull ?? [];
                    if (emps.isEmpty) return const SizedBox();
                    return Column(
                      children: [
                        DropdownButtonFormField<int?>(
                          value: _salesPersonId,
                          decoration: const InputDecoration(
                            labelText: 'Менеджер по продаже',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('— Не назначен —')),
                            ...emps.map((e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(e.name),
                                )),
                          ],
                          onChanged: (v) =>
                              setState(() => _salesPersonId = v),
                        ),
                        if (_salesPersonId != null) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _commissionCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Комиссия %',
                              prefixIcon: Icon(Icons.percent),
                              hintText: 'Например: 5',
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    _dueDate != null
                        ? 'Дата оплаты: ${DateFormat('dd.MM.yyyy').format(_dueDate!)}'
                        : 'Дата оплаты (необязательно)',
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: _dueDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _dueDate = null),
                        )
                      : null,
                  onTap: _pickDate,
                ),

                const Divider(height: 24),

                // ── Line items
                Row(children: [
                  Text('Позиции счёта',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Добавить строку'),
                    onPressed: () => setState(() => _items.add(_ItemRow())),
                  ),
                ]),
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                        'Без позиций — укажите общую сумму ниже',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  )
                else ...[
                  // Column headers
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                          flex: 4,
                          child: Text('Наименование',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600))),
                      SizedBox(width: 6),
                      SizedBox(
                          width: 48,
                          child: Text('Кол.',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600))),
                      SizedBox(width: 6),
                      SizedBox(
                          width: 44,
                          child: Text('Ед.',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600))),
                      SizedBox(width: 6),
                      SizedBox(
                          width: 72,
                          child: Text('Цена без НДС',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600))),
                      SizedBox(width: 6),
                      SizedBox(
                          width: 64,
                          child: Text('НДС%',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600))),
                      SizedBox(width: 32),
                    ]),
                  ),
                  ..._items.asMap().entries.map((e) =>
                      _ItemRowWidget(
                        key: ValueKey(e.key),
                        row: e.value,
                        onRemove: () =>
                            setState(() => _items.removeAt(e.key)),
                        onChanged: () => setState(() {}),
                      )),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Итого к оплате: ${NumberFormat('#,##0', 'ru_RU').format(_computedTotal)} $_currency',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],

                // Manual total (only if no items)
                if (_items.isEmpty) ...[
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Сумма счёта *',
                      prefixIcon: const Icon(Icons.attach_money),
                      suffixText: _currency,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() {}),
                    controller: _manualAmountCtrl,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  late final TextEditingController _manualAmountCtrl =
      TextEditingController(
          text: widget.existing != null && widget.existing!.totalAmount > 0
              ? widget.existing!.totalAmount.toStringAsFixed(0)
              : '');

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ru'),
    );
    if (d != null) setState(() => _dueDate = d);
  }

  void _save() async {
    final client = _clientCtrl.text.trim();
    if (client.isEmpty) return;

    double total;
    if (_items.isNotEmpty) {
      total = _computedTotal;
    } else {
      total = double.tryParse(
              _manualAmountCtrl.text.replaceAll(',', '.').replaceAll(' ', '')) ??
          0;
      if (total <= 0) return;
    }

    final db = ref.read(databaseProvider);
    final rawNumber = _numberCtrl.text.trim();
    final number = rawNumber.isEmpty
        ? null
        : rawNumber.padLeft(8, '0');
    final clientDetails = _clientDetailsCtrl.text.trim().isEmpty
        ? null
        : _clientDetailsCtrl.text.trim();
    final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

    final commissionPct = double.tryParse(
            _commissionCtrl.text.replaceAll(',', '.')) ??
        0.0;

    int invoiceId;
    if (widget.existing == null) {
      invoiceId = await db.insertInvoice(InvoicesCompanion.insert(
        companyId: widget.companyId,
        invoiceNumber: Value(number),
        clientName: client,
        clientDetails: Value(clientDetails),
        totalAmount: total,
        currency: Value(_currency),
        description: Value(desc),
        dueDate: Value(_dueDate),
        salesPersonId: Value(_salesPersonId),
        commissionPct: Value(commissionPct),
      ));
    } else {
      invoiceId = widget.existing!.id;
      await db.updateInvoice(InvoicesCompanion(
        id: Value(invoiceId),
        companyId: Value(widget.companyId),
        invoiceNumber: Value(number),
        clientName: Value(client),
        clientDetails: Value(clientDetails),
        totalAmount: Value(total),
        currency: Value(_currency),
        description: Value(desc),
        dueDate: Value(_dueDate),
        salesPersonId: Value(_salesPersonId),
        commissionPct: Value(commissionPct),
      ));
    }

    // Save items
    if (_items.isNotEmpty) {
      final companions = _items.map((r) {
        final qty = double.tryParse(
                r.qtyCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ??
            1;
        final price = double.tryParse(
                r.priceCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ??
            0;
        return InvoiceItemsCompanion.insert(
          invoiceId: invoiceId,
          description: r.descCtrl.text.trim().isEmpty
              ? '—'
              : r.descCtrl.text.trim(),
          qty: Value(qty),
          unit: Value(r.unitCtrl.text.trim().isEmpty
              ? 'шт'
              : r.unitCtrl.text.trim()),
          unitPrice: price,
          vatRate: Value(r.vatRate),
        );
      }).toList();
      await db.replaceInvoiceItems(invoiceId, companions);
    }

    if (mounted) Navigator.pop(context);
  }
}

// ─── Item row data ─────────────────────────────────────────────────────────────

class _ItemRow {
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController priceCtrl;
  double vatRate;

  _ItemRow({
    TextEditingController? descCtrl,
    TextEditingController? qtyCtrl,
    TextEditingController? unitCtrl,
    TextEditingController? priceCtrl,
    this.vatRate = 0,
  })  : descCtrl = descCtrl ?? TextEditingController(),
        qtyCtrl = qtyCtrl ?? TextEditingController(text: '1'),
        unitCtrl = unitCtrl ?? TextEditingController(text: 'шт'),
        priceCtrl = priceCtrl ?? TextEditingController();

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _ItemRowWidget extends StatefulWidget {
  final _ItemRow row;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemRowWidget({
    super.key,
    required this.row,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_ItemRowWidget> createState() => _ItemRowWidgetState();
}

class _ItemRowWidgetState extends State<_ItemRowWidget> {
  Future<void> _editDescription(BuildContext context) async {
    final ctrl = TextEditingController(text: widget.row.descCtrl.text);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Наименование',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Введите наименование товара или услуги',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                widget.row.descCtrl.text = ctrl.text;
                widget.onChanged();
                Navigator.pop(ctx);
              },
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: InkWell(
            onTap: () => _editDescription(context),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.outline, width: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.row.descCtrl,
                builder: (_, val, __) => Text(
                  val.text.isEmpty ? 'Нажмите для ввода' : val.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: val.text.isEmpty
                        ? Theme.of(context).hintColor
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 48,
          child: TextField(
            controller: widget.row.qtyCtrl,
            decoration: const InputDecoration(isDense: true),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => widget.onChanged(),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 44,
          child: TextField(
            controller: widget.row.unitCtrl,
            decoration: const InputDecoration(isDense: true),
            onChanged: (_) => widget.onChanged(),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: TextField(
            controller: widget.row.priceCtrl,
            decoration: const InputDecoration(isDense: true),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => widget.onChanged(),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 64,
          child: DropdownButtonFormField<double>(
            initialValue: widget.row.vatRate,
            isDense: true,
            decoration: const InputDecoration(isDense: true),
            items: const [
              DropdownMenuItem(value: 0, child: Text('0%')),
              DropdownMenuItem(value: 12, child: Text('12%')),
            ],
            onChanged: (v) {
              setState(() => widget.row.vatRate = v ?? 0);
              widget.onChanged();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16, color: Colors.red),
          onPressed: widget.onRemove,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}

// ─── Print Params ─────────────────────────────────────────────────────────────

class _PrintParams {
  final String sellerName;
  final String sellerInn;
  final String sellerAddress;
  final String sellerBankDetails;
  final String signerSeller;
  final String signerBuyer;

  const _PrintParams({
    required this.sellerName,
    required this.sellerInn,
    required this.sellerAddress,
    required this.sellerBankDetails,
    required this.signerSeller,
    required this.signerBuyer,
  });
}

class _PrintParamsDialog extends StatefulWidget {
  final Company? company;
  const _PrintParamsDialog({this.company});

  @override
  State<_PrintParamsDialog> createState() => _PrintParamsDialogState();
}

class _PrintParamsDialogState extends State<_PrintParamsDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _innCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _signerSellerCtrl;
  late final TextEditingController _signerBuyerCtrl;

  @override
  void initState() {
    super.initState();
    final c = widget.company;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _innCtrl = TextEditingController(text: c?.inn ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _bankCtrl = TextEditingController(text: c?.bankDetails ?? '');
    _signerSellerCtrl = TextEditingController();
    _signerBuyerCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _innCtrl.dispose();
    _addressCtrl.dispose();
    _bankCtrl.dispose();
    _signerSellerCtrl.dispose();
    _signerBuyerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Параметры печати'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Секция 1 — Продавец',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название компании',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _innCtrl,
                decoration: const InputDecoration(
                  labelText: 'ИНН',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Адрес',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bankCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Банковские реквизиты',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Секция 7 — Подписи',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _signerSellerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Отпустил (ФИО / должность)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _signerBuyerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Получил (ФИО / должность)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Печать'),
          onPressed: () => Navigator.pop(
            context,
            _PrintParams(
              sellerName: _nameCtrl.text.trim(),
              sellerInn: _innCtrl.text.trim(),
              sellerAddress: _addressCtrl.text.trim(),
              sellerBankDetails: _bankCtrl.text.trim(),
              signerSeller: _signerSellerCtrl.text.trim(),
              signerBuyer: _signerBuyerCtrl.text.trim(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Payment Dialog ───────────────────────────────────────────────────────────

class _PaymentDialog extends ConsumerStatefulWidget {
  final Invoice invoice;
  final double remaining;
  const _PaymentDialog({required this.invoice, required this.remaining});

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  late final TextEditingController _amountCtrl;
  final _noteCtrl = TextEditingController();
  int? _accountId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.remaining.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: '', decimalDigits: 0);

    return AlertDialog(
      title: const Text('Внести оплату'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Remaining hint
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Остаток: ${fmt.format(widget.remaining)} ${widget.invoice.currency}',
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Сумма оплаты',
                suffixText: widget.invoice.currency,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            accountsAsync.when(
              data: (accounts) => DropdownButtonFormField<int>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Зачислить на счёт (необязательно)',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— Не зачислять —')),
                  ...accounts.map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      )),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                'Дата: ${DateFormat('dd.MM.yyyy').format(_date)}',
                style: const TextStyle(fontSize: 14),
              ),
              onTap: _pickDate,
            ),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Примечание (необязательно)',
              ),
            ),
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
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ru'),
    );
    if (d != null) setState(() => _date = d);
  }

  void _save() {
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    ref.read(databaseProvider).insertInvoicePayment(
          InvoicePaymentsCompanion.insert(
            invoiceId: widget.invoice.id,
            amount: amount,
            date: _date,
            accountId: Value(_accountId),
            note: Value(_noteCtrl.text.trim().isEmpty
                ? null
                : _noteCtrl.text.trim()),
          ),
        );
    Navigator.pop(context);
  }
}

// ─── Invoice → Transaction Dialog ─────────────────────────────────────────────

class _InvoiceToTransactionDialog extends ConsumerStatefulWidget {
  final Invoice invoice;
  final double remaining;
  const _InvoiceToTransactionDialog(
      {required this.invoice, required this.remaining});

  @override
  ConsumerState<_InvoiceToTransactionDialog> createState() =>
      _InvoiceToTransactionDialogState();
}

class _InvoiceToTransactionDialogState
    extends ConsumerState<_InvoiceToTransactionDialog> {
  late final TextEditingController _amountCtrl;
  int? _accountId;
  int? _categoryId;
  final DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.remaining.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      title: const Text('Создать транзакцию'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Клиент: ${widget.invoice.clientName}',
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Сумма',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              data: (accounts) => DropdownButtonFormField<int>(
                value: _accountId ?? (accounts.isNotEmpty ? accounts.first.id : null),
                decoration: const InputDecoration(
                    labelText: 'Счёт', border: OutlineInputBorder(), isDense: true),
                items: accounts
                    .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _accountId = v);
                  if (_accountId == null && accounts.isNotEmpty) {
                    _accountId = accounts.first.id;
                  }
                },
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (cats) {
                final income =
                    cats.where((c) => c.type == 'income').toList();
                return DropdownButtonFormField<int>(
                  value: _categoryId,
                  decoration: const InputDecoration(
                      labelText: 'Категория (необязательно)',
                      border: OutlineInputBorder(),
                      isDense: true),
                  items: income
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const SizedBox(),
            ),
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
          child: const Text('Создать'),
        ),
      ],
    );
  }

  void _save() {
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    final accounts =
        ref.read(accountsProvider).valueOrNull ?? [];
    final accId = _accountId ??
        (accounts.isNotEmpty ? accounts.first.id : null);
    if (accId == null) return;

    ref.read(databaseProvider).insertTransaction(
          TransactionsCompanion.insert(
            companyId: widget.invoice.companyId,
            accountId: accId,
            amount: amount,
            type: 'income',
            date: _date,
            categoryId: Value(_categoryId),
            description: Value(
                'Оплата по счёту: ${widget.invoice.clientName}'
                '${widget.invoice.invoiceNumber != null ? " №${widget.invoice.invoiceNumber}" : ""}'),
          ),
        );

    // Mark invoice as paid if amount covers remaining
    if (amount >= widget.remaining - 0.01) {
      final inv = widget.invoice;
      ref.read(databaseProvider).updateInvoice(
            InvoicesCompanion(
              id: Value(inv.id),
              companyId: Value(inv.companyId),
              invoiceNumber: Value(inv.invoiceNumber),
              clientName: Value(inv.clientName),
              clientDetails: Value(inv.clientDetails),
              description: Value(inv.description),
              totalAmount: Value(inv.totalAmount),
              currency: Value(inv.currency),
              dueDate: Value(inv.dueDate),
              status: const Value('paid'),
              salesPersonId: Value(inv.salesPersonId),
              commissionPct: Value(inv.commissionPct),
              createdAt: Value(inv.createdAt),
            ),
          );
    }

    Navigator.pop(context);
  }
}

// ─── Client LTV View ─────────────────────────────────────────────────────────

class _ClientLtvView extends StatelessWidget {
  final List<Invoice> invoices;
  const _ClientLtvView({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final clientMap = <String, ({double total, int count, DateTime last})>{};
    for (final inv in invoices) {
      if (inv.status == 'cancelled') continue;
      final prev = clientMap[inv.clientName];
      final later = prev == null || inv.createdAt.isAfter(prev.last);
      clientMap[inv.clientName] = (
        total: (prev?.total ?? 0) + inv.totalAmount,
        count: (prev?.count ?? 0) + 1,
        last: later ? inv.createdAt : prev.last,
      );
    }

    if (clientMap.isEmpty) {
      return const Center(child: Text('Нет данных по клиентам'));
    }

    final sorted = clientMap.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    final maxTotal = sorted.first.value.total;
    final fmt = NumberFormat('#,##0', 'ru_RU');

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final e = sorted[i];
        final pct = maxTotal > 0 ? e.value.total / maxTotal : 0.0;
        final colorScheme = Theme.of(ctx).colorScheme;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  Text(
                    fmt.format(e.value.total),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.shade200,
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Text('${e.value.count} сделок',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const Spacer(),
                  Text(
                      'последняя: ${DateFormat('dd.MM.yyyy').format(e.value.last)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ]),
                Builder(builder: (ctx) {
                  final daysSince =
                      DateTime.now().difference(e.value.last).inDays;
                  if (daysSince < 90) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      const Icon(Icons.person_off_outlined,
                          size: 13, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        'Нет активности $daysSince дней',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Status Filter Chip ───────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
              color: selected ? c : Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? c : Colors.grey[600],
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

