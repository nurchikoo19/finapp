import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../../providers/database_provider.dart';
import '../../db/database.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/employee_avatar.dart';

String _fmtDue(DateTime dt) {
  final hasTime = dt.hour != 0 || dt.minute != 0;
  return hasTime
      ? DateFormat('dd.MM.yyyy HH:mm').format(dt)
      : DateFormat('dd.MM.yyyy').format(dt);
}

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(filteredTasksProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final company = ref.watch(selectedCompanyProvider);
    ref.watch(taskFilterEmployeeProvider);
    final filterStatus = ref.watch(taskFilterStatusProvider);
    final search = ref.watch(taskSearchProvider);
    final taskSort = ref.watch(taskSortProvider);

    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Поиск по задачам...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(taskSearchProvider.notifier).state = '';
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              onChanged: (v) =>
                  ref.read(taskSearchProvider.notifier).state = v,
            ),
          ),
          // Filters bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Status filter
                _FilterChip(
                  label: 'Все статусы',
                  selected: filterStatus == null,
                  onTap: () => ref.read(taskFilterStatusProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                const SizedBox(width: 16),
                const VerticalDivider(width: 1, indent: 4, endIndent: 4),
                const SizedBox(width: 16),
                _FilterChip(
                  label: 'По дедлайну',
                  selected: taskSort == 'deadline',
                  onTap: () => ref.read(taskSortProvider.notifier).state =
                      taskSort == 'deadline' ? 'none' : 'deadline',
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'По приоритету',
                  selected: taskSort == 'priority',
                  onTap: () => ref.read(taskSortProvider.notifier).state =
                      taskSort == 'priority' ? 'none' : 'priority',
                ),
                const SizedBox(width: 16),
                const VerticalDivider(width: 1, indent: 4, endIndent: 4),
                const SizedBox(width: 16),
                ...['new', 'in_progress', 'done', 'cancelled'].map((s) {
                  const labels = {
                    'new': 'Новые',
                    'in_progress': 'В работе',
                    'done': 'Выполненные',
                    'cancelled': 'Отменённые',
                  };
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: labels[s]!,
                      selected: filterStatus == s,
                      onTap: () =>
                          ref.read(taskFilterStatusProvider.notifier).state =
                              filterStatus == s ? null : s,
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: employeesAsync.when(
              data: (employees) {
                final empMap = {for (final e in employees) e.id: e};
                if (tasks.isEmpty) {
                  return const Center(child: Text('Нет задач'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) => _TaskCard(
                    task: tasks[i],
                    employee: tasks[i].assignedTo != null
                        ? empMap[tasks[i].assignedTo!]
                        : null,
                    onTap: () => _openDetail(context, tasks[i], empMap),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
      floatingActionButton: company != null
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Новая задача'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _TaskDialog(companyId: company.id),
              ),
            )
          : null,
    );
  }

  void _openDetail(
    BuildContext context,
    Task task,
    Map<int, Employee> empMap,
  ) {
    showDialog(
      context: context,
      builder: (_) => _TaskDetailDialog(task: task, empMap: empMap),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final Employee? employee;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.employee,
    required this.onTap,
  });

  bool get _isOverdue =>
      task.dueDate != null &&
      task.dueDate!.isBefore(DateTime.now()) &&
      task.status != 'done' &&
      task.status != 'cancelled';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  PriorityBadge(priority: task.priority),
                ],
              ),
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  StatusBadge(status: task.status),
                  const SizedBox(width: 8),
                  if (task.dueDate != null) ...[
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: _isOverdue ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _fmtDue(task.dueDate!),
                      style: TextStyle(
                        fontSize: 12,
                        color: _isOverdue ? Colors.red : Colors.grey[600],
                        fontWeight: _isOverdue ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (employee != null)
                    Row(
                      children: [
                        EmployeeAvatar(
                          name: employee!.name,
                          colorValue: employee!.color,
                          radius: 12,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          employee!.name.split(' ').first,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskDetailDialog extends ConsumerWidget {
  final Task task;
  final Map<int, Employee> empMap;

  const _TaskDetailDialog({required this.task, required this.empMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = task.assignedTo != null ? empMap[task.assignedTo!] : null;

    return AlertDialog(
      title: Text(task.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.description != null && task.description!.isNotEmpty)
            Text(task.description!),
          const SizedBox(height: 12),
          Row(children: [
            StatusBadge(status: task.status),
            const SizedBox(width: 8),
            PriorityBadge(priority: task.priority),
          ]),
          if (task.dueDate != null) ...[
            const SizedBox(height: 8),
            Text('Срок: ${_fmtDue(task.dueDate!)}'),
          ],
          if (employee != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              EmployeeAvatar(
                  name: employee.name, colorValue: employee.color, radius: 14),
              const SizedBox(width: 8),
              Text(employee.name),
            ]),
          ],
          const Divider(height: 24),
          const Text('Изменить статус:',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['new', 'in_progress', 'done', 'cancelled'].map((s) {
              const labels = {
                'new': 'Новая',
                'in_progress': 'В работе',
                'done': 'Выполнена',
                'cancelled': 'Отменена',
              };
              return ActionChip(
                label: Text(labels[s]!),
                backgroundColor:
                    task.status == s ? Colors.blue.shade100 : null,
                onPressed: () {
                  ref.read(databaseProvider).updateTask(TasksCompanion(
                        id: Value(task.id),
                        status: Value(s),
                      ));
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Удалить задачу?'),
                content: Text('Задача "${task.title}" будет удалена.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      ref.read(databaseProvider).deleteTask(task.id);
                    },
                    child: const Text('Удалить'),
                  ),
                ],
              ),
            );
          },
          child: const Text('Удалить'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            final company = ref.read(selectedCompanyProvider);
            if (company != null) {
              showDialog(
                context: context,
                builder: (_) =>
                    _TaskDialog(companyId: company.id, existing: task),
              );
            }
          },
          child: const Text('Редактировать'),
        ),
      ],
    );
  }
}

class _TaskDialog extends ConsumerStatefulWidget {
  final int companyId;
  final Task? existing;

  const _TaskDialog({required this.companyId, this.existing});

  @override
  ConsumerState<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends ConsumerState<_TaskDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  int? _assignedTo;
  DateTime? _dueDate;
  String _status = 'new';
  String _priority = 'medium';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _assignedTo = widget.existing?.assignedTo;
    _dueDate = widget.existing?.dueDate;
    _status = widget.existing?.status ?? 'new';
    _priority = widget.existing?.priority ?? 'medium';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);

    return employeesAsync.when(
      data: (employees) => AlertDialog(
        title: Text(widget.existing == null ? 'Новая задача' : 'Редактировать задачу'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _assignedTo,
                decoration: const InputDecoration(labelText: 'Исполнитель'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Не назначен —')),
                  ...employees.map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(e.name),
                      )),
                ],
                onChanged: (v) => setState(() => _assignedTo = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Приоритет'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Низкий')),
                  DropdownMenuItem(value: 'medium', child: Text('Средний')),
                  DropdownMenuItem(value: 'high', child: Text('Высокий')),
                ],
                onChanged: (v) => setState(() => _priority = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Статус'),
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('Новая')),
                  DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
                  DropdownMenuItem(value: 'done', child: Text('Выполнена')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Отменена')),
                ],
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _dueDate != null
                      ? 'Срок: ${_fmtDue(_dueDate!)}'
                      : 'Срок не задан',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_dueDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _dueDate = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      onPressed: _pickDate,
                    ),
                  ],
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
      ),
      loading: () => const AlertDialog(
        content: CircularProgressIndicator(),
      ),
      error: (e, _) => AlertDialog(content: Text('$e')),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ru'),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: _dueDate != null
          ? TimeOfDay.fromDateTime(_dueDate!)
          : TimeOfDay.now(),
    );
    setState(() {
      _dueDate = DateTime(d.year, d.month, d.day,
          t?.hour ?? 0, t?.minute ?? 0);
    });
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) return;
    final db = ref.read(databaseProvider);
    if (widget.existing == null) {
      db.insertTask(TasksCompanion.insert(
        companyId: widget.companyId,
        title: _titleCtrl.text.trim(),
        description: Value(_descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim()),
        assignedTo: Value(_assignedTo),
        dueDate: Value(_dueDate),
        status: Value(_status),
        priority: Value(_priority),
      ));
    } else {
      db.updateTask(TasksCompanion(
        id: Value(widget.existing!.id),
        title: Value(_titleCtrl.text.trim()),
        description: Value(_descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim()),
        assignedTo: Value(_assignedTo),
        dueDate: Value(_dueDate),
        status: Value(_status),
        priority: Value(_priority),
      ));
    }
    Navigator.pop(context);
  }
}
