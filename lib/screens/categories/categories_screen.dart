import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../providers/database_provider.dart';
import '../../db/database.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final company = ref.watch(selectedCompanyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Категории'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Доходы', icon: Icon(Icons.trending_up)),
            Tab(text: 'Расходы', icon: Icon(Icons.trending_down)),
          ],
        ),
      ),
      body: categoriesAsync.when(
        data: (cats) => TabBarView(
          controller: _tabCtrl,
          children: [
            _CategoryList(
              categories: cats.where((c) => c.type == 'income').toList(),
              type: 'income',
            ),
            _CategoryList(
              categories: cats.where((c) => c.type == 'expense').toList(),
              type: 'expense',
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: company != null
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Добавить категорию'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _CategoryDialog(
                  companyId: company.id,
                  defaultType: _tabCtrl.index == 0 ? 'income' : 'expense',
                ),
              ),
            )
          : null,
    );
  }
}

class _CategoryList extends ConsumerWidget {
  final List<Category> categories;
  final String type;

  const _CategoryList({required this.categories, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'income' ? Icons.trending_up : Icons.trending_down,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Нет категорий ${type == 'income' ? 'доходов' : 'расходов'}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (ctx, i) {
        final cat = categories[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (type == 'income' ? Colors.green : Colors.red)
                  .withValues(alpha: 0.15),
              child: Icon(
                type == 'income' ? Icons.trending_up : Icons.trending_down,
                color: type == 'income' ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            title: Text(cat.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _CategoryDialog(
                      companyId: cat.companyId,
                      existing: cat,
                      defaultType: type,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () => _confirmDelete(context, ref, cat),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Category cat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(
          'Категория "${cat.name}" будет удалена. '
          'Транзакции с этой категорией останутся без категории.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(databaseProvider).deleteCategory(cat.id);
              Navigator.pop(context);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  final int companyId;
  final Category? existing;
  final String defaultType;

  const _CategoryDialog({
    required this.companyId,
    this.existing,
    required this.defaultType,
  });

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  late final TextEditingController _nameCtrl;
  late String _type;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _type = widget.existing?.type ?? widget.defaultType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Новая категория' : 'Редактировать'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Название категории'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'income',
                label: Text('Доход'),
                icon: Icon(Icons.trending_up),
              ),
              ButtonSegment(
                value: 'expense',
                label: Text('Расход'),
                icon: Icon(Icons.trending_down),
              ),
            ],
            selected: {_type},
            onSelectionChanged: widget.existing == null
                ? (s) => setState(() => _type = s.first)
                : null,
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
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final db = ref.read(databaseProvider);
    if (widget.existing == null) {
      db.insertCategory(CategoriesCompanion.insert(
        companyId: widget.companyId,
        name: name,
        type: Value(_type),
      ));
    } else {
      db.updateCategory(CategoriesCompanion(
        id: Value(widget.existing!.id),
        companyId: Value(widget.companyId),
        name: Value(name),
        type: Value(widget.existing!.type),
      ));
    }
    Navigator.pop(context);
  }
}
