import 'dart:io';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database.dart';

class SheetsSettings {
  final String clientId;
  final String clientSecret;
  final String spreadsheetId;
  final String? refreshToken;

  const SheetsSettings({
    required this.clientId,
    required this.clientSecret,
    required this.spreadsheetId,
    this.refreshToken,
  });

  bool get isConfigured =>
      clientId.isNotEmpty && clientSecret.isNotEmpty && spreadsheetId.isNotEmpty;

  static Future<SheetsSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SheetsSettings(
      clientId: prefs.getString('sheets_client_id') ?? '',
      clientSecret: prefs.getString('sheets_client_secret') ?? '',
      spreadsheetId: prefs.getString('sheets_spreadsheet_id') ?? '',
      refreshToken: prefs.getString('sheets_refresh_token'),
    );
  }

  Future<void> save({String? refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sheets_client_id', clientId);
    await prefs.setString('sheets_client_secret', clientSecret);
    await prefs.setString('sheets_spreadsheet_id', spreadsheetId);
    if (refreshToken != null) {
      await prefs.setString('sheets_refresh_token', refreshToken);
    }
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sheets_refresh_token');
  }
}

class SheetsService {
  static const _scopes = [SheetsApi.spreadsheetsScope];
  static final _dateFmt = DateFormat('dd.MM.yyyy HH:mm');

  /// Syncs transactions and invoices to Google Sheets.
  /// Returns a status message.
  static Future<String> sync(
    AppDatabase db,
    int companyId,
    SheetsSettings settings,
  ) async {
    if (!settings.isConfigured) {
      return 'Заполните Client ID, Client Secret и Spreadsheet ID';
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return 'Google Sheets синхронизация доступна только на Windows/macOS/Linux.\n'
          'Используйте десктопную версию приложения.';
    }

    final clientId = ClientId(settings.clientId, settings.clientSecret);
    late AuthClient client;

    // Try to use saved refresh token first
    if (settings.refreshToken != null && settings.refreshToken!.isNotEmpty) {
      try {
        final expiredCreds = AccessCredentials(
          AccessToken('Bearer', '', DateTime.now().toUtc()),
          settings.refreshToken,
          _scopes,
        );
        final baseClient = http.Client();
        final refreshed = await refreshCredentials(clientId, expiredCreds, baseClient);
        client = authenticatedClient(baseClient, refreshed);
      } catch (_) {
        // Refresh failed — do full OAuth
        client = await _fullOAuth(clientId, settings);
      }
    } else {
      client = await _fullOAuth(clientId, settings);
    }

    try {
      final sheetsApi = SheetsApi(client);
      final sid = settings.spreadsheetId;

      // Get existing sheet names
      final spreadsheet = await sheetsApi.spreadsheets.get(sid);
      final sheetNames = spreadsheet.sheets
              ?.map((s) => s.properties?.title ?? '')
              .toSet() ??
          {};

      // Ensure required sheets exist
      final requests = <Request>[];
      for (final name in ['Транзакции', 'Счета']) {
        if (!sheetNames.contains(name)) {
          requests.add(Request(
            addSheet: AddSheetRequest(
              properties: SheetProperties(title: name),
            ),
          ));
        }
      }
      if (requests.isNotEmpty) {
        await sheetsApi.spreadsheets.batchUpdate(
          BatchUpdateSpreadsheetRequest(requests: requests),
          sid,
        );
      }

      // Sync transactions
      final txs = await db.getTransactionsByCompany(companyId);
      final cats = await db.getCategoriesByCompany(companyId);
      final accounts = await db.getAccountsByCompany(companyId);
      final catMap = {for (final c in cats) c.id: c.name};
      final accMap = {for (final a in accounts) a.id: a.name};

      final txRows = <List<Object>>[
        ['Дата', 'Тип', 'Счёт', 'Категория', 'Сумма', 'Описание'],
      ];
      for (final tx in txs) {
        final type = switch (tx.type) {
          'income' => 'Доход',
          'expense' => 'Расход',
          _ => 'Перевод',
        };
        txRows.add([
          _dateFmt.format(tx.date),
          type,
          accMap[tx.accountId] ?? '',
          tx.categoryId != null ? (catMap[tx.categoryId!] ?? '') : '',
          tx.amount,
          tx.description ?? '',
        ]);
      }
      await _writeSheet(sheetsApi, sid, 'Транзакции', txRows);

      // Sync invoices
      final invoices = await db.watchInvoicesByCompany(companyId).first;
      const statusLabels = {
        'pending': 'Ожидает',
        'partial': 'Частично',
        'paid': 'Оплачен',
        'cancelled': 'Отменён',
      };
      final invRows = <List<Object>>[
        ['Клиент', 'Сумма', 'Валюта', 'Внесено', 'Остаток', 'Статус', 'Срок оплаты'],
      ];
      for (final inv in invoices) {
        final paid = await db.getPaidAmountForInvoice(inv.id);
        invRows.add(<Object>[
          inv.clientName,
          inv.totalAmount,
          inv.currency,
          paid,
          inv.totalAmount - paid,
          statusLabels[inv.status] ?? inv.status,
          inv.dueDate != null ? DateFormat('dd.MM.yyyy').format(inv.dueDate!) : '',
        ]);
      }
      await _writeSheet(sheetsApi, sid, 'Счета', invRows);

      // Save refresh token for next time
      final newToken = client.credentials.refreshToken;
      await settings.save(refreshToken: newToken);

      return 'Синхронизировано: ${txs.length} транзакций, ${invoices.length} счетов';
    } finally {
      client.close();
    }
  }

  static Future<void> _writeSheet(
    SheetsApi api,
    String spreadsheetId,
    String sheetName,
    List<List<Object>> rows,
  ) async {
    await api.spreadsheets.values.clear(
      ClearValuesRequest(),
      spreadsheetId,
      '$sheetName!A:Z',
    );
    await api.spreadsheets.values.update(
      ValueRange(values: rows),
      spreadsheetId,
      '$sheetName!A1',
      valueInputOption: 'USER_ENTERED',
    );
  }

  static Future<AutoRefreshingAuthClient> _fullOAuth(
    ClientId clientId,
    SheetsSettings settings,
  ) async {
    return await clientViaUserConsent(clientId, _scopes, _openBrowser);
  }

  static Future<void> _openBrowser(String url) async {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', url.replaceAll('&', '^&')]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else {
      await Process.run('xdg-open', [url]);
    }
  }
}
