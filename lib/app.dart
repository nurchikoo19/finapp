import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'db/database.dart';
import 'providers/database_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/accounts/accounts_screen.dart';
import 'screens/transactions/transactions_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/tasks/tasks_screen.dart';
import 'screens/employees/employees_screen.dart';
import 'screens/categories/categories_screen.dart';
import 'screens/settings/company_settings_screen.dart';
import 'screens/invoices/invoices_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'screens/contracts/contracts_screen.dart';
import 'screens/payroll/payroll_screen.dart';

class TabysApp extends ConsumerStatefulWidget {
  const TabysApp({super.key});

  @override
  ConsumerState<TabysApp> createState() => _TabysAppState();
}

class _TabysAppState extends ConsumerState<TabysApp> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseProvider).processRecurringTransactions();
    });
  }

  static const _screens = [
    DashboardScreen(),
    AccountsScreen(),
    TransactionsScreen(),
    ReportsScreen(),
    InvoicesScreen(),
    TasksScreen(),
    EmployeesScreen(),
    CategoriesScreen(),
    InventoryScreen(),
    ContractsScreen(),
    PayrollScreen(),
  ];

  static const _navItems = [
    NavigationDestination(icon: Icon(Icons.dashboard), label: 'Главная'),
    NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Счета'),
    NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Транзакции'),
    NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Отчёты'),
    NavigationDestination(icon: Icon(Icons.handshake), label: 'Сделки'),
    NavigationDestination(icon: Icon(Icons.task_alt), label: 'Задачи'),
    NavigationDestination(icon: Icon(Icons.people), label: 'Сотрудники'),
    NavigationDestination(icon: Icon(Icons.category), label: 'Категории'),
    NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Склад'),
    NavigationDestination(icon: Icon(Icons.description), label: 'Договоры'),
    NavigationDestination(icon: Icon(Icons.payments), label: 'Зарплата'),
  ];

  static const _titles = [
    'Главная',
    'Счета',
    'Транзакции',
    'Отчёты',
    'Сделки и дебиторка',
    'Задачи',
    'Сотрудники',
    'Категории',
    'Склад',
    'Договоры',
    'Зарплата',
  ];

  @override
  Widget build(BuildContext context) {
    final selectedCompany = ref.watch(selectedCompanyProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Меню',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        // Flexible prevents the dropdown from overflowing the AppBar Row
        title: Text(
          _titles[_selectedIndex],
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (selectedCompany != null)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Настройки компании',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CompanySettingsScreen(
                    company: selectedCompany,
                  ),
                ),
              ),
            ),
          Consumer(
            builder: (ctx, r, _) {
              final isDark = r.watch(themeModeProvider) == ThemeMode.dark;
              return IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
                onPressed: () => r.read(themeModeProvider.notifier).toggle(),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: _AppDrawer(
          selectedIndex: _selectedIndex,
          onSelected: (i) {
            setState(() => _selectedIndex = i);
            Navigator.pop(context);
          },
          navItems: _navItems,
          onAddCompany: () {
            Navigator.pop(context);
            _showCompanyDialog(context);
          },
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }

  void _showCompanyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _CompanyDialog(),
    );
  }
}

// ─── App Drawer ───────────────────────────────────────────────────────────────

class _AppDrawer extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> navItems;
  final VoidCallback onAddCompany;

  const _AppDrawer({
    required this.selectedIndex,
    required this.onSelected,
    required this.navItems,
    required this.onAddCompany,
  });

  @override
  ConsumerState<_AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<_AppDrawer> {
  bool _companiesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(companiesProvider);
    final selectedCompany = ref.watch(selectedCompanyProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Company switcher header ──────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: InkWell(
            onTap: () => setState(() => _companiesExpanded = !_companiesExpanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    radius: 20,
                    child: Text(
                      selectedCompany?.name.isNotEmpty == true
                          ? selectedCompany!.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedCompany?.name ?? 'Нет компании',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Нажмите для смены',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _companiesExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Company list (expanded) ──────────────────────────────────────────
        if (_companiesExpanded)
          Container(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: companiesAsync.when(
              data: (companies) => Column(
                children: [
                  ...companies.map((c) {
                    final isSelected = c.id == selectedCompany?.id;
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: isSelected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(
                        c.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: colorScheme.primary, size: 18)
                          : null,
                      onTap: () {
                        ref.read(selectedCompanyIdProvider.notifier).state =
                            c.id;
                        setState(() => _companiesExpanded = false);
                        Navigator.pop(context);
                      },
                    );
                  }),
                  ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    leading: Icon(Icons.add_business,
                        size: 20, color: colorScheme.primary),
                    title: Text(
                      'Добавить компанию',
                      style: TextStyle(
                          fontSize: 13, color: colorScheme.primary),
                    ),
                    onTap: () {
                      setState(() => _companiesExpanded = false);
                      widget.onAddCompany();
                    },
                  ),
                  const Divider(height: 1),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
              error: (_, __) => const SizedBox(),
            ),
          ),

        const Divider(height: 1),

        // ── Navigation items ─────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            itemCount: widget.navItems.length,
            itemBuilder: (ctx, i) {
              final item = widget.navItems[i];
              final selected = widget.selectedIndex == i;
              return ListTile(
                selected: selected,
                selectedTileColor: colorScheme.secondaryContainer,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                leading: IconTheme(
                  data: IconThemeData(
                    color: selected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                  child: item.icon,
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => widget.onSelected(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CompanyDialog extends ConsumerStatefulWidget {
  const _CompanyDialog();

  @override
  ConsumerState<_CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends ConsumerState<_CompanyDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _currency = 'KGS';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая компания'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Название компании'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Описание (необязательно)'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Валюта'),
            items: const [
              DropdownMenuItem(value: 'KGS', child: Text('с Кыргызский сом')),
              DropdownMenuItem(value: 'RUB', child: Text('₽ Рубль')),
              DropdownMenuItem(value: 'USD', child: Text('\$ Доллар')),
              DropdownMenuItem(value: 'EUR', child: Text('€ Евро')),
              DropdownMenuItem(value: 'KZT', child: Text('₸ Казахстанский тенге')),
              DropdownMenuItem(value: 'UZS', child: Text('сўм Узбекский сум')),
            ],
            onChanged: (v) => setState(() => _currency = v!),
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
          child: const Text('Создать'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final db = ref.read(databaseProvider);
    final newId = await db.insertCompany(CompaniesCompanion.insert(
      name: _nameCtrl.text.trim(),
      description: Value(_descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim()),
      currency: Value(_currency),
    ));
    ref.read(selectedCompanyIdProvider.notifier).state = newId;
    if (mounted) Navigator.pop(context);
  }
}
