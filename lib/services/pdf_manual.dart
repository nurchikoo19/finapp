import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class PdfManualService {
  // ── Цвета ──────────────────────────────────────────────────────────────────
  static const _primary = PdfColor.fromInt(0xFF1565C0);
  static const _accent = PdfColor.fromInt(0xFF0288D1);
  static const _green = PdfColor.fromInt(0xFF2E7D32);
  static const _orange = PdfColor.fromInt(0xFFE65100);
  static const _bg = PdfColor.fromInt(0xFFF5F5F5);
  static const _divider = PdfColor.fromInt(0xFFBDBDBD);
  static const _textGrey = PdfColor.fromInt(0xFF757575);

  static Future<File> generateAndSave() async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(
        base: font, bold: fontBold, italic: fontItalic);

    // ── Вспомогательные стили ───────────────────────────────────────────────
    pw.TextStyle h1(pw.Font b) => pw.TextStyle(
        font: b, fontSize: 18, color: _primary, fontWeight: pw.FontWeight.bold);
    pw.TextStyle h2(pw.Font b) => pw.TextStyle(
        font: b, fontSize: 14, color: _primary, fontWeight: pw.FontWeight.bold);
    pw.TextStyle h3(pw.Font b) => pw.TextStyle(
        font: b, fontSize: 12, color: _accent, fontWeight: pw.FontWeight.bold);
    pw.TextStyle body(pw.Font f) =>
        pw.TextStyle(font: f, fontSize: 10, lineSpacing: 2);
    pw.TextStyle small(pw.Font f) =>
        pw.TextStyle(font: f, fontSize: 9, color: _textGrey);
    pw.TextStyle code(pw.Font f) => pw.TextStyle(
        font: f, fontSize: 9, background: const pw.BoxDecoration(color: _bg));

    // ── Хелперы ────────────────────────────────────────────────────────────
    pw.Widget divider() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Divider(color: _divider, thickness: 0.5),
        );

    pw.Widget sectionHeader(String text, pw.Font b) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: const pw.BoxDecoration(
            color: _primary,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(text,
              style: pw.TextStyle(
                  font: b,
                  fontSize: 13,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold)),
        );

    pw.Widget subHeader(String text, pw.Font b) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(text, style: h2(b)),
        );

    pw.Widget subSubHeader(String text, pw.Font b) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 3),
          child: pw.Text(text, style: h3(b)),
        );

    pw.Widget para(String text, pw.Font f) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(text, style: body(f)),
        );

    pw.Widget bullet(String text, pw.Font f) => pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: body(f)),
              pw.Expanded(child: pw.Text(text, style: body(f))),
            ],
          ),
        );

    pw.Widget numberedItem(int n, String text, pw.Font f, pw.Font b) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$n.  ', style: pw.TextStyle(font: b, fontSize: 10)),
              pw.Expanded(child: pw.Text(text, style: body(f))),
            ],
          ),
        );

    pw.Widget noteBox(String text, pw.Font f, pw.Font b,
            {PdfColor color = _bg}) =>
        pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: _divider),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ℹ  ', style: pw.TextStyle(font: b, fontSize: 10)),
              pw.Expanded(child: pw.Text(text, style: body(f))),
            ],
          ),
        );

    pw.Widget warningBox(String text, pw.Font f, pw.Font b) => pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFFF8E1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFFFB300)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('⚠  ', style: pw.TextStyle(font: b, fontSize: 10)),
              pw.Expanded(child: pw.Text(text, style: body(f))),
            ],
          ),
        );

    pw.Widget screenCard(String title, String desc, pw.Font f, pw.Font b) =>
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _divider),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title,
                  style: pw.TextStyle(
                      font: b,
                      fontSize: 10,
                      color: _primary)),
              pw.SizedBox(height: 3),
              pw.Text(desc, style: small(f)),
            ],
          ),
        );

    // ──────────────────────────────────────────────────────────────────────────
    // СТРАНИЦА 1 — ОБЛОЖКА
    // ──────────────────────────────────────────────────────────────────────────
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (ctx) => pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(40),
              decoration: const pw.BoxDecoration(color: _primary),
              child: pw.Column(
                children: [
                  pw.Text('FinApp',
                      style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 48,
                          color: PdfColors.white)),
                  pw.SizedBox(height: 8),
                  pw.Text('Финансовое приложение для бизнеса',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 16,
                          color: PdfColors.grey300)),
                ],
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Text('РУКОВОДСТВО ПОЛЬЗОВАТЕЛЯ',
                style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 22,
                    color: _primary,
                    letterSpacing: 2)),
            pw.SizedBox(height: 16),
            pw.Container(
              width: 200,
              height: 1,
              color: _divider,
            ),
            pw.SizedBox(height: 16),
            pw.Text('Desktop (Windows) · Android · Мультипользователь',
                style: pw.TextStyle(
                    font: font, fontSize: 13, color: _textGrey)),
            pw.SizedBox(height: 60),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                _coverChip('13 экранов', fontBold, font),
                pw.SizedBox(width: 12),
                _coverChip('Telegram уведомления', fontBold, font),
                pw.SizedBox(width: 12),
                _coverChip('PDF отчёты', fontBold, font),
              ],
            ),
            pw.Spacer(),
            pw.Text('Версия 1.0  ·  2025',
                style: pw.TextStyle(font: font, fontSize: 9, color: _textGrey)),
          ],
        ),
      ),
    );

    // ──────────────────────────────────────────────────────────────────────────
    // СТРАНИЦЫ ОСНОВНОГО КОНТЕНТА — MultiPage
    // ──────────────────────────────────────────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 50),
        theme: theme,
        header: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: _divider, width: 0.5))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('FinApp — Руководство пользователя',
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 9, color: _primary)),
              pw.Text('Стр. ${ctx.pageNumber}',
                  style: pw.TextStyle(
                      font: font, fontSize: 9, color: _textGrey)),
            ],
          ),
        ),
        build: (ctx) => [
          // ══════════════════════════════════════════════════════════════════
          // 1. СОДЕРЖАНИЕ
          // ══════════════════════════════════════════════════════════════════
          sectionHeader('СОДЕРЖАНИЕ', fontBold),
          pw.SizedBox(height: 10),
          ...[
            ('1.', 'Введение и возможности приложения'),
            ('2.', 'Первый запуск — создание компании'),
            ('3.', 'Навигация (Боковое меню)'),
            ('4.', 'Инструкция для Desktop (Windows)'),
            ('   4.1', 'Дашборд'),
            ('   4.2', 'Счета'),
            ('   4.3', 'Транзакции'),
            ('   4.4', 'Инвойсы и сделки'),
            ('   4.5', 'Задачи'),
            ('   4.6', 'Сотрудники'),
            ('   4.7', 'Категории'),
            ('   4.8', 'Склад'),
            ('   4.9', 'Договоры'),
            ('   4.10', 'Зарплата'),
            ('   4.11', 'Отчёты'),
            ('   4.12', 'Настройки'),
            ('5.', 'Инструкция для Android'),
            ('6.', 'Работа с несколькими сотрудниками'),
            ('7.', 'Настройка Telegram-уведомлений'),
            ('8.', 'Резервное копирование данных'),
          ].map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                        width: 30,
                        child: pw.Text(item.$1, style: small(fontBold))),
                    pw.Text(item.$2, style: small(font)),
                  ],
                ),
              )),

          divider(),

          // ══════════════════════════════════════════════════════════════════
          // 1. ВВЕДЕНИЕ
          // ══════════════════════════════════════════════════════════════════
          sectionHeader('1. ВВЕДЕНИЕ И ВОЗМОЖНОСТИ', fontBold),
          pw.SizedBox(height: 8),
          para(
            'FinApp — это финансовое приложение для малого и среднего бизнеса. '
            'Оно позволяет вести учёт транзакций, выставлять счета клиентам, '
            'управлять сотрудниками, отслеживать договоры и получать подробную аналитику.',
            font,
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Финансы', style: h3(fontBold)),
                    pw.SizedBox(height: 4),
                    bullet('Учёт доходов и расходов', font),
                    bullet('Управление банковскими счетами', font),
                    bullet('Бюджеты по категориям', font),
                    bullet('Повторяющиеся транзакции', font),
                    bullet('Денежный поток (cash flow)', font),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Бизнес', style: h3(fontBold)),
                    pw.SizedBox(height: 4),
                    bullet('Выставление инвойсов (PDF)', font),
                    bullet('Договоры с клиентами', font),
                    bullet('Управление складом', font),
                    bullet('Расчёт зарплаты', font),
                    bullet('Менеджеры и комиссии', font),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Аналитика', style: h3(fontBold)),
                    pw.SizedBox(height: 4),
                    bullet('P&L, EBITDA, бюджеты', font),
                    bullet('Сравнение периодов', font),
                    bullet('Топ клиентов и расходов', font),
                    bullet('Прогноз и точка безубыточности', font),
                    bullet('Telegram-дайджест', font),
                  ],
                ),
              ),
            ],
          ),
          divider(),

          // ══════════════════════════════════════════════════════════════════
          // 2. ПЕРВЫЙ ЗАПУСК
          // ══════════════════════════════════════════════════════════════════
          sectionHeader('2. ПЕРВЫЙ ЗАПУСК — СОЗДАНИЕ КОМПАНИИ', fontBold),
          pw.SizedBox(height: 8),
          para(
              'При первом запуске приложение откроет экран приветствия. '
              'Необходимо создать хотя бы одну компанию для начала работы.',
              font),
          pw.SizedBox(height: 6),
          numberedItem(1,
              'Нажмите кнопку "Создать компанию" на экране приветствия.', font, fontBold),
          numberedItem(2,
              'Введите название компании (обязательно). Остальные поля можно заполнить позже.', font, fontBold),
          numberedItem(3,
              'Выберите валюту по умолчанию (KGS, RUB, USD, EUR и др.).', font, fontBold),
          numberedItem(4,
              'Нажмите "Создать". Приложение автоматически создаст базовые категории и счёт.', font, fontBold),
          pw.SizedBox(height: 6),
          noteBox(
            'Вы можете создать несколько компаний и переключаться между ними '
            'через боковое меню. Каждая компания имеет собственные данные.',
            font, fontBold,
          ),
          divider(),

          // ══════════════════════════════════════════════════════════════════
          // 3. НАВИГАЦИЯ
          // ══════════════════════════════════════════════════════════════════
          sectionHeader('3. НАВИГАЦИЯ — БОКОВОЕ МЕНЮ', fontBold),
          pw.SizedBox(height: 8),
          para(
              'Все разделы приложения доступны через боковое меню (Drawer). '
              'На Desktop откройте его кнопкой ☰ в верхнем левом углу. '
              'На Android проведите пальцем от левого края экрана.',
              font),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    screenCard('🏠  Дашборд',
                        'Сводка по бизнесу, графики, задачи', font, fontBold),
                    screenCard('🏦  Счета',
                        'Банковские счета и их баланс', font, fontBold),
                    screenCard('💸  Транзакции',
                        'Доходы, расходы, переводы', font, fontBold),
                    screenCard('📋  Задачи',
                        'Задачи с приоритетами и дедлайнами', font, fontBold),
                    screenCard('👥  Сотрудники',
                        'Список сотрудников, статистика', font, fontBold),
                    screenCard('🏷️  Категории',
                        'Категории доходов и расходов', font, fontBold),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    screenCard('🧾  Инвойсы',
                        'Счета клиентам, PDF, история оплат', font, fontBold),
                    screenCard('📦  Склад',
                        'Товары, движения, остатки', font, fontBold),
                    screenCard('📄  Договоры',
                        'Договоры с клиентами и поставщиками', font, fontBold),
                    screenCard('💰  Зарплата',
                        'Начисление и история выплат', font, fontBold),
                    screenCard('📊  Отчёты',
                        'P&L, EBITDA, бюджеты, прогноз', font, fontBold),
                    screenCard('⚙️  Настройки',
                        'Данные компании, Telegram, бэкап', font, fontBold),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          para(
              'В верхней части бокового меню отображается название текущей компании. '
              'Нажмите на него, чтобы увидеть список компаний и переключиться.',
              font),
          divider(),

          // ══════════════════════════════════════════════════════════════════
          // 4. DESKTOP
          // ══════════════════════════════════════════════════════════════════
          sectionHeader('4. ИНСТРУКЦИЯ ДЛЯ DESKTOP (WINDOWS)', fontBold),
          pw.SizedBox(height: 6),
          para('Приложение устанавливается как обычная Windows-программа. '
              'Файл finapp.exe можно создать ярлык на рабочем столе через Настройки → Windows.',
              font),

          // 4.1 Дашборд
          subHeader('4.1  Дашборд', fontBold),
          para(
              'Дашборд — главный экран приложения. Показывает сводку по текущему состоянию бизнеса.',
              font),
          bullet('Три карточки вверху: Общий баланс, Доходы месяца, Расходы месяца.', font),
          bullet('Карточка "Денежный поток" — чистый результат (доходы − расходы).', font),
          bullet('Карточка "Сравнение с прошлым месяцем" — показывает % изменения.', font),
          bullet('Карточки "Превышение бюджета" — красные алерты если расходы вышли за бюджет.', font),
          bullet('График доходов и расходов за 6 месяцев (зелёная и красная линии).', font),
          bullet('"Ближайшие задачи" — топ-5 незакрытых задач.', font),
          bullet('"Топ расходов месяца" — 3 самые большие категории трат с прогресс-барами.', font),
          bullet('"Топ клиентов" — 3 клиента с наибольшей суммой инвойсов.', font),
          bullet('"Истекающие договоры" — договоры с окончанием в течение 30 дней.', font),
          bullet('"Просроченные инвойсы" — количество не оплаченных в срок счетов.', font),

          // 4.2 Счета
          subHeader('4.2  Счета', fontBold),
          para(
              'Управление банковскими счетами и кассой компании. Баланс обновляется автоматически при каждой транзакции.',
              font),
          bullet('Нажмите "Новый счёт" для создания: укажите название, тип (банк/касса/карта), начальный баланс.', font),
          bullet('Карточка счёта показывает текущий баланс и тип счёта.', font),
          bullet('Для удаления счёта — нажмите иконку корзины, подтвердите удаление.', font),
          warningBox('Нельзя удалить счёт, если к нему привязаны транзакции. '
              'Сначала удалите или перенесите транзакции.', font, fontBold),

          // 4.3 Транзакции
          subHeader('4.3  Транзакции', fontBold),
          para(
              'Основной экран для учёта движения денег. Показывает транзакции за выбранный период.',
              font),
          bullet('Используйте кнопку "Изменить" для смены периода (по умолчанию текущий месяц).', font),
          bullet('Строка поиска ищет по описанию, категории и счёту.', font),
          bullet('Фильтр по категории — выпадающий список справа от поиска.', font),
          bullet('Нажмите на транзакцию для редактирования.', font),
          bullet('Кнопка ⬇ (скрепка) — экспорт в CSV-файл для Excel.', font),
          pw.SizedBox(height: 4),
          pw.Text('Создание транзакции:', style: h3(fontBold)),
          pw.SizedBox(height: 3),
          numberedItem(1, 'Нажмите "+ Новая транзакция".', font, fontBold),
          numberedItem(2, 'Выберите тип: Доход / Расход / Перевод.', font, fontBold),
          numberedItem(3, 'Введите сумму и выберите счёт.', font, fontBold),
          numberedItem(4, 'Укажите категорию, дату и описание (необязательно).', font, fontBold),
          numberedItem(5, 'Для повторяющихся платежей включите "Повторять" и выберите интервал.', font, fontBold),
          numberedItem(6, 'Нажмите "Сохранить".', font, fontBold),

          // 4.4 Инвойсы
          subHeader('4.4  Инвойсы и сделки', fontBold),
          para('Создание и отслеживание счетов для клиентов. Поддерживает PDF-выгрузку с реквизитами.',
              font),
          bullet('Строка поиска — ищет по клиенту, номеру счёта, описанию.', font),
          bullet('Фильтр-chips вверху: Все / Ожидает / Частично / Оплачен / Просроченные / Отменён.', font),
          bullet('Нажмите на инвойс для просмотра деталей и истории оплат.', font),
          pw.SizedBox(height: 4),
          pw.Text('Создание инвойса:', style: h3(fontBold)),
          pw.SizedBox(height: 3),
          numberedItem(1, 'Нажмите "+ Новый счёт".', font, fontBold),
          numberedItem(2, 'Введите имя клиента, описание, сумму, срок оплаты.', font, fontBold),
          numberedItem(3, 'Добавьте позиции счёта (товары/услуги с ценой и НДС).', font, fontBold),
          numberedItem(4, 'Укажите менеджера по продаже и его % комиссии (необязательно).', font, fontBold),
          numberedItem(5, 'Нажмите "Сохранить".', font, fontBold),
          pw.SizedBox(height: 4),
          pw.Text('Работа с оплатой:', style: h3(fontBold)),
          pw.SizedBox(height: 3),
          bullet('"Внести оплату" — записывает частичный или полный платёж в историю.', font),
          bullet('"→ Транзакция" — создаёт доходную транзакцию на счёт и автоматически ставит статус "Оплачен".', font),
          bullet('"Печать PDF" — генерирует счёт-фактуру с реквизитами компании и клиента.', font),

          // 4.5 Задачи
          subHeader('4.5  Задачи', fontBold),
          para('Управление рабочими задачами с приоритетами, дедлайнами и назначением исполнителей.', font),
          bullet('Строка поиска — ищет по названию и описанию задачи.', font),
          bullet('Фильтр по статусу: Новые / В работе / Выполненные / Отменённые.', font),
          bullet('Нажмите на задачу для редактирования или изменения статуса.', font),
          bullet('Приоритеты: Низкий (серый) / Средний (синий) / Высокий (красный).', font),
          bullet('Назначьте задачу сотруднику из выпадающего списка.', font),

          // 4.6 Сотрудники
          subHeader('4.6  Сотрудники', fontBold),
          para('Список сотрудников компании со статистикой продаж.', font),
          bullet('Карточка сотрудника показывает должность, контакты, дату найма.', font),
          bullet('Секция "Статистика менеджера" — количество инвойсов, общая сумма, заработанная комиссия.', font),
          bullet('Сортировка: по имени, должности, дате найма.', font),
          bullet('Для удаления нажмите ⋮ → Удалить (требует подтверждения).', font),

          // 4.7 Категории
          subHeader('4.7  Категории', fontBold),
          para('Управление категориями доходов и расходов. Используются при создании транзакций.', font),
          bullet('Два таба: "Доходы" и "Расходы".', font),
          bullet('Нажмите "+ Добавить" для новой категории.', font),
          bullet('Длинное нажатие на категорию — редактирование или удаление.', font),
          bullet('Для категорий можно задать бюджет через экран Отчёты → таб "Бюджеты".', font),

          // 4.8 Склад
          subHeader('4.8  Склад', fontBold),
          para('Учёт товаров и движений на складе.', font),
          bullet('Список товаров с текущим остатком и ценой.', font),
          bullet('Добавьте новый товар кнопкой "+ Товар": название, единица, цена, количество.', font),
          bullet('"Движение" — записать приход (+) или расход (−) товара.', font),
          bullet('История движений доступна по нажатию на товар.', font),
          bullet('Сортировка: по названию, остатку, цене.', font),

          // 4.9 Договоры
          subHeader('4.9  Договоры', fontBold),
          para('Хранение договоров с клиентами и поставщиками.', font),
          bullet('Строка поиска — ищет по контрагенту, номеру, заметкам.', font),
          bullet('Фильтры: Все / Клиент / Поставщик / Активные / Истекающие.', font),
          bullet('Сортировка: по дате, контрагенту, сумме.', font),
          bullet('Договоры с истечением срока в 30 дней автоматически появляются на Дашборде.', font),
          bullet('Статусы: Активный / Завершён / Отменён / Истёк.', font),

          // 4.10 Зарплата
          subHeader('4.10  Зарплата', fontBold),
          para('Начисление и история зарплатных выплат по сотрудникам.', font),
          bullet('Список записей с фильтрацией по сотруднику и периоду.', font),
          bullet('Нажмите "+ Начисление": выберите сотрудника, период, сумму.', font),
          bullet('Статусы: Запланирована / Выплачена.', font),
          bullet('Нажмите на запись для изменения статуса или удаления.', font),

          // 4.11 Отчёты
          subHeader('4.11  Отчёты', fontBold),
          para('Шесть аналитических вкладок для углублённого анализа бизнеса.', font),
          bullet('П&Л (P&L) — доходы и расходы по категориям за период. Кнопка 🖨 — экспорт в PDF.', font),
          bullet('EBITDA — прибыль до вычета постоянных затрат.', font),
          bullet('Безубыточность — при какой выручке бизнес выходит в ноль.', font),
          bullet('Бюджеты — установите лимит расходов по каждой категории. Превышения видны на Дашборде.', font),
          bullet('Прогноз — ожидаемые доходы и расходы на основе истории.', font),
          bullet('Налоги — расчёт налоговой нагрузки согласно выбранному режиму (ОСН/УСН/Патент).', font),

          // 4.12 Настройки
          subHeader('4.12  Настройки', fontBold),
          para('Настройки компании, интеграции и резервное копирование.', font),
          bullet('Основная информация: название, описание, ИНН, адрес.', font),
          bullet('Налоговый режим: ОСН, УСН 6%, Патент.', font),
          bullet('Реквизиты для PDF-счетов: ИНН, адрес, банковские реквизиты.', font),
          bullet('Валюта: выбор из 6 валют (KGS, RUB, USD, EUR, KZT, UZS).', font),
          bullet('Telegram уведомления: настройка бота для ежедневного дайджеста.', font),
          bullet('Резервная копия: создать .db файл / восстановить из файла.', font),
          bullet('Windows: создать ярлык на рабочем столе.', font),
          divider(),

          // ══════════════════════════════════════════════════════════════════
          // 5. ANDROID
          // ══════════════════════════════════════════════════════════════════
          sectionHeader('5. ИНСТРУКЦИЯ ДЛЯ ANDROID', fontBold),
          pw.SizedBox(height: 8),
          noteBox(
            'Android-версия использует тот же код и интерфейс что и Desktop-версия. '
            'Все функции доступны в полном объёме. Отличие только в способе навигации.',
            font, fontBold,
          ),

          subHeader('5.1  Установка APK', fontBold),
          numberedItem(1,
              'Скачайте файл finapp.apk с официального источника.', font, fontBold),
          numberedItem(2,
              'На Android откройте Настройки → Безопасность → включите "Установка из неизвестных источников".', font, fontBold),
          numberedItem(3,
              'Откройте APK-файл через файловый менеджер и нажмите "Установить".', font, fontBold),
          numberedItem(4,
              'После установки найдите FinApp в списке приложений и запустите.', font, fontBold),
          pw.SizedBox(height: 4),
          warningBox(
            'На некоторых устройствах Samsung/Xiaomi может потребоваться дополнительно '
            'разрешить установку в настройках конкретного браузера или файлового менеджера.',
            font, fontBold,
          ),

          subHeader('5.2  Навигация на Android', fontBold),
          bullet('Боковое меню: проведите пальцем от левого края экрана вправо.', font),
          bullet('Альтернативно: нажмите кнопку ☰ в верхнем левом углу.', font),
          bullet('Кнопка "Назад" на устройстве закрывает текущий диалог или возвращает на предыдущий экран.', font),
          bullet('Для прокрутки списков проводите пальцем вверх/вниз.', font),
          bullet('Нажмите и удерживайте элемент для дополнительных действий (где доступно).', font),

          subHeader('5.3  Ввод данных на Android', fontBold),
          bullet('При нажатии на текстовое поле автоматически открывается клавиатура.', font),
          bullet('Числовые поля (суммы) открывают цифровую клавиатуру.', font),
          bullet('Выбор даты — нажмите на поле даты и выберите в календаре.', font),
          bullet('Выпадающие списки — нажмите для открытия, выберите вариант.', font),
          bullet('Закрыть клавиатуру — нажмите кнопку "Готово" или проведите вниз.', font),

          subHeader('5.4  Особенности мобильной версии', fontBold),
          bullet('На узких экранах карточки дашборда располагаются в 2 колонки вместо 3.', font),
          bullet('PDF-файлы сохраняются в папку "Документы" на устройстве.', font),
          bullet('CSV-файлы сохраняются в "Документы" и открываются через Google Таблицы или Excel Mobile.', font),
          bullet('Резервная копия создаётся в "Документы/FinApp_backup_[дата].db".', font),
          bullet('База данных хранится локально на устройстве — данные не уходят в интернет.', font),
          divider(),

          // ══════════════════════════════════════════════════════════════════
          // 6. НЕСКОЛЬКО СОТРУДНИКОВ
          // ══════════════════════════════════════════════════════════════════
          sectionHeader('6. РАБОТА С НЕСКОЛЬКИМИ СОТРУДНИКАМИ', fontBold),
          pw.SizedBox(height: 8),
          para(
            'FinApp позволяет добавить любое количество сотрудников и распределять между ними задачи, '
            'инвойсы и зарплатные записи. Это не многопользовательская система (каждый работает '
            'на своём устройстве), но позволяет вести полный учёт по команде.',
            font,
          ),

          subHeader('6.1  Добавление сотрудников', fontBold),
          numberedItem(1, 'Перейдите в раздел "Сотрудники" через боковое меню.', font, fontBold),
          numberedItem(2, 'Нажмите "+ Добавить сотрудника" (кнопка внизу справа).', font, fontBold),
          numberedItem(3,
              'Заполните данные: ФИО (обязательно), должность, контактный телефон, email, '
              'дату найма, оклад.',
              font, fontBold),
          numberedItem(4, 'Нажмите "Сохранить".', font, fontBold),
          pw.SizedBox(height: 6),
          noteBox(
            'Рекомендуется добавить всех сотрудников до начала работы с задачами и инвойсами, '
            'чтобы сразу можно было назначать ответственных.',
            font, fontBold,
          ),

          subHeader('6.2  Назначение сотрудника на задачу', fontBold),
          para('При создании или редактировании задачи можно назначить исполнителя:', font),
          numberedItem(1, 'Откройте раздел "Задачи".', font, fontBold),
          numberedItem(2,
              'Нажмите "+ Новая задача" или нажмите на существующую задачу для редактирования.', font, fontBold),
          numberedItem(3,
              'В поле "Исполнитель" выберите сотрудника из выпадающего списка.', font, fontBold),
          numberedItem(4, 'Установите приоритет (низкий/средний/высокий) и дедлайн.', font, fontBold),
          numberedItem(5, 'Нажмите "Сохранить".', font, fontBold),
          pw.SizedBox(height: 4),
          para('Для просмотра задач конкретного сотрудника используйте фильтр по исполнителю в строке фильтров.', font),

          subHeader('6.3  Менеджер по продажам и комиссии', fontBold),
          para(
            'При создании инвойса можно указать менеджера, который ведёт сделку, '
            'и автоматически рассчитать его комиссионное вознаграждение.',
            font,
          ),
          numberedItem(1, 'Откройте раздел "Инвойсы" → "Новый счёт".', font, fontBold),
          numberedItem(2,
              'Прокрутите вниз до секции "Менеджер по продаже".', font, fontBold),
          numberedItem(3, 'Выберите сотрудника из выпадающего списка.', font, fontBold),
          numberedItem(4,
              'Укажите процент комиссии (например, 5%). Сумма комиссии рассчитается автоматически.', font, fontBold),
          numberedItem(5, 'Сохраните инвойс.', font, fontBold),
          pw.SizedBox(height: 4),
          noteBox(
            'Сумма комиссии отображается в деталях инвойса и в карточке сотрудника в разделе '
            '"Статистика менеджера" (количество сделок, общая сумма, итого комиссия).',
            font, fontBold,
          ),

          subHeader('6.4  Просмотр статистики по сотруднику', fontBold),
          para('Для каждого сотрудника доступна сводная статистика продаж:', font),
          numberedItem(1, 'Перейдите в раздел "Сотрудники".', font, fontBold),
          numberedItem(2, 'Нажмите на карточку сотрудника.', font, fontBold),
          numberedItem(3,
              'В открывшейся карточке найдите секцию "Статистика менеджера" внизу.', font, fontBold),
          bullet('Количество выставленных инвойсов.', font),
          bullet('Общая сумма сделок.', font),
          bullet('Итоговая сумма комиссионных вознаграждений.', font),

          subHeader('6.5  Начисление и учёт зарплаты', fontBold),
          numberedItem(1, 'Перейдите в раздел "Зарплата".', font, fontBold),
          numberedItem(2, 'Нажмите "+ Начисление".', font, fontBold),
          numberedItem(3,
              'Выберите сотрудника, укажите период (месяц/год), сумму и описание.', font, fontBold),
          numberedItem(4, 'Установите статус: "Запланирована" или "Выплачена".', font, fontBold),
          numberedItem(5,
              'Для отметки о выплате — нажмите на запись и измените статус на "Выплачена".', font, fontBold),
          pw.SizedBox(height: 4),
          para(
            'Для фильтрации зарплатных записей по конкретному сотруднику '
            'используйте выпадающий список в верхней части экрана.',
            font,
          ),

          subHeader('6.6  Совместная работа через несколько устройств', fontBold),
          para(
            'В текущей версии каждое устройство хранит данные локально. '
            'Для работы команды с общей базой данных есть два варианта:',
            font,
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _primary),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Вариант A — Ручная синхронизация (доступно сейчас):',
                    style: pw.TextStyle(font: fontBold, fontSize: 10, color: _primary)),
                pw.SizedBox(height: 4),
                bullet('Один сотрудник ведёт основную базу (обычно руководитель).', font),
                bullet('Регулярно создавайте резервную копию (Настройки → Резервная копия → Создать).', font),
                bullet('Передайте .db файл коллеге и восстановите на его устройстве.', font),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _green),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Вариант B — Облачная синхронизация (в разработке):',
                    style: pw.TextStyle(font: fontBold, fontSize: 10, color: _green)),
                pw.SizedBox(height: 4),
                bullet('Данные автоматически синхронизируются между всеми устройствами в реальном времени.', font),
                bullet('Работает на Desktop, Android, iOS одновременно.', font),
                bullet('Изменения одного сотрудника мгновенно видны другим.', font),
                bullet('Будет добавлено в следующей версии приложения.', font),
              ],
            ),
          ),
          divider(),

          // ══════════════════════════════════════════════════════════════════
          // 7. TELEGRAM
          // ══════════════════════════════════════════════════════════════════
          sectionHeader('7. НАСТРОЙКА TELEGRAM-УВЕДОМЛЕНИЙ', fontBold),
          pw.SizedBox(height: 8),
          para(
            'Telegram-бот отправляет ежедневный дайджест с балансом, '
            'денежным потоком, просроченными инвойсами и задачами на сегодня.',
            font,
          ),

          subHeader('7.1  Создание Telegram-бота', fontBold),
          numberedItem(1, 'Откройте Telegram и найдите бота @BotFather (официальный бот Telegram).', font, fontBold),
          numberedItem(2, 'Напишите команду /newbot', font, fontBold),
          numberedItem(3, 'BotFather спросит имя бота — введите любое (например, "Мой FinApp бот").', font, fontBold),
          numberedItem(4, 'Затем спросит username — введите уникальное имя, заканчивающееся на "bot" (например, myfinapp_bot).', font, fontBold),
          numberedItem(5,
              'BotFather выдаст токен вида: 1234567890:ABCdefGHIjklMNOpqrsTUVwxyz. Скопируйте его.', font, fontBold),

          subHeader('7.2  Получение Chat ID', fontBold),
          numberedItem(1, 'Найдите бота @userinfobot в Telegram.', font, fontBold),
          numberedItem(2, 'Напишите ему /start.', font, fontBold),
          numberedItem(3, 'Бот ответит с вашим ID (числовой, например: 123456789). Скопируйте его.', font, fontBold),
          pw.SizedBox(height: 4),
          noteBox(
            'Для получения уведомлений в группу или канал: добавьте бота в группу/канал '
            'как администратора, а Chat ID будет отрицательным числом (например, -100123456789). '
            'Его можно получить через @getmyid_bot.',
            font, fontBold,
          ),

          subHeader('7.3  Настройка в FinApp', fontBold),
          numberedItem(1, 'Откройте боковое меню → Настройки (⚙️).', font, fontBold),
          numberedItem(2, 'Найдите секцию "Telegram уведомления".', font, fontBold),
          numberedItem(3, 'Вставьте Bot Token в поле "Bot Token".', font, fontBold),
          numberedItem(4, 'Вставьте Chat ID в поле "Chat ID".', font, fontBold),
          numberedItem(5, 'Нажмите "Сохранить".', font, fontBold),
          numberedItem(6, 'Нажмите "Тест дайджест" — должно прийти сообщение в Telegram.', font, fontBold),

          subHeader('7.4  Пример сообщения дайджеста', fontBold),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFE3F2FD),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('📊 FinApp — Моя компания',
                    style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.Text('12.05.2025', style: small(font)),
                pw.SizedBox(height: 6),
                pw.Text('💰 Общий баланс: 1,250,000 с',
                    style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Text('📅 Май 2025:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.Text('  ↑ Доходы: 450,000 с', style: small(font)),
                pw.Text('  ↓ Расходы: 280,000 с', style: small(font)),
                pw.Text('  = Поток: +170,000 с', style: small(font)),
                pw.SizedBox(height: 4),
                pw.Text('🧾 Ожидает оплаты: 320,000 с',
                    style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.Text('⚠️ Просроченных инвойсов: 2',
                    style: pw.TextStyle(font: fontBold, fontSize: 10, color: _orange)),
                pw.SizedBox(height: 4),
                pw.Text('📋 Задачи на сегодня (3):', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.Text('  • Позвонить клиенту Иванову', style: small(font)),
                pw.Text('  • Подписать договор №15', style: small(font)),
                pw.Text('  • Отправить счёт в бухгалтерию', style: small(font)),
              ],
            ),
          ),
          divider(),

          // ══════════════════════════════════════════════════════════════════
          // 8. РЕЗЕРВНОЕ КОПИРОВАНИЕ
          // ══════════════════════════════════════════════════════════════════
          sectionHeader('8. РЕЗЕРВНОЕ КОПИРОВАНИЕ ДАННЫХ', fontBold),
          pw.SizedBox(height: 8),
          para('Регулярное создание резервных копий защитит ваши данные от потери.', font),

          subHeader('8.1  Создание резервной копии', fontBold),
          numberedItem(1, 'Откройте Настройки → секция "Резервная копия".', font, fontBold),
          numberedItem(2, 'Нажмите "Создать резервную копию".', font, fontBold),
          numberedItem(3,
              'Файл FinApp_backup_[дата].db сохранится в папку "Документы".', font, fontBold),
          numberedItem(4, 'Скопируйте файл в облако (Google Drive, OneDrive) для надёжности.', font, fontBold),

          subHeader('8.2  Восстановление из резервной копии', fontBold),
          numberedItem(1, 'Откройте Настройки → "Восстановить из файла".', font, fontBold),
          numberedItem(2, 'В диалоге файла выберите .db файл резервной копии.', font, fontBold),
          numberedItem(3, 'Подтвердите восстановление. Текущие данные будут заменены.', font, fontBold),
          numberedItem(4, 'Приложение перезапустится с восстановленными данными.', font, fontBold),
          warningBox(
            'Восстановление из резервной копии ПОЛНОСТЬЮ заменяет текущие данные. '
            'Перед восстановлением создайте резервную копию текущего состояния, '
            'если хотите сохранить последние изменения.',
            font, fontBold,
          ),

          subHeader('8.3  Рекомендации', fontBold),
          bullet('Создавайте резервную копию еженедельно или после важных изменений.', font),
          bullet('Храните несколько версий копий с разными датами.', font),
          bullet('На Android регулярно синхронизируйте папку "Документы" с облаком.', font),
          bullet('Перед обновлением приложения обязательно создайте резервную копию.', font),
          divider(),

          // ── FOOTER ───────────────────────────────────────────────────────
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _bg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              children: [
                pw.Text('FinApp — Финансовое приложение для бизнеса',
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 11, color: _primary)),
                pw.SizedBox(height: 4),
                pw.Text(
                    'По вопросам и предложениям обращайтесь к разработчику. '
                    'Актуальная версия документации доступна в приложении.',
                    style: small(font),
                    textAlign: pw.TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );

    // ── Сохранение ────────────────────────────────────────────────────────────
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/FinApp_Manual.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  static pw.Widget _coverChip(String text, pw.Font bold, pw.Font regular) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _primary),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(font: bold, fontSize: 10, color: _primary)),
    );
  }

  /// Открыть диалог печати вместо сохранения файла.
  static Future<void> printManual() async {
    final font = await PdfGoogleFonts.robotoRegular();
    final file = await generateAndSave();
    await Printing.layoutPdf(
      onLayout: (_) async => file.readAsBytes(),
      name: 'FinApp_Manual',
    );
  }
}
