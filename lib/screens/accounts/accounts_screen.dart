import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../../providers/database_provider.dart';
import '../../db/database.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final company = ref.watch(selectedCompanyProvider);

    return Scaffold(
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(child: Text('Нет счетов. Добавьте первый счёт.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            itemBuilder: (ctx, i) => _AccountCard(account: accounts[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
      floatingActionButton: company != null
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Добавить счёт'),
              onPressed: () => _showAccountDialog(context, ref, company.id),
            )
          : null,
    );
  }

  void _showAccountDialog(BuildContext context, WidgetRef ref, int companyId,
      [Account? existing]) {
    showDialog(
      context: context,
      builder: (_) => _AccountDialog(companyId: companyId, existing: existing),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final Account account;

  const _AccountCard({required this.account});

  static const _typeIcons = {
    'cash': Icons.money,
    'bank': Icons.account_balance,
    'card': Icons.credit_card,
  };

  static const _typeLabels = {
    'cash': 'Наличные',
    'bank': 'Банк',
    'card': 'Карта',
  };

  static String _sym(String code) {
    const m = {
      'KGS': 'с', 'RUB': '₽', 'USD': '\$', 'EUR': '€', 'KZT': '₸', 'UZS': 'сўм',
    };
    return m[code] ?? code;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: _sym(account.currency), decimalDigits: 2);
    final isNegative = account.balance < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isNegative ? Colors.red.shade100 : Colors.blue.shade100,
          child: Icon(
            _typeIcons[account.type] ?? Icons.account_balance_wallet,
            color: isNegative ? Colors.red : Colors.blue,
          ),
        ),
        title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${_typeLabels[account.type] ?? account.type}'
          '${account.bankName != null ? " · ${account.bankName}" : ""}',
        ),
        trailing: Text(
          fmt.format(account.balance),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isNegative ? Colors.red : Colors.black87,
          ),
        ),
        onLongPress: () => _showOptions(context, ref),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Редактировать'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => _AccountDialog(
                  companyId: company.id,
                  existing: account,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Удалить', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Удалить счёт?'),
                  content: Text(
                      'Счёт "${account.name}" и все связанные данные будут удалены.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена')),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(databaseProvider).deleteAccount(account.id);
                      },
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AccountDialog extends ConsumerStatefulWidget {
  final int companyId;
  final Account? existing;

  const _AccountDialog({required this.companyId, this.existing});

  @override
  ConsumerState<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<_AccountDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _balanceCtrl;
  String _type = 'bank';
  String _currency = 'KGS';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _bankCtrl = TextEditingController(text: widget.existing?.bankName ?? '');
    _balanceCtrl = TextEditingController(
      text: widget.existing?.balance.toStringAsFixed(2) ?? '0',
    );
    _type = widget.existing?.type ?? 'bank';
    _currency = widget.existing?.currency ?? 'KGS';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Новый счёт' : 'Редактировать счёт'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Тип'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Наличные')),
              DropdownMenuItem(value: 'bank', child: Text('Банк')),
              DropdownMenuItem(value: 'card', child: Text('Карта')),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bankCtrl,
            decoration: const InputDecoration(labelText: 'Название банка (необязательно)'),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Валюта'),
            items: const [
              DropdownMenuItem(value: 'KGS', child: Text('с Кыргызский сом')),
              DropdownMenuItem(value: 'RUB', child: Text('₽ Рубль')),
              DropdownMenuItem(value: 'USD', child: Text('\$ Доллар')),
              DropdownMenuItem(value: 'EUR', child: Text('€ Евро')),
              DropdownMenuItem(value: 'KZT', child: Text('₸ Тенге')),
            ],
            onChanged: (v) => setState(() => _currency = v!),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _balanceCtrl,
            decoration: const InputDecoration(labelText: 'Начальный баланс'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
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

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final db = ref.read(databaseProvider);
    final balance = double.tryParse(_balanceCtrl.text.replaceAll(',', '.')) ?? 0;

    if (widget.existing == null) {
      db.insertAccount(AccountsCompanion.insert(
        companyId: widget.companyId,
        name: _nameCtrl.text.trim(),
        type: Value(_type),
        bankName: Value(_bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim()),
        balance: Value(balance),
        currency: Value(_currency),
      ));
    } else {
      db.updateAccount(AccountsCompanion(
        id: Value(widget.existing!.id),
        companyId: Value(widget.companyId),
        name: Value(_nameCtrl.text.trim()),
        type: Value(_type),
        bankName: Value(_bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim()),
        balance: Value(balance),
        currency: Value(_currency),
      ));
    }
    Navigator.pop(context);
  }
}
