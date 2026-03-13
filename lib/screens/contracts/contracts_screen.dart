import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../providers/database_provider.dart';

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

Color _statusColor(String status) {
  switch (status) {
    case 'active':
      return Colors.green;
    case 'completed':
      return Colors.blue;
    case 'cancelled':
      return Colors.grey;
    case 'expired':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Активный';
    case 'completed':
      return 'Завершён';
    case 'cancelled':
      return 'Отменён';
    case 'expired':
      return 'Истёк';
    default:
      return status;
  }
}

class ContractsScreen extends ConsumerStatefulWidget {
  const ContractsScreen({super.key});

  @override
  ConsumerState<ContractsScreen> createState() => _ContractsScreenState();
}

enum _ContractSort { counterparty, amount, date }

class _ContractsScreenState extends ConsumerState<ContractsScreen> {
  // null = all, otherwise 'client'/'supplier'/'active'/'expiring'
  String? _filter;
  _ContractSort _sort = _ContractSort.date;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(selectedCompanyProvider);
    if (company == null) {
      return const Scaffold(body: Center(child: Text('Нет компании')));
    }

    final contractsAsync = ref.watch(contractsProvider);
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: _sym(company.currency), decimalDigits: 0);

    return Scaffold(
      body: contractsAsync.when(
        data: (all) {
          final now = DateTime.now();
          final soon = now.add(const Duration(days: 30));

          List<Contract> filtered;
          switch (_filter) {
            case 'client':
              filtered = all.where((c) => c.type == 'client').toList();
              break;
            case 'supplier':
              filtered = all.where((c) => c.type == 'supplier').toList();
              break;
            case 'active':
              filtered = all.where((c) => c.status == 'active').toList();
              break;
            case 'expiring':
              filtered = all
                  .where((c) =>
                      c.status == 'active' &&
                      c.endDate != null &&
                      c.endDate!.isAfter(now) &&
                      c.endDate!.isBefore(soon))
                  .toList();
              break;
            case 'signed':
              filtered =
                  all.where((c) => c.signedDate != null).toList();
              break;
            case 'unsigned':
              filtered =
                  all.where((c) => c.signedDate == null).toList();
              break;
            default:
              filtered = all;
          }

          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            filtered = filtered
                .where((c) =>
                    c.counterparty.toLowerCase().contains(q) ||
                    (c.number?.toLowerCase().contains(q) ?? false) ||
                    (c.notes?.toLowerCase().contains(q) ?? false))
                .toList();
          }

          switch (_sort) {
            case _ContractSort.counterparty:
              filtered.sort(
                  (a, b) => a.counterparty.compareTo(b.counterparty));
              break;
            case _ContractSort.amount:
              filtered.sort(
                  (a, b) => b.totalAmount.compareTo(a.totalAmount));
              break;
            case _ContractSort.date:
              filtered.sort(
                  (a, b) => b.startDate.compareTo(a.startDate));
              break;
          }

          final activeTotal = all
              .where((c) => c.status == 'active')
              .fold(0.0, (s, c) => s + c.totalAmount);

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Поиск по контрагенту, номеру...',
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
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              // Summary bar
              if (all.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.description),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${all.where((c) => c.status == "active").length} активных договоров',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('На сумму: ${fmt.format(activeTotal)}',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ]),
                ),

              // Filter + sort row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  const Text('Сортировка:',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  DropdownButton<_ContractSort>(
                    value: _sort,
                    underline: const SizedBox(),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                          value: _ContractSort.date,
                          child: Text('По дате', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: _ContractSort.counterparty,
                          child: Text('По контрагенту',
                              style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: _ContractSort.amount,
                          child: Text('По сумме', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) => setState(() => _sort = v!),
                  ),
                ]),
              ),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _FilterChip(
                        label: 'Все',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null)),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Клиент',
                        selected: _filter == 'client',
                        onTap: () => setState(() => _filter = 'client')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Поставщик',
                        selected: _filter == 'supplier',
                        onTap: () => setState(() => _filter = 'supplier')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Активные',
                        selected: _filter == 'active',
                        onTap: () => setState(() => _filter = 'active')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Истекающие',
                        selected: _filter == 'expiring',
                        onTap: () => setState(() => _filter = 'expiring')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Подписан',
                        selected: _filter == 'signed',
                        onTap: () => setState(() => _filter = 'signed')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Не подписан',
                        selected: _filter == 'unsigned',
                        onTap: () => setState(() => _filter = 'unsigned')),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Договоры не найдены'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _ContractCard(
                          contract: filtered[i],
                          currency: company.currency,
                          companyId: company.id,
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Добавить договор'),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => _ContractDialog(companyId: company.id),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}

class _ContractCard extends ConsumerWidget {
  final Contract contract;
  final String currency;
  final int companyId;

  const _ContractCard({
    required this.contract,
    required this.currency,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: _sym(currency), decimalDigits: 0);
    final now = DateTime.now();
    final isExpiringSoon = contract.status == 'active' &&
        contract.endDate != null &&
        contract.endDate!.isAfter(now) &&
        contract.endDate!.isBefore(now.add(const Duration(days: 30)));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(contract.counterparty,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                _StatusBadge(status: contract.status),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(
                  contract.type == 'client'
                      ? Icons.person_outline
                      : Icons.business_outlined,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  contract.type == 'client' ? 'Клиент' : 'Поставщик',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (contract.number != null) ...[
                  const SizedBox(width: 12),
                  Text('№ ${contract.number}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text(fmt.format(contract.totalAmount),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                        'с ${DateFormat('dd.MM.yyyy').format(contract.startDate)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    if (contract.endDate != null)
                      Text(
                          'по ${DateFormat('dd.MM.yyyy').format(contract.endDate!)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isExpiringSoon
                                  ? Colors.orange
                                  : Colors.grey[600],
                              fontWeight: isExpiringSoon
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                  ],
                ),
              ]),
              if (contract.signedDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Icon(Icons.verified_outlined,
                        size: 13, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                        'Подписан: ${DateFormat('dd.MM.yyyy').format(contract.signedDate!)}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.green)),
                  ]),
                ),
              if (isExpiringSoon)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text('Истекает в ближайшие 30 дней',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.orange)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _ContractDialog(
          companyId: companyId, contract: contract),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
            fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ContractDialog extends ConsumerStatefulWidget {
  final int companyId;
  final Contract? contract;

  const _ContractDialog({required this.companyId, this.contract});

  @override
  ConsumerState<_ContractDialog> createState() => _ContractDialogState();
}

class _ContractDialogState extends ConsumerState<_ContractDialog> {
  late final TextEditingController _counterpartyCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;
  late String _type;
  late String _status;
  late DateTime _startDate;
  DateTime? _endDate;
  DateTime? _signedDate;

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    _counterpartyCtrl = TextEditingController(text: c?.counterparty ?? '');
    _numberCtrl = TextEditingController(text: c?.number ?? '');
    _amountCtrl = TextEditingController(
        text: c != null ? c.totalAmount.toStringAsFixed(0) : '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
    _type = c?.type ?? 'client';
    _status = c?.status ?? 'active';
    _startDate = c?.startDate ?? DateTime.now();
    _endDate = c?.endDate;
    _signedDate = c?.signedDate;
  }

  @override
  void dispose() {
    _counterpartyCtrl.dispose();
    _numberCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.contract != null;
    return AlertDialog(
      title: Text(isEdit ? 'Редактировать договор' : 'Новый договор'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _counterpartyCtrl,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Контрагент *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _numberCtrl,
              decoration:
                  const InputDecoration(labelText: 'Номер договора (необязательно)'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Тип'),
              items: const [
                DropdownMenuItem(value: 'client', child: Text('Клиент')),
                DropdownMenuItem(value: 'supplier', child: Text('Поставщик')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Сумма договора *'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat('dd.MM.yy').format(_startDate)),
                  onPressed: () => _pickDate(context, field: 'start'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(_endDate != null
                      ? DateFormat('dd.MM.yy').format(_endDate!)
                      : 'Дата окончания'),
                  onPressed: () => _pickDate(context, field: 'end'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: Icon(
                _signedDate != null
                    ? Icons.verified_outlined
                    : Icons.draw_outlined,
                size: 16,
                color: _signedDate != null ? Colors.green : null,
              ),
              label: Text(
                _signedDate != null
                    ? 'Подписан: ${DateFormat('dd.MM.yyyy').format(_signedDate!)}'
                    : 'Дата подписания (необязательно)',
                style: TextStyle(
                    color: _signedDate != null ? Colors.green : null),
              ),
              onPressed: () => _pickDate(context, field: 'signed'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Статус'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Активный')),
                DropdownMenuItem(
                    value: 'completed', child: Text('Завершён')),
                DropdownMenuItem(
                    value: 'cancelled', child: Text('Отменён')),
                DropdownMenuItem(value: 'expired', child: Text('Истёк')),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Примечания (необязательно)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        if (isEdit)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Удалить договор?'),
                content: const Text(
                    'Договор и все связанные данные будут удалены.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена')),
                  FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref
                          .read(databaseProvider)
                          .deleteContract(widget.contract!.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Удалить'),
                  ),
                ],
              ),
            ),
            child: const Text('Удалить'),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context,
      {required String field}) async {
    final initial = field == 'start'
        ? _startDate
        : field == 'end'
            ? (_endDate ?? DateTime.now())
            : (_signedDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() {
        if (field == 'start') {
          _startDate = picked;
        } else if (field == 'end') {
          _endDate = picked;
        } else {
          _signedDate = picked;
        }
      });
    }
  }

  void _save() async {
    if (_counterpartyCtrl.text.trim().isEmpty) return;
    final amount = double.tryParse(
            _amountCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ??
        0.0;
    final db = ref.read(databaseProvider);
    final number = _numberCtrl.text.trim().isEmpty
        ? null
        : _numberCtrl.text.trim();
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    if (widget.contract == null) {
      await db.insertContract(ContractsCompanion.insert(
        companyId: widget.companyId,
        counterparty: _counterpartyCtrl.text.trim(),
        type: Value(_type),
        number: Value(number),
        startDate: _startDate,
        endDate: Value(_endDate),
        totalAmount: amount,
        status: Value(_status),
        notes: Value(notes),
        signedDate: Value(_signedDate),
      ));
    } else {
      await db.updateContract(ContractsCompanion(
        id: Value(widget.contract!.id),
        companyId: Value(widget.companyId),
        counterparty: Value(_counterpartyCtrl.text.trim()),
        type: Value(_type),
        number: Value(number),
        startDate: Value(_startDate),
        endDate: Value(_endDate),
        totalAmount: Value(amount),
        status: Value(_status),
        notes: Value(notes),
        signedDate: Value(_signedDate),
      ));
    }
    if (mounted) Navigator.pop(context);
  }
}
