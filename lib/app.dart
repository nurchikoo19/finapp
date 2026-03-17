import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:google_fonts/google_fonts.dart';
import 'db/database.dart';
import 'providers/database_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/tabys_theme.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/accounts/accounts_screen.dart';
import 'screens/transactions/transactions_screen.dart' show TransactionsScreen, TransactionDialog;
import 'screens/reports/reports_screen.dart';
import 'screens/tasks/tasks_screen.dart';
import 'screens/employees/employees_screen.dart';
import 'screens/categories/categories_screen.dart';
import 'screens/settings/company_settings_screen.dart';
import 'screens/invoices/invoices_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'screens/contracts/contracts_screen.dart';
import 'screens/payroll/payroll_screen.dart';

// ─── Screen registry ──────────────────────────────────────────────────────────

const _screens = [
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

// ─── Nav item model ───────────────────────────────────────────────────────────

class _NavItem {
  final int index;
  final IconData icon;
  final String label;
  final String? section;
  const _NavItem(this.index, this.icon, this.label, {this.section});
}

const _navItems = [
  _NavItem(0,  Icons.dashboard_outlined,       'Главная',   section: 'Обзор'),
  _NavItem(1,  Icons.account_balance_wallet_outlined, 'Счета'),
  _NavItem(2,  Icons.receipt_long_outlined,    'Транзакции'),
  _NavItem(3,  Icons.bar_chart_outlined,       'Отчёты'),
  _NavItem(4,  Icons.handshake_outlined,       'Сделки',    section: 'Бизнес'),
  _NavItem(5,  Icons.task_alt_outlined,        'Задачи'),
  _NavItem(10, Icons.payments_outlined,        'Зарплата'),
  _NavItem(9,  Icons.description_outlined,     'Договоры'),
  _NavItem(8,  Icons.inventory_2_outlined,     'Склад',     section: 'Операции'),
  _NavItem(6,  Icons.people_outline,           'Сотрудники'),
  _NavItem(7,  Icons.category_outlined,        'Категории'),
];

const _titles = [
  'Дашборд',
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

// ─── Root widget ──────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final selectedCompany = ref.watch(selectedCompanyProvider);

    return Scaffold(
      backgroundColor: TColors.ink,
      body: Row(
        children: [
          _TabysSidebar(
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
            onAddCompany: () => _showCompanyDialog(context),
          ),
          Expanded(
            child: Column(
              children: [
                _TabysTopbar(
                  title: _titles[_selectedIndex],
                  company: selectedCompany,
                  onSettings: selectedCompany == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompanySettingsScreen(
                                company: selectedCompany,
                              ),
                            ),
                          ),
                  onAddTransaction: selectedCompany == null
                      ? null
                      : () => showDialog(
                            context: context,
                            builder: (_) => TransactionDialog(
                              companyId: selectedCompany.id,
                            ),
                          ),
                ),
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCompanyDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _CompanyDialog());
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

class _TabysSidebar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAddCompany;

  const _TabysSidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.onAddCompany,
  });

  @override
  ConsumerState<_TabysSidebar> createState() => _TabysSidebarState();
}

class _TabysSidebarState extends ConsumerState<_TabysSidebar> {
  bool _companiesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(companiesProvider);
    final selected = ref.watch(selectedCompanyProvider);

    return SizedBox(
      width: 220,
      child: Container(
        decoration: const BoxDecoration(
          color: TColors.surface,
          border: Border(right: BorderSide(color: TColors.border)),
        ),
        child: Column(
          children: [
            // ── Logo ────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: TColors.border)),
              ),
              child: Row(
                children: [
                  ClipPath(
                    clipper: _TriangleClipper(),
                    child: Container(
                      width: 26, height: 26,
                      color: TColors.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.syne(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: TColors.text),
                      children: const [
                        TextSpan(text: 'T'),
                        TextSpan(
                            text: 'A',
                            style: TextStyle(color: TColors.gold)),
                        TextSpan(text: 'BYS'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Company box ─────────────────────────────────────────────────
            GestureDetector(
              onTap: () =>
                  setState(() => _companiesExpanded = !_companiesExpanded),
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: TColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _companiesExpanded ? TColors.border2 : TColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('КОМПАНИЯ',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            color: TColors.muted,
                            letterSpacing: .6,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selected?.name ?? 'Нет компании',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: TColors.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _companiesExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: TColors.muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Company list ────────────────────────────────────────────────
            if (_companiesExpanded)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: TColors.card2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TColors.border),
                ),
                child: Column(
                  children: [
                    ...companiesAsync.valueOrNull?.map((c) {
                          final isSel = c.id == selected?.id;
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              ref
                                  .read(selectedCompanyIdProvider.notifier)
                                  .state = c.id;
                              setState(() => _companiesExpanded = false);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? TColors.gold
                                          : TColors.border2,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      c.name.isNotEmpty
                                          ? c.name[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.syne(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isSel
                                              ? TColors.ink
                                              : TColors.text),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(c.name,
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: isSel
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSel
                                                ? TColors.gold
                                                : TColors.text),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  if (isSel)
                                    const Icon(Icons.check,
                                        size: 14, color: TColors.gold),
                                ],
                              ),
                            ),
                          );
                        }).toList() ??
                        [],
                    const Divider(height: 1),
                    InkWell(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(10)),
                      onTap: () {
                        setState(() => _companiesExpanded = false);
                        widget.onAddCompany();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            const Icon(Icons.add_business_outlined,
                                size: 16, color: TColors.gold),
                            const SizedBox(width: 8),
                            Text('Добавить компанию',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: TColors.gold,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 4),

            // ── Navigation ──────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: _navItems.length,
                itemBuilder: (ctx, i) {
                  final item = _navItems[i];
                  final isActive = widget.selectedIndex == item.index;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.section != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                          child: Text(
                            item.section!.toUpperCase(),
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: TColors.muted2,
                                letterSpacing: .8,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 1),
                        decoration: isActive
                            ? BoxDecoration(
                                color: TColors.goldBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0x26D4A843)),
                              )
                            : null,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => widget.onSelect(item.index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                if (isActive)
                                  Container(
                                    width: 3,
                                    height: 18,
                                    margin: const EdgeInsets.only(right: 9),
                                    decoration: BoxDecoration(
                                      color: TColors.gold,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  )
                                else
                                  const SizedBox(width: 12),
                                Icon(item.icon,
                                    size: 16,
                                    color: isActive
                                        ? TColors.gold
                                        : TColors.muted),
                                const SizedBox(width: 10),
                                Text(
                                  item.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isActive
                                        ? TColors.gold
                                        : TColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Profile row ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: TColors.border)),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [TColors.gold, Color(0xFF8B5E1F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        selected?.name.isNotEmpty == true
                            ? selected!.name[0].toUpperCase()
                            : 'T',
                        style: GoogleFonts.syne(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: TColors.ink),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected?.name ?? 'Tabys',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: TColors.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('Администратор',
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: TColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Topbar ───────────────────────────────────────────────────────────────────

class _TabysTopbar extends ConsumerWidget {
  final String title;
  final Company? company;
  final VoidCallback? onSettings;
  final VoidCallback? onAddTransaction;

  const _TabysTopbar({
    required this.title,
    required this.company,
    this.onSettings,
    this.onAddTransaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final now = DateTime.now();
    final months = [
      '', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: TColors.surface,
        border: Border(bottom: BorderSide(color: TColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Title
          Text(title,
              style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: TColors.text)),
          const SizedBox(width: 14),

          // Period pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: TColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: TColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: TColors.muted),
                const SizedBox(width: 6),
                Text(
                  '${months[now.month]} ${now.year}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: TColors.text),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Theme toggle
          _IconBtn(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const SizedBox(width: 6),

          // Settings
          if (onSettings != null) ...[
            _IconBtn(
              icon: Icons.settings_outlined,
              tooltip: 'Настройки компании',
              onTap: onSettings!,
            ),
            const SizedBox(width: 6),
          ],

          // Add transaction button
          FilledButton.icon(
            onPressed: onAddTransaction,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Транзакция'),
            style: FilledButton.styleFrom(
              backgroundColor: TColors.gold,
              foregroundColor: TColors.ink,
              textStyle: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: TColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: TColors.border),
          ),
          child: Icon(icon, size: 17, color: TColors.muted),
        ),
      ),
    );
  }
}

// ─── Triangle logo clipper ────────────────────────────────────────────────────

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width / 2, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_TriangleClipper old) => false;
}

// ─── Company dialog ───────────────────────────────────────────────────────────

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
            decoration:
                const InputDecoration(labelText: 'Название компании'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
                labelText: 'Описание (необязательно)'),
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
