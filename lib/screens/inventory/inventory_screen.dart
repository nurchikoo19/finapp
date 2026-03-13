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

enum _InvSort { name, quantity, value }

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  _InvSort _sort = _InvSort.name;

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(selectedCompanyProvider);
    if (company == null) {
      return const Scaffold(body: Center(child: Text('Нет компании')));
    }
    final productsAsync = ref.watch(productsProvider);
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: _sym(company.currency), decimalDigits: 0);

    return Scaffold(
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inventory_2, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text('Нет товаров. Нажмите + чтобы добавить.'),
              ]),
            );
          }
          final totalValue =
              products.fold(0.0, (s, p) => s + p.quantity * p.salePrice);

          final sorted = [...products];
          switch (_sort) {
            case _InvSort.name:
              sorted.sort((a, b) => a.name.compareTo(b.name));
              break;
            case _InvSort.quantity:
              sorted.sort((a, b) => b.quantity.compareTo(a.quantity));
              break;
            case _InvSort.value:
              sorted.sort((a, b) => (b.quantity * b.salePrice)
                  .compareTo(a.quantity * a.salePrice));
              break;
          }

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${products.length} позиций',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Text(
                              'Стоимость склада: ${fmt.format(totalValue)}',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    DropdownButton<_InvSort>(
                      value: _sort,
                      underline: const SizedBox(),
                      isDense: true,
                      items: const [
                        DropdownMenuItem(
                            value: _InvSort.name,
                            child: Text('По имени',
                                style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(
                            value: _InvSort.quantity,
                            child: Text('По кол-ву',
                                style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(
                            value: _InvSort.value,
                            child: Text('По стоимости',
                                style: TextStyle(fontSize: 13))),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Добавить товар'),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => _ProductDialog(companyId: company.id),
        ),
      ),
    );
  }
}

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
        locale: 'ru_RU', symbol: _sym(currency), decimalDigits: 0);
    final value = product.quantity * product.salePrice;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: product.quantity <= 0
                            ? Colors.red.shade100
                            : (product.minQuantity > 0 &&
                                    product.quantity <= product.minQuantity)
                                ? Colors.orange.shade100
                                : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${product.quantity.toStringAsFixed(product.quantity == product.quantity.roundToDouble() ? 0 : 2)} ${product.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: product.quantity <= 0
                              ? Colors.red.shade700
                              : (product.minQuantity > 0 &&
                                      product.quantity <= product.minQuantity)
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                        ),
                      ),
                    ),
                    if (product.minQuantity > 0 &&
                        product.quantity <= product.minQuantity)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Нужен заказ',
                            style: TextStyle(
                                fontSize: 10, color: Colors.orange.shade700)),
                      ),
                  ],
                ),
              ]),
              if (product.description != null &&
                  product.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(product.description!,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(children: [
                _PriceChip(
                    label: 'Закупка',
                    value: fmt.format(product.purchasePrice),
                    color: Colors.orange),
                const SizedBox(width: 8),
                _PriceChip(
                    label: 'Продажа',
                    value: fmt.format(product.salePrice),
                    color: Colors.blue),
                const Spacer(),
                Text('= ${fmt.format(value)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Приход'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
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
                      foregroundColor: Colors.red,
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
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Удалить', style: TextStyle(color: Colors.red)),
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
                          backgroundColor: Colors.red),
                      onPressed: () async {
                        Navigator.pop(context);
                        await ref
                            .read(databaseProvider)
                            .deleteProduct(product.id);
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

  void _addMovement(BuildContext context, WidgetRef ref, String type) {
    showDialog(
      context: context,
      builder: (_) => _MovementDialog(
          product: product, companyId: companyId, type: type, ref: ref),
    );
  }
}

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
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

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
        locale: 'ru_RU', symbol: _sym(currency), decimalDigits: 0);
    return AlertDialog(
      title: Text(product.name),
      content: SizedBox(
        width: double.maxFinite,
        child: movements.isEmpty
            ? const Text('Нет движений по товару')
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
                      color: isIn ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      '${isIn ? "+" : "-"}${m.quantity} ${product.unit}',
                      style: TextStyle(
                          color: isIn ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                        '${DateFormat('dd.MM.yyyy').format(m.date)}'
                        '${m.note != null ? "  ${m.note}" : ""}'),
                    trailing: m.price > 0
                        ? Text(fmt.format(m.price),
                            style: const TextStyle(fontSize: 12))
                        : null,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Закрыть'))
      ],
    );
  }
}

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
      title: Text(isIn ? 'Приход: ${widget.product.name}' : 'Расход: ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Количество',
              suffixText: widget.product.unit,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Цена (необязательно)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Примечание (необязательно)'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  void _save() async {
    final qty =
        double.tryParse(_qtyCtrl.text.replaceAll(' ', '').replaceAll(',', '.'));
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
            note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
          ),
        );
    if (mounted) Navigator.pop(context);
  }
}

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
              decoration: const InputDecoration(labelText: 'Единица (шт/кг/л/м)'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _purchaseCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Закупочная цена'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _saleCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Цена продажи'),
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
            onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
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
    final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
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
