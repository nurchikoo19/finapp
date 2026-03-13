import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';

class TelegramService {
  static const _tokenKey = 'tg_bot_token';
  static const _chatKey = 'tg_chat_id';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getChatId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chatKey);
  }

  static Future<void> saveConfig(String token, String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token.trim());
    await prefs.setString(_chatKey, chatId.trim());
  }

  static Future<bool> sendMessage(
      String token, String chatId, String text) async {
    try {
      final url =
          Uri.parse('https://api.telegram.org/bot$token/sendMessage');
      final resp = await http.post(url, body: {
        'chat_id': chatId,
        'text': text,
        'parse_mode': 'HTML',
      }).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Собирает ежедневный дайджест и отправляет если настроен токен.
  static Future<bool> sendDailyDigest(
      AppDatabase db, int companyId, String companyName, String currency) async {
    final token = await getToken();
    final chatId = await getChatId();
    if (token == null || token.isEmpty || chatId == null || chatId.isEmpty) {
      return false;
    }
    final text =
        await buildDailyDigest(db, companyId, companyName, currency);
    return sendMessage(token, chatId, text);
  }

  static Future<String> buildDailyDigest(
    AppDatabase db,
    int companyId,
    String companyName,
    String currency,
  ) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    final accounts = await db.getAccountsByCompany(companyId);
    final totalBalance =
        accounts.fold(0.0, (s, a) => s + a.balance);

    final txs = await db.getTransactionsByCompany(companyId,
        from: monthStart, to: monthEnd);
    final income = txs
        .where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final expense = txs
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);

    final invoices = await db.watchInvoicesByCompany(companyId).first;
    final overdue = invoices
        .where((inv) =>
            inv.dueDate != null &&
            inv.dueDate!.isBefore(now) &&
            inv.status != 'paid' &&
            inv.status != 'cancelled')
        .length;
    final pendingTotal = invoices
        .where((inv) =>
            inv.status == 'pending' || inv.status == 'partial')
        .fold(0.0, (s, inv) => s + inv.totalAmount);

    final tasks = await db.getTasksByCompany(companyId);
    final todayTasks = tasks
        .where((t) =>
            t.dueDate != null &&
            t.dueDate!.year == now.year &&
            t.dueDate!.month == now.month &&
            t.dueDate!.day == now.day &&
            t.status != 'done' &&
            t.status != 'cancelled')
        .toList();

    final fmt = NumberFormat('#,##0', 'ru_RU');
    final sym = _sym(currency);
    final monthName =
        DateFormat('MMMM yyyy', 'ru').format(now);

    final buf = StringBuffer();
    buf.writeln('📊 <b>FinApp — $companyName</b>');
    buf.writeln(
        DateFormat('dd.MM.yyyy', 'ru').format(now));
    buf.writeln();
    buf.writeln(
        '💰 <b>Общий баланс:</b> ${fmt.format(totalBalance)} $sym');
    buf.writeln();
    buf.writeln('📅 <b>$monthName:</b>');
    buf.writeln('  ↑ Доходы: ${fmt.format(income)} $sym');
    buf.writeln('  ↓ Расходы: ${fmt.format(expense)} $sym');
    final net = income - expense;
    buf.writeln(
        '  = Поток: ${net >= 0 ? "+" : ""}${fmt.format(net)} $sym');

    if (pendingTotal > 0) {
      buf.writeln();
      buf.writeln(
          '🧾 <b>Ожидает оплаты:</b> ${fmt.format(pendingTotal)} $sym');
    }
    if (overdue > 0) {
      buf.writeln('⚠️ <b>Просроченных инвойсов:</b> $overdue');
    }

    if (todayTasks.isNotEmpty) {
      buf.writeln();
      buf.writeln(
          '📋 <b>Задачи на сегодня (${todayTasks.length}):</b>');
      for (final t in todayTasks.take(5)) {
        buf.writeln('  • ${t.title}');
      }
    }

    return buf.toString();
  }

  static String _sym(String code) {
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
}
