import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../db/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/tabys_theme.dart';
import '../../utils/currency_utils.dart';

enum _InvSort { name, quantity, value }

// ─── Receipt item data (local state model) ───────────────────────────────────

class _ReceiptItemData {
  final int? productId; // null = new product
  final String productName;
  final String unit;
  final double qty;
  final double unitPrice;
  final double salePrice;

  const _ReceiptItemData({
    this.productId,
    required this.productName,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    this.salePrice = 0.0,
  });

  double get subtotal => qty * unitPrice;

  _ReceiptItemData copyWith({
    int? productId,
    String? productName,
    String? unit,
    double? qty,
    double? unitPrice,
    double? salePrice,
  }) =>
      _ReceiptItemData(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        unit: unit ?? this.unit,
        qty: qty ?? this.qty,
        unitPrice: unitPrice ?? this.unitPrice,
        salePrice: salePrice ?? this.salePrice,
      );
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(selectedCompanyProvider);
    if (company == null) {
      return const Scaffold(
        body: Center(
          child: Text('Нет компании', style: TextStyle(color: TColors.muted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: TColors.ink,
      body: Column(
        children: [
          // Tab bar
          Container(
            color: TColors.surface,
            child: TabBar(
              controller: _tab,
              tabs: const [
                Tab(text: 'Товары'),
                Tab(text: 'Оприходование'),
              ],
              indicatorColor: TColors.gold,
              labelColor: TColors.gold,
              unselectedLabelColor: TColors.muted,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              indicatorSize: TabBarIndicatorSize.label,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ProductsTab(company: company),
                _ReceiptsTab(company: company),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Добавить товар'),
              backgroundColor: TColors.gold,
              foregroundColor: TColors.ink,
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _ProductDialog(companyId: company.id),
              ),
            )
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Новая накладная'),
              backgroundColor: TColors.gold,
              foregroundColor: TColors.ink,
              onPressed: () => _createReceipt(company.id),
            ),
    );
  }

  Future<void> _createReceipt(int companyId) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final num =
        'ПРХ-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final receiptId = await db.insertReceipt(StockReceiptsCompanion.insert(
      companyId: companyId,
      number: num,
      date: now,
    ));
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReceiptEditScreen(receiptId: receiptId, companyId: companyId),
      ),
    );
  }
}

// ─── Products Tab ─────────────────────────────────────────────────────────────

class _ProductsTab extends ConsumerStatefulWidget {
  final Company company;
  const _ProductsTab({required this.company});

  @override
  ConsumerState<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<_ProductsTab> {
  _InvSort _sort = _InvSort.name;

  @override
  Widget build(BuildContext context) {
    final company = widget.company;
    final productsAsync = ref.watch(productsProvider);
    final fmt = NumberFormat.currency(
        locale: 'ru_RU',
        symbol: currencySymbol(company.currency),
        decimalDigits: 0);

    return productsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: TColors.gold)),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: TColors.red))),
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 64, color: TColors.muted2),
              const SizedBox(height: 12),
              const Text('Нет товаров. Нажмите + чтобы добавить.',
                  style: TextStyle(color: TColors.muted)),
            ]),
          );
        }

        final totalValue =
            products.fold(0.0, (s, p) => s + p.quantity * p.salePrice);

        final sorted = [...products];
        switch (_sort) {
          case _InvSort.name:
            sorted.sort((a, b) => a.name.compareTo(b.name));
          case _InvSort.quantity:
            sorted.sort((a, b) => b.quantity.compareTo(a.quantity));
          case _InvSort.value:
            sorted.sort((a, b) =>
                (b.quantity * b.salePrice).compareTo(a.quantity * a.salePrice));
        }

        return Column(
          children: [
            // Summary header
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: TColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: TColors.blueBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: TColors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${products.length} позиций',
                            style: const TextStyle(
                                color: TColors.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(
                            'Стоимость склада: ${fmt.format(totalValue)}',
                            style: const TextStyle(
                                color: TColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  DropdownButton<_InvSort>(
                    value: _sort,
                    dropdownColor: TColors.card2,
                    underline: const SizedBox(),
                    isDense: true,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: TColors.muted),
                    items: const [
                      DropdownMenuItem(
                          value: _InvSort.name,
                          child: Text('По имени')),
                      DropdownMenuItem(
                          value: _InvSort.quantity,
                          child: Text('По кол-ву')),
                      DropdownMenuItem(
                          value: _InvSort.value,
                          child: Text('По стоимости')),
                    ],
                    onChanged: (v) => setState(() => _sort = v!),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: sorted.length,
                itemBuilder: (ctx, i) => _ProductCard(
                  product: sorted[i],
                  currency: company.currency,
                  companyId: company.id,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Receipts Tab ─────────────────────────────────────────────────────────────

class _ReceiptsTab extends ConsumerWidget {
  final Company company;
  const _ReceiptsTab({required this.company});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(receiptsProvider(company.id));
    final fmt = NumberFormat('#,##0', 'ru_RU');

    return receiptsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: TColors.gold)),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: TColors.red))),
      data: (receipts) {
        if (receipts.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: TColors.muted2),
              SizedBox(height: 12),
              Text('Нет накладных. Нажмите + для создания.',
                  style: TextStyle(color: TColors.muted)),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: receipts.length,
          itemBuilder: (ctx, i) => _ReceiptTile(
            receipt: receipts[i],
            company: company,
            fmt: fmt,
          ),
        );
      },
    );
  }
}

// ─── Receipt Tile ─────────────────────────────────────────────────────────────

class _ReceiptTile extends ConsumerWidget {
  final StockReceipt receipt;
  final Company company;
  final NumberFormat fmt;

  const _ReceiptTile({
    required this.receipt,
    required this.company,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPosted = receipt.status == 'posted';
    final sym = currencySymbol(company.currency);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: TColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isPosted
                ? TColors.green.withValues(alpha: 0.25)
                : TColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptEditScreen(
              receiptId: receipt.id,
              companyId: company.id,
            ),
          ),
        ),
        onLongPress: isPosted ? null : () => _confirmDelete(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPosted ? TColors.greenBg : TColors.goldBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPosted
                      ? Icons.check_circle_outline
                      : Icons.edit_document,
                  color: isPosted ? TColors.green : TColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(receipt.number,
                        style: const TextStyle(
                            color: TColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        DateFormat('dd.MM.yyyy').format(receipt.date),
                        if (receipt.supplierName != null) receipt.supplierName!,
                      ].join(' · '),
                      style: const TextStyle(
                          color: TColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Status + amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPosted ? TColors.greenBg : TColors.goldBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPosted ? 'Проведено' : 'Черновик',
                      style: TextStyle(
                          color: isPosted ? TColors.green : TColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$sym ${fmt.format(receipt.totalAmount)}',
                    style: TabysTheme.mono(size: 13, color: TColors.text),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить накладную?'),
        content: Text(
            'Накладная "${receipt.number}" будет удалена. Это действие нельзя отменить.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TColors.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(databaseProvider).deleteReceipt(receipt.id);
            },
            child: const Text('Удалить',
                style: TextStyle(color: TColors.text)),
          ),
        ],
      ),
    );
  }
}

// ─── Receipt Edit Screen ──────────────────────────────────────────────────────

class ReceiptEditScreen extends ConsumerStatefulWidget {
  final int receiptId;
  final int companyId;

  const ReceiptEditScreen({
    super.key,
    required this.receiptId,
    required this.companyId,
  });

  @override
  ConsumerState<ReceiptEditScreen> createState() => _ReceiptEditScreenState();
}

class _ReceiptEditScreenState extends ConsumerState<ReceiptEditScreen> {
  final _numberCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  List<_ReceiptItemData> _items = [];
  bool _isPosted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _supplierCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final receipt = await db.getReceiptById(widget.receiptId);
    if (receipt == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final items = await db.getItemsByReceipt(widget.receiptId);
    if (!mounted) return;
    setState(() {
      _numberCtrl.text = receipt.number;
      _supplierCtrl.text = receipt.supplierName ?? '';
      _noteCtrl.text = receipt.note ?? '';
      _date = receipt.date;
      _isPosted = receipt.status == 'posted';
      _items = items
          .map((item) => _ReceiptItemData(
                productId: item.productId,
                productName: item.productName,
                unit: item.unit,
                qty: item.qty,
                unitPrice: item.unitPrice,
                salePrice: item.salePrice,
              ))
          .toList();
      _loading = false;
    });
  }

  double get _total => _items.fold(0.0, (s, i) => s + i.subtotal);

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(selectedCompanyProvider);
    final sym = company != null ? currencySymbol(company.currency) : '';
    final fmt = NumberFormat('#,##0.##', 'ru_RU');

    return Scaffold(
      backgroundColor: TColors.ink,
      appBar: AppBar(
        title: Text(_loading
            ? 'Загрузка...'
            : 'Накладная ${_numberCtrl.text}'),
        actions: _isPosted
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: TColors.greenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: TColors.green.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: TColors.green, size: 14),
                        SizedBox(width: 6),
                        Text('Проведено',
                            style: TextStyle(
                                color: TColors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ]
            : [
                TextButton(
                  onPressed: _save,
                  child: const Text('Сохранить'),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton(
                    onPressed: _items.isEmpty ? null : _post,
                    style: FilledButton.styleFrom(
                      backgroundColor: TColors.green,
                      foregroundColor: TColors.ink,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Провести',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: TColors.gold))
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildItemsSection(fmt, sym)),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _LabeledField(
                    label: 'Номер документа',
                    controller: _numberCtrl,
                    enabled: !_isPosted),
              ),
              const SizedBox(width: 12),
              // Date picker button
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Дата',
                      style: TextStyle(color: TColors.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _isPosted ? null : _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: TColors.card2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: TColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 14, color: TColors.muted),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd.MM.yyyy').format(_date),
                            style: const TextStyle(
                                color: TColors.text, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                    label: 'Поставщик',
                    controller: _supplierCtrl,
                    enabled: !_isPosted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                    label: 'Примечание',
                    controller: _noteCtrl,
                    enabled: !_isPosted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(NumberFormat fmt, String sym) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: TColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TColors.border),
      ),
      child: Column(
        children: [
          // Table header row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: TColors.card2,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: TColors.border)),
            ),
            child: Row(
              children: [
                const Expanded(
                    flex: 4,
                    child: Text('Товар',
                        style: TextStyle(
                            color: TColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                _headerCell(80, 'Кол-во'),
                _headerCell(100, 'Цена'),
                _headerCell(110, 'Сумма'),
                if (!_isPosted) const SizedBox(width: 64),
              ],
            ),
          ),
          // Items list
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Нет позиций. Добавьте товары.',
                        style: TextStyle(color: TColors.muted)))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: TColors.border),
                    itemBuilder: (ctx, i) =>
                        _buildItemRow(_items[i], i, fmt, sym),
                  ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: TColors.border)),
            ),
            child: Row(
              children: [
                if (!_isPosted)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Добавить позицию'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TColors.gold,
                      side: const BorderSide(color: TColors.gold),
                    ),
                    onPressed: _addItem,
                  ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Итого',
                        style:
                            TextStyle(color: TColors.muted, fontSize: 11)),
                    Text(
                      '$sym ${fmt.format(_total)}',
                      style: TabysTheme.mono(
                          size: 20,
                          color: TColors.text,
                          weight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
      _ReceiptItemData item, int index, NumberFormat fmt, String sym) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: const TextStyle(
                        color: TColors.text,
                        fontWeight: FontWeight.w500,
                        fontSize: 13)),
                if (item.productId == null)
                  const Text('Новый товар',
                      style:
                          TextStyle(color: TColors.gold, fontSize: 10)),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '${_fmtQty(item.qty)} ${item.unit}',
              style: TabysTheme.mono(size: 12, color: TColors.text),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              '$sym ${fmt.format(item.unitPrice)}',
              style: TabysTheme.mono(size: 12, color: TColors.muted),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              '$sym ${fmt.format(item.subtotal)}',
              style: TabysTheme.mono(
                  size: 12,
                  color: TColors.text,
                  weight: FontWeight.w700),
              textAlign: TextAlign.right,
            ),
          ),
          if (!_isPosted) ...[
            const SizedBox(width: 8),
            _iconBtn(
              icon: Icons.edit_outlined,
              color: TColors.muted,
              onTap: () => _editItem(index),
            ),
            _iconBtn(
              icon: Icons.delete_outline,
              color: TColors.red,
              onTap: () => setState(() => _items.removeAt(index)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconBtn(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _addItem() async {
    final result = await showDialog<_ReceiptItemData>(
      context: context,
      builder: (_) => const _ReceiptItemDialog(),
    );
    if (result != null) setState(() => _items.add(result));
  }

  Future<void> _editItem(int index) async {
    final result = await showDialog<_ReceiptItemData>(
      context: context,
      builder: (_) => _ReceiptItemDialog(existing: _items[index]),
    );
    if (result != null) setState(() => _items[index] = result);
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final number = _numberCtrl.text.trim().isEmpty
        ? 'ПРХ'
        : _numberCtrl.text.trim();
    await db.updateReceipt(StockReceiptsCompanion(
      id: Value(widget.receiptId),
      number: Value(number),
      supplierName: Value(_supplierCtrl.text.trim().isEmpty
          ? null
          : _supplierCtrl.text.trim()),
      date: Value(_date),
      note: Value(
          _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
    ));
    await db.replaceReceiptItems(
      widget.receiptId,
      _items
          .map((item) => StockReceiptItemsCompanion.insert(
                receiptId: widget.receiptId,
                productId: Value(item.productId),
                productName: item.productName,
                unit: Value(item.unit),
                qty: item.qty,
                unitPrice: Value(item.unitPrice),
                salePrice: Value(item.salePrice),
              ))
          .toList(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Черновик сохранён')),
      );
    }
  }

  Future<void> _post() async {
    await _save();
    await ref.read(databaseProvider).postReceipt(widget.receiptId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Накладная проведена. Остатки обновлены.')),
      );
      Navigator.pop(context);
    }
  }
}

// ─── Receipt Item Dialog ──────────────────────────────────────────────────────

class _ReceiptItemDialog extends ConsumerStatefulWidget {
  final _ReceiptItemData? existing;

  const _ReceiptItemDialog({this.existing});

  @override
  ConsumerState<_ReceiptItemDialog> createState() =>
      _ReceiptItemDialogState();
}

class _ReceiptItemDialogState extends ConsumerState<_ReceiptItemDialog> {
  bool _isNew = false;
  int? _selectedProductId;

  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _isNew = ex.productId == null;
      _selectedProductId = ex.productId;
      _nameCtrl.text = ex.productName;
      _unitCtrl.text = ex.unit;
      _qtyCtrl.text = _fmtQty(ex.qty);
      _priceCtrl.text = ex.unitPrice > 0 ? ex.unitPrice.toStringAsFixed(0) : '';
      _salePriceCtrl.text =
          ex.salePrice > 0 ? ex.salePrice.toStringAsFixed(0) : '';
    } else {
      _unitCtrl.text = 'шт';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _salePriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).valueOrNull ?? [];
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Редактировать позицию' : 'Добавить позицию'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle: existing / new product
              Row(
                children: [
                  _ToggleBtn(
                    label: 'Существующий',
                    selected: !_isNew,
                    onTap: () => setState(() => _isNew = false),
                  ),
                  const SizedBox(width: 8),
                  _ToggleBtn(
                    label: 'Новый товар',
                    selected: _isNew,
                    onTap: () => setState(() => _isNew = true),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (!_isNew) ...[
                DropdownButtonFormField<int>(
                  value: _selectedProductId,
                  decoration:
                      const InputDecoration(labelText: 'Выберите товар'),
                  items: products
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              '${p.name}  (${_fmtQty(p.quantity)} ${p.unit})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final p = products.firstWhere((p) => p.id == id);
                    setState(() {
                      _selectedProductId = id;
                      _unitCtrl.text = p.unit;
                      _nameCtrl.text = p.name;
                      if (p.purchasePrice > 0) {
                        _priceCtrl.text =
                            p.purchasePrice.toStringAsFixed(0);
                      }
                    });
                  },
                ),
              ] else ...[
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Название товара *'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _unitCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Единица'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _salePriceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Цена продажи'),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: !_isNew,
                      decoration: const InputDecoration(
                          labelText: 'Количество *'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Цена закупки'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }

  void _submit() {
    final qty = double.tryParse(
        _qtyCtrl.text.trim().replaceAll(' ', '').replaceAll(',', '.'));
    if (qty == null || qty <= 0) return;
    final price = double.tryParse(
            _priceCtrl.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ??
        0.0;
    final salePrice = double.tryParse(_salePriceCtrl.text
            .trim()
            .replaceAll(' ', '')
            .replaceAll(',', '.')) ??
        0.0;

    _ReceiptItemData result;

    if (_isNew) {
      if (_nameCtrl.text.trim().isEmpty) return;
      result = _ReceiptItemData(
        productId: null,
        productName: _nameCtrl.text.trim(),
        unit: _unitCtrl.text.trim().isEmpty ? 'шт' : _unitCtrl.text.trim(),
        qty: qty,
        unitPrice: price,
        salePrice: salePrice,
      );
    } else {
      if (_selectedProductId == null) return;
      final products = ref.read(productsProvider).valueOrNull ?? [];
      final product = products.firstWhere((p) => p.id == _selectedProductId);
      result = _ReceiptItemData(
        productId: _selectedProductId,
        productName: product.name,
        unit: _unitCtrl.text.trim().isEmpty
            ? product.unit
            : _unitCtrl.text.trim(),
        qty: qty,
        unitPrice: price,
        salePrice: product.salePrice,
      );
    }

    Navigator.pop(context, result);
  }
}

// ─── Product Card ─────────────────────────────────────────────────────────────

class _ProductCard extends ConsumerWidget {
  final Product product;
  final String currency;
  final int companyId;

  const _ProductCard({
    required this.product,
    required this.currency,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(
        locale: 'ru_RU',
        symbol: currencySymbol(currency),
        decimalDigits: 0);
    final value = product.quantity * product.salePrice;

    final qtyColor = product.quantity <= 0
        ? TColors.red
        : (product.minQuantity > 0 && product.quantity <= product.minQuantity)
            ? TColors.gold
            : TColors.green;
    final qtyBg = product.quantity <= 0
        ? TColors.redBg
        : (product.minQuantity > 0 && product.quantity <= product.minQuantity)
            ? TColors.goldBg
            : TColors.greenBg;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: TColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMovements(context, ref),
        onLongPress: () => _showOptions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: TColors.text)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: qtyBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_fmtQty(product.quantity)} ${product.unit}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: qtyColor),
                      ),
                    ),
                    if (product.minQuantity > 0 &&
                        product.quantity <= product.minQuantity)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Нужен заказ',
                            style: TextStyle(
                                fontSize: 10, color: TColors.gold)),
                      ),
                  ],
                ),
              ]),
              if (product.description != null &&
                  product.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(product.description!,
                    style: const TextStyle(
                        fontSize: 12, color: TColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(children: [
                _PriceChip(
                    label: 'Закупка',
                    value: fmt.format(product.purchasePrice),
                    color: TColors.gold),
                const SizedBox(width: 8),
                _PriceChip(
                    label: 'Продажа',
                    value: fmt.format(product.salePrice),
                    color: TColors.blue),
                const Spacer(),
                Text('= ${fmt.format(value)}',
                    style: TabysTheme.mono(
                        size: 13, color: TColors.text)),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Приход'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: TColors.green,
                      side: BorderSide(
                          color: TColors.green.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => _addMovement(context, ref, 'in'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  label: const Text('Расход'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: TColors.red,
                      side: BorderSide(
                          color: TColors.red.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => _addMovement(context, ref, 'out'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showMovements(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final movements = await db.getStockMovementsByProduct(product.id);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => _MovementsDialog(
          product: product, movements: movements, currency: currency),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TColors.card,
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
                builder: (_) =>
                    _ProductDialog(companyId: companyId, product: product),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: TColors.red),
            title: const Text('Удалить',
                style: TextStyle(color: TColors.red)),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Удалить товар?'),
                  content: Text(
                      'Товар "${product.name}" и история движений будут удалены.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена')),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: TColors.red),
                      onPressed: () async {
                        Navigator.pop(context);
                        await ref
                            .read(databaseProvider)
                            .deleteProduct(product.id);
                      },
                      child: const Text('Удалить',
                          style: TextStyle(color: TColors.text)),
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

  void _addMovement(BuildContext context, WidgetRef ref, String type) {
    showDialog(
      context: context,
      builder: (_) => _MovementDialog(
          product: product, companyId: companyId, type: type, ref: ref),
    );
  }
}

// ─── Price Chip ───────────────────────────────────────────────────────────────

class _PriceChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PriceChip(
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
            fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─── Movements Dialog ─────────────────────────────────────────────────────────

class _MovementsDialog extends StatelessWidget {
  final Product product;
  final List<StockMovement> movements;
  final String currency;

  const _MovementsDialog({
    required this.product,
    required this.movements,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
        locale: 'ru_RU',
        symbol: currencySymbol(currency),
        decimalDigits: 0);
    return AlertDialog(
      title: Text(product.name),
      content: SizedBox(
        width: double.maxFinite,
        child: movements.isEmpty
            ? const Text('Нет движений по товару',
                style: TextStyle(color: TColors.muted))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: movements.length,
                itemBuilder: (ctx, i) {
                  final m = movements[i];
                  final isIn = m.type == 'in';
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isIn ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isIn ? TColors.green : TColors.red,
                    ),
                    title: Text(
                      '${isIn ? "+" : "-"}${_fmtQty(m.quantity)} ${product.unit}',
                      style: TextStyle(
                          color: isIn ? TColors.green : TColors.red,
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                        '${DateFormat('dd.MM.yyyy').format(m.date)}'
                        '${m.note != null ? "  ${m.note}" : ""}',
                        style:
                            const TextStyle(color: TColors.muted)),
                    trailing: m.price > 0
                        ? Text(fmt.format(m.price),
                            style: TabysTheme.mono(
                                size: 12, color: TColors.muted))
                        : null,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'))
      ],
    );
  }
}

// ─── Movement Dialog ──────────────────────────────────────────────────────────

class _MovementDialog extends StatefulWidget {
  final Product product;
  final int companyId;
  final String type;
  final WidgetRef ref;

  const _MovementDialog({
    required this.product,
    required this.companyId,
    required this.type,
    required this.ref,
  });

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIn = widget.type == 'in';
    return AlertDialog(
      title: Text(isIn
          ? 'Приход: ${widget.product.name}'
          : 'Расход: ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _qtyCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Количество',
              suffixText: widget.product.unit,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Цена (необязательно)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
                labelText: 'Примечание (необязательно)'),
          ),
        ],
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
    final qty = double.tryParse(
        _qtyCtrl.text.replaceAll(' ', '').replaceAll(',', '.'));
    if (qty == null || qty <= 0) return;
    final price = double.tryParse(
            _priceCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ??
        0.0;
    await widget.ref.read(databaseProvider).insertStockMovement(
          StockMovementsCompanion.insert(
            companyId: widget.companyId,
            productId: widget.product.id,
            type: Value(widget.type),
            quantity: qty,
            price: Value(price),
            date: DateTime.now(),
            note: Value(_noteCtrl.text.trim().isEmpty
                ? null
                : _noteCtrl.text.trim()),
          ),
        );
    if (mounted) Navigator.pop(context);
  }
}

// ─── Product Dialog ───────────────────────────────────────────────────────────

class _ProductDialog extends ConsumerStatefulWidget {
  final int companyId;
  final Product? product;

  const _ProductDialog({required this.companyId, this.product});

  @override
  ConsumerState<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<_ProductDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _purchaseCtrl;
  late final TextEditingController _saleCtrl;
  late final TextEditingController _minQtyCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _unitCtrl = TextEditingController(text: p?.unit ?? 'шт');
    _purchaseCtrl = TextEditingController(
        text: p != null && p.purchasePrice > 0
            ? p.purchasePrice.toStringAsFixed(0)
            : '');
    _saleCtrl = TextEditingController(
        text: p != null && p.salePrice > 0
            ? p.salePrice.toStringAsFixed(0)
            : '');
    _minQtyCtrl = TextEditingController(
        text: p != null && p.minQuantity > 0
            ? p.minQuantity.toStringAsFixed(0)
            : '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _purchaseCtrl.dispose();
    _saleCtrl.dispose();
    _minQtyCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return AlertDialog(
      title: Text(isEdit ? 'Редактировать товар' : 'Новый товар'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Название *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _unitCtrl,
              decoration:
                  const InputDecoration(labelText: 'Единица (шт/кг/л/м)'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _purchaseCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Закупочная цена'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _saleCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Цена продажи'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _minQtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Мин. остаток (точка перезаказа)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              decoration:
                  const InputDecoration(labelText: 'Описание (необязательно)'),
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
    if (_nameCtrl.text.trim().isEmpty) return;
    final db = ref.read(databaseProvider);
    final purchase = double.tryParse(
            _purchaseCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ??
        0.0;
    final sale = double.tryParse(
            _saleCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ??
        0.0;
    final minQty = double.tryParse(
            _minQtyCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ??
        0.0;
    final desc =
        _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
    final unit =
        _unitCtrl.text.trim().isEmpty ? 'шт' : _unitCtrl.text.trim();

    if (widget.product == null) {
      await db.insertProduct(ProductsCompanion.insert(
        companyId: widget.companyId,
        name: _nameCtrl.text.trim(),
        unit: Value(unit),
        purchasePrice: Value(purchase),
        salePrice: Value(sale),
        minQuantity: Value(minQty),
        description: Value(desc),
      ));
    } else {
      await db.updateProduct(ProductsCompanion(
        id: Value(widget.product!.id),
        companyId: Value(widget.companyId),
        name: Value(_nameCtrl.text.trim()),
        unit: Value(unit),
        purchasePrice: Value(purchase),
        salePrice: Value(sale),
        minQuantity: Value(minQty),
        description: Value(desc),
      ));
    }
    if (mounted) Navigator.pop(context);
  }
}

// ─── Toggle Button ────────────────────────────────────────────────────────────

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleBtn(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? TColors.goldBg : TColors.card2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? TColors.gold : TColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? TColors.gold : TColors.muted),
        ),
      ),
    );
  }
}

// ─── Labeled Field ────────────────────────────────────────────────────────────

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: TColors.muted, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          style: const TextStyle(color: TColors.text, fontSize: 13),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

// ─── Header Cell ─────────────────────────────────────────────────────────────

Widget _headerCell(double width, String label) {
  return SizedBox(
    width: width,
    child: Text(label,
        textAlign: TextAlign.right,
        style: const TextStyle(
            color: TColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600)),
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _fmtQty(double qty) =>
    qty == qty.floorToDouble() && qty >= 0
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
