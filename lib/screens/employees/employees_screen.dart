import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../db/database.dart';
import '../../widgets/employee_avatar.dart';
import '../../widgets/status_badge.dart';

enum _EmpSort { name, role, tasks }

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  _EmpSort _sort = _EmpSort.name;

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      body: employeesAsync.when(
        data: (employees) {
          final tasks = tasksAsync.valueOrNull ?? [];
          if (employees.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text('Нет сотрудников. Добавьте первого.'),
              ]),
            );
          }

          final sorted = [...employees];
          switch (_sort) {
            case _EmpSort.name:
              sorted.sort((a, b) => a.name.compareTo(b.name));
              break;
            case _EmpSort.role:
              sorted.sort((a, b) =>
                  (a.role ?? '').compareTo(b.role ?? ''));
              break;
            case _EmpSort.tasks:
              sorted.sort((a, b) {
                final aCount =
                    tasks.where((t) => t.assignedTo == a.id).length;
                final bCount =
                    tasks.where((t) => t.assignedTo == b.id).length;
                return bCount.compareTo(aCount);
              });
              break;
          }

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  const Text('Сортировка:',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  DropdownButton<_EmpSort>(
                    value: _sort,
                    underline: const SizedBox(),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                          value: _EmpSort.name,
                          child: Text('По имени', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: _EmpSort.role,
                          child: Text('По должности', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: _EmpSort.tasks,
                          child: Text('По задачам', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) => setState(() => _sort = v!),
                  ),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  itemBuilder: (ctx, i) {
                    final emp = sorted[i];
                    final empTasks =
                        tasks.where((t) => t.assignedTo == emp.id).toList();
                    return _EmployeeCard(employee: emp, tasks: empTasks);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Добавить сотрудника'),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const _EmployeeDialog(),
        ),
      ),
    );
  }
}

class _EmployeeCard extends ConsumerWidget {
  final Employee employee;
  final List<Task> tasks;

  const _EmployeeCard({required this.employee, required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = tasks.where((t) => t.status == 'new' || t.status == 'in_progress').length;
    final done = tasks.where((t) => t.status == 'done').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: EmployeeAvatar(
          name: employee.name,
          colorValue: employee.color,
          radius: 22,
        ),
        title: Text(
          employee.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(employee.role ?? 'Без роли'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatBadge(label: 'Открыто', count: open, color: Colors.orange),
            const SizedBox(width: 8),
            _StatBadge(label: 'Готово', count: done, color: Colors.green),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Нет задач'),
            )
          else
            ...tasks.map(
              (t) => ListTile(
                title: Text(t.title, style: const TextStyle(fontSize: 14)),
                trailing: StatusBadge(status: t.status),
                dense: true,
              ),
            ),
          FutureBuilder<List<Invoice>>(
            future: ref.read(databaseProvider).getInvoicesBySalesPerson(employee.id),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.isEmpty) return const SizedBox();
              final invs = snap.data!;
              final total = invs.fold(0.0, (s, i) => s + i.totalAmount);
              final commission = invs.fold(
                  0.0, (s, i) => s + i.totalAmount * i.commissionPct / 100);
              final fmt = NumberFormat('#,##0', 'ru_RU');
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Статистика менеджера',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _StatBadge(label: 'Инвойсов', count: invs.length, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Сумма: ${fmt.format(total)}',
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (commission > 0) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Комиссия: ${fmt.format(commission)}',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Изменить'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _EmployeeDialog(existing: employee),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                label: const Text('Удалить', style: TextStyle(color: Colors.red)),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Удалить сотрудника?'),
                    content: Text(
                        'Сотрудник "${employee.name}" будет удалён.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отмена')),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          ref
                              .read(databaseProvider)
                              .deleteEmployee(employee.id);
                        },
                        child: const Text('Удалить'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmployeeDialog extends ConsumerStatefulWidget {
  final Employee? existing;
  const _EmployeeDialog({this.existing});

  @override
  ConsumerState<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends ConsumerState<_EmployeeDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _roleCtrl;
  int _color = 0xFF2196F3;

  static const _colorOptions = [
    0xFF2196F3, // blue
    0xFF4CAF50, // green
    0xFFF44336, // red
    0xFFFF9800, // orange
    0xFF9C27B0, // purple
    0xFF00BCD4, // cyan
    0xFF795548, // brown
    0xFF607D8B, // blue-grey
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _roleCtrl = TextEditingController(text: widget.existing?.role ?? '');
    _color = widget.existing?.color ?? 0xFF2196F3;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Новый сотрудник' : 'Редактировать сотрудника'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Имя'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _roleCtrl,
            decoration: const InputDecoration(labelText: 'Должность'),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Цвет аватара', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _colorOptions.map((c) {
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: _color == c
                        ? Border.all(color: Colors.black, width: 3)
                        : null,
                  ),
                ),
              );
            }).toList(),
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
    final company = ref.read(selectedCompanyProvider);
    if (widget.existing == null) {
      db.insertEmployee(EmployeesCompanion.insert(
        companyId: Value(company?.id),
        name: _nameCtrl.text.trim(),
        role: Value(_roleCtrl.text.trim().isEmpty ? null : _roleCtrl.text.trim()),
        color: Value(_color),
      ));
    } else {
      db.updateEmployee(EmployeesCompanion(
        id: Value(widget.existing!.id),
        companyId: Value(company?.id),
        name: Value(_nameCtrl.text.trim()),
        role: Value(_roleCtrl.text.trim().isEmpty ? null : _roleCtrl.text.trim()),
        color: Value(_color),
      ));
    }
    Navigator.pop(context);
  }
}
