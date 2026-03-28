import 'package:local_notifier/local_notifier.dart';
import '../db/database.dart';

class TaskNotificationService {
  /// Checks for overdue and today's tasks and shows Windows toast notifications.
  static Future<void> checkAndNotify(AppDatabase db, int companyId) async {
    final allTasks = await db.getTasksByCompany(companyId);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final active = allTasks.where((t) =>
        t.dueDate != null &&
        t.status != 'done' &&
        t.status != 'cancelled');

    final overdue =
        active.where((t) => t.dueDate!.isBefore(today)).toList();
    final dueToday = active
        .where((t) => !t.dueDate!.isBefore(today) && t.dueDate!.isBefore(tomorrow))
        .toList();

    if (overdue.isNotEmpty) {
      final titles = overdue.take(3).map((t) => t.title).join(', ');
      final extra = overdue.length > 3 ? ' и ещё ${overdue.length - 3}' : '';
      await _show(
        id: 'tabys_overdue',
        title: 'Просрочено задач: ${overdue.length}',
        body: '$titles$extra',
      );
    }

    if (dueToday.isNotEmpty) {
      final titles = dueToday.take(3).map((t) => t.title).join(', ');
      final extra = dueToday.length > 3 ? ' и ещё ${dueToday.length - 3}' : '';
      await _show(
        id: 'tabys_today',
        title: 'Задачи на сегодня: ${dueToday.length}',
        body: '$titles$extra',
      );
    }
  }

  static Future<void> _show({
    required String id,
    required String title,
    required String body,
  }) async {
    final notification = LocalNotification(
      identifier: id,
      title: title,
      body: body,
    );
    await notification.show();
  }
}
