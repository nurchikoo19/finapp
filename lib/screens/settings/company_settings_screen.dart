import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../db/database.dart';
import '../../providers/database_provider.dart';
import '../../services/sheets_service.dart';
import '../../services/backup_service.dart';
import '../../services/telegram_service.dart';

class CompanySettingsScreen extends ConsumerStatefulWidget {
  final Company company;

  const CompanySettingsScreen({super.key, required this.company});

  @override
  ConsumerState<CompanySettingsScreen> createState() =>
      _CompanySettingsScreenState();
}

class _CompanySettingsScreenState
    extends ConsumerState<CompanySettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _innCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _bankCtrl;
  late String _currency;
  late String? _taxRegime;
  bool _changed = false;

  static const _currencies = [
    ('KGS', 'с', 'Кыргызский сом'),
    ('RUB', '₽', 'Российский рубль'),
    ('USD', '\$', 'Доллар США'),
    ('EUR', '€', 'Евро'),
    ('KZT', '₸', 'Казахстанский тенге'),
    ('UZS', 'сўм', 'Узбекский сум'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.company.name);
    _descCtrl = TextEditingController(text: widget.company.description ?? '');
    _innCtrl = TextEditingController(text: widget.company.inn ?? '');
    _addressCtrl = TextEditingController(text: widget.company.address ?? '');
    _bankCtrl = TextEditingController(text: widget.company.bankDetails ?? '');
    _currency = widget.company.currency;
    _taxRegime = widget.company.taxRegime;
    _nameCtrl.addListener(_onChanged);
    _descCtrl.addListener(_onChanged);
    _innCtrl.addListener(_onChanged);
    _addressCtrl.addListener(_onChanged);
    _bankCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _changed = true);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _innCtrl.dispose();
    _addressCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки компании'),
        actions: [
          if (_changed)
            TextButton(
              onPressed: _save,
              child: const Text(
                'Сохранить',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic info section
          _SectionHeader(title: 'Основная информация'),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Название компании',
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Описание',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Налоговый режим (КР)'),
          const SizedBox(height: 12),
          ...[
            ('osn', 'ОСН', 'НДС 12% + Налог на прибыль 10%'),
            ('usn', 'УСН', 'Единый налог 6% от выручки'),
            ('patent', 'Патент', 'Фиксированный платёж'),
          ].map((t) {
            final (code, label, sub) = t;
            final selected = _taxRegime == code;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                title: Text(label,
                    style: TextStyle(
                        fontWeight: selected ? FontWeight.bold : null)),
                subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
                trailing: selected
                    ? Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => setState(() {
                  _taxRegime = code;
                  _changed = true;
                }),
              ),
            );
          }),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Реквизиты для счетов'),
          const SizedBox(height: 12),
          TextField(
            controller: _innCtrl,
            decoration: const InputDecoration(
              labelText: 'ИНН',
              prefixIcon: Icon(Icons.badge),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Юридический адрес',
              prefixIcon: Icon(Icons.location_on),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bankCtrl,
            decoration: const InputDecoration(
              labelText: 'Банковские реквизиты',
              prefixIcon: Icon(Icons.account_balance),
              hintText: 'Банк, р/с, БИК, кор.счёт...',
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Валюта'),
          const SizedBox(height: 12),

          // Currency picker
          ...(_currencies.map((c) {
            final (code, symbol, name) = c;
            final selected = _currency == code;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    symbol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                title: Text(name),
                subtitle: Text(code),
                trailing: selected
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() {
                    _currency = code;
                    _changed = true;
                  });
                },
              ),
            );
          })),

          if (Platform.isWindows) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: 'Windows'),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shortcut, color: Colors.blue),
                title: const Text('Создать ярлык на рабочем столе'),
                subtitle: const Text(
                  'Добавляет Tabys на рабочий стол',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => _createShortcut(context),
              ),
            ),
          ],

          const SizedBox(height: 24),
          _SectionHeader(title: 'Telegram уведомления'),
          const SizedBox(height: 8),
          _TelegramSection(
            company: widget.company,
            db: ref.read(databaseProvider),
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Google Sheets'),
          const SizedBox(height: 8),
          _GoogleSheetsSection(
            companyId: widget.company.id,
            db: ref.read(databaseProvider),
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Резервная копия'),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup, color: Colors.blue),
                  title: const Text('Создать резервную копию'),
                  subtitle: const Text(
                    'Сохранить все данные в файл .db',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _backup(context),
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.restore, color: Colors.orange),
                  title: const Text('Восстановить из файла'),
                  subtitle: const Text(
                    'Заменить текущие данные из резервной копии',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _restore(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Опасная зона', color: Colors.red),
          const SizedBox(height: 12),

          // Delete company
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Удалить компанию',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Удалит компанию и все связанные данные',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => _confirmDelete(context),
            ),
          ),
        ],
      ),
      floatingActionButton: _changed
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.save),
              label: const Text('Сохранить'),
              onPressed: _save,
            )
          : null,
    );
  }

  Future<void> _backup(BuildContext context) async {
    try {
      final path = await BackupService.backup();
      if (!context.mounted) return;
      if (path == null) return; // cancelled
      if (path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('База данных не найдена'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Резервная копия сохранена:\n$path'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Скопировать путь',
            onPressed: () => Clipboard.setData(ClipboardData(text: path)),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка резервного копирования: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restore(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Восстановить данные?'),
        content: const Text(
          'Все текущие данные будут заменены данными из резервной копии. '
          'После восстановления приложение закроется — откройте его снова.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final success = await BackupService.restore();
      if (!context.mounted) return;
      if (!success) return; // cancelled
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Готово'),
          content: const Text(
            'Данные восстановлены. Закройте и снова откройте приложение.',
          ),
          actions: [
            FilledButton(
              onPressed: () => exit(0),
              child: const Text('Закрыть приложение'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка восстановления: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _createShortcut(BuildContext context) async {
    try {
      final exePath = Platform.resolvedExecutable.replaceAll('/', '\\');
      final desktop =
          Platform.environment['USERPROFILE']?.replaceAll('/', '\\') ??
              'C:\\Users\\Public';
      final linkPath = '$desktop\\Desktop\\Tabys.lnk';

      final script =
          '\$ws = New-Object -ComObject WScript.Shell; '
          '\$s = \$ws.CreateShortcut("$linkPath"); '
          '\$s.TargetPath = "$exePath"; '
          '\$s.IconLocation = "$exePath"; '
          '\$s.Save()';

      final result = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', script],
        runInShell: true,
      );
      if (!context.mounted) return;
      if (result.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ярлык создан на рабочем столе'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка (код ${result.exitCode}): ${result.stderr}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    ref.read(databaseProvider).updateCompany(
          CompaniesCompanion(
            id: Value(widget.company.id),
            name: Value(_nameCtrl.text.trim()),
            description: Value(
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            ),
            currency: Value(_currency),
            taxRegime: Value(_taxRegime),
            inn: Value(_innCtrl.text.trim().isEmpty ? null : _innCtrl.text.trim()),
            address: Value(
                _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim()),
            bankDetails: Value(
                _bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim()),
          ),
        );
    setState(() => _changed = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Настройки сохранены'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить компанию?'),
        content: Text(
          'Компания "${widget.company.name}" и все её данные (счета, '
          'транзакции, задачи, категории) будут удалены безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref
                  .read(databaseProvider)
                  .deleteCompany(widget.company.id);
              if (context.mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // close settings screen
              }
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionHeader({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color ?? Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
    );
  }
}

// ─── Google Sheets Section ────────────────────────────────────────────────────

class _GoogleSheetsSection extends StatefulWidget {
  final int companyId;
  final AppDatabase db;
  const _GoogleSheetsSection({required this.companyId, required this.db});

  @override
  State<_GoogleSheetsSection> createState() => _GoogleSheetsSectionState();
}

class _GoogleSheetsSectionState extends State<_GoogleSheetsSection> {
  late TextEditingController _clientIdCtrl;
  late TextEditingController _clientSecretCtrl;
  late TextEditingController _spreadsheetIdCtrl;
  bool _loading = false;
  bool _initialized = false;
  bool _hasRefreshToken = false;

  @override
  void initState() {
    super.initState();
    _clientIdCtrl = TextEditingController();
    _clientSecretCtrl = TextEditingController();
    _spreadsheetIdCtrl = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await SheetsSettings.load();
    if (!mounted) return;
    setState(() {
      _clientIdCtrl.text = s.clientId;
      _clientSecretCtrl.text = s.clientSecret;
      _spreadsheetIdCtrl.text = s.spreadsheetId;
      _hasRefreshToken = s.refreshToken != null && s.refreshToken!.isNotEmpty;
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    _spreadsheetIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const Center(child: CircularProgressIndicator());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Создайте OAuth 2.0 Desktop credentials в Google Cloud Console '
                'и включите Sheets API. Добавьте http://localhost в Authorized redirect URIs.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clientIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Client ID',
                hintText: 'xxx.apps.googleusercontent.com',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _clientSecretCtrl,
              decoration: const InputDecoration(labelText: 'Client Secret'),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _spreadsheetIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Spreadsheet ID',
                hintText: 'из URL таблицы /d/.../edit',
              ),
            ),
            const SizedBox(height: 12),
            if (_hasRefreshToken)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    const Text('Авторизован', style: TextStyle(color: Colors.green, fontSize: 13)),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        await SheetsSettings.clearAuth();
                        setState(() => _hasRefreshToken = false);
                      },
                      child: const Text('Выйти', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: const Text('Синхронизировать'),
                    onPressed: _loading ? null : _sync,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sync() async {
    final settings = SheetsSettings(
      clientId: _clientIdCtrl.text.trim(),
      clientSecret: _clientSecretCtrl.text.trim(),
      spreadsheetId: _spreadsheetIdCtrl.text.trim(),
    );

    if (!settings.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все поля'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Save credentials before syncing
    await settings.save();

    setState(() => _loading = true);
    try {
      final loaded = await SheetsSettings.load();
      final result = await SheetsService.sync(widget.db, widget.companyId, loaded);
      if (mounted) {
        setState(() => _hasRefreshToken = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Telegram Section ─────────────────────────────────────────────────────────

class _TelegramSection extends StatefulWidget {
  final Company company;
  final AppDatabase db;
  const _TelegramSection({required this.company, required this.db});

  @override
  State<_TelegramSection> createState() => _TelegramSectionState();
}

class _TelegramSectionState extends State<_TelegramSection> {
  final _tokenCtrl = TextEditingController();
  final _chatCtrl = TextEditingController();
  bool _loading = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final token = await TelegramService.getToken();
    final chat = await TelegramService.getChatId();
    if (mounted) {
      _tokenCtrl.text = token ?? '';
      _chatCtrl.text = chat ?? '';
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await TelegramService.saveConfig(_tokenCtrl.text, _chatCtrl.text);
    if (mounted) setState(() => _saved = true);
  }

  Future<void> _sendTest() async {
    setState(() => _loading = true);
    try {
      final token = _tokenCtrl.text.trim();
      final chat = _chatCtrl.text.trim();
      if (token.isEmpty || chat.isEmpty) {
        _showSnack('Заполните токен и Chat ID', isError: true);
        return;
      }
      await TelegramService.saveConfig(token, chat);
      final text = await TelegramService.buildDailyDigest(
        widget.db,
        widget.company.id,
        widget.company.name,
        widget.company.currency,
      );
      final ok = await TelegramService.sendMessage(token, chat, text);
      _showSnack(
        ok ? '✓ Дайджест отправлен в Telegram' : 'Ошибка отправки. Проверьте токен и Chat ID.',
        isError: !ok,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Получайте ежедневный дайджест с балансом, инвойсами и задачами прямо в Telegram.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _showInstructions(context),
              child: const Text(
                'Как настроить? →',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Bot Token',
                hintText: '123456:ABC-DEF...',
                prefixIcon: Icon(Icons.key),
                isDense: true,
              ),
              onChanged: (_) => setState(() => _saved = false),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chatCtrl,
              decoration: const InputDecoration(
                labelText: 'Chat ID',
                hintText: '123456789',
                prefixIcon: Icon(Icons.chat),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => _saved = false),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.save, size: 16),
                  label: Text(_saved ? 'Сохранено ✓' : 'Сохранить'),
                  onPressed: _save,
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 16),
                  label: const Text('Тест дайджест'),
                  onPressed: _loading ? null : _sendTest,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Настройка Telegram бота'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Откройте Telegram и найдите @BotFather'),
              SizedBox(height: 6),
              Text('2. Отправьте /newbot и следуйте инструкциям'),
              SizedBox(height: 6),
              Text('3. Скопируйте полученный токен в поле Bot Token'),
              SizedBox(height: 12),
              Text('Для получения Chat ID:'),
              SizedBox(height: 6),
              Text('4. Найдите @userinfobot в Telegram'),
              SizedBox(height: 6),
              Text('5. Отправьте ему /start — он покажет ваш Chat ID'),
              SizedBox(height: 6),
              Text('6. Вставьте Chat ID в соответствующее поле'),
              SizedBox(height: 12),
              Text(
                'После настройки нажмите "Тест дайджест" для проверки.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}
