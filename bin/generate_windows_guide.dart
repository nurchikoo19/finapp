// ignore_for_file: avoid_print
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Run: dart run bin/generate_windows_guide.dart

const _blue = PdfColor.fromInt(0xFF1565C0);
const _blueDark = PdfColor.fromInt(0xFF0D47A1);
const _blueLight = PdfColor.fromInt(0xFFE3F2FD);
const _grey = PdfColor.fromInt(0xFF616161);
const _greyDark = PdfColor.fromInt(0xFF212121);
const _greyLight = PdfColor.fromInt(0xFFF5F5F5);
const _green = PdfColor.fromInt(0xFF2E7D32);
const _greenLight = PdfColor.fromInt(0xFFE8F5E9);
const _orange = PdfColor.fromInt(0xFFE65100);
const _orangeLight = PdfColor.fromInt(0xFFFFF3E0);
const _red = PdfColor.fromInt(0xFFB71C1C);
const _redLight = PdfColor.fromInt(0xFFFFEBEE);
const _purple = PdfColor.fromInt(0xFF4A148C);
const _purpleLight = PdfColor.fromInt(0xFFF3E5F5);

void main() async {
  await initializeDateFormatting('ru');

  final fontData =
      File('C:/Windows/Fonts/arial.ttf').readAsBytesSync().buffer.asByteData();
  final fontBoldData = File('C:/Windows/Fonts/arialbd.ttf')
      .readAsBytesSync()
      .buffer
      .asByteData();
  final fontItalicData = File('C:/Windows/Fonts/ariali.ttf')
      .readAsBytesSync()
      .buffer
      .asByteData();

  final font = pw.Font.ttf(fontData);
  final fontBold = pw.Font.ttf(fontBoldData);
  final fontItalic = pw.Font.ttf(fontItalicData);

  final theme = pw.ThemeData.withFont(
    base: font,
    bold: fontBold,
    italic: fontItalic,
  );

  final doc = pw.Document(theme: theme);

  // ─── Обложка ────────────────────────────────────────────────────────────
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(
        children: [
          pw.Positioned(
            top: 0, left: 0, right: 0,
            child: pw.Container(height: 380, color: _blue),
          ),
          pw.Positioned(
            top: 340, left: 0, right: 0,
            child: pw.Container(height: 40, color: _blueDark),
          ),
          pw.Positioned.fill(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(60, 80, 60, 60),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Windows badge
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text(
                      '  Windows 10 / 11',
                      style: pw.TextStyle(
                        font: fontBold, fontSize: 11, color: _blue,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    'FinApp',
                    style: pw.TextStyle(
                      font: fontBold, fontSize: 56, color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Установка и использование\nна Windows',
                    style: pw.TextStyle(
                      font: font, fontSize: 22, color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Container(width: 60, height: 3, color: PdfColors.white),
                  pw.SizedBox(height: 200),

                  pw.Text(
                    'Пошаговый гайд',
                    style: pw.TextStyle(
                      font: fontBold, fontSize: 20, color: _blue,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    DateFormat('MMMM yyyy', 'ru').format(DateTime.now()),
                    style: pw.TextStyle(font: font, fontSize: 13, color: _grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ─── Содержание ──────────────────────────────────────────────────────────
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 48, 56, 48),
      theme: theme,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Содержание',
              style: pw.TextStyle(font: fontBold, fontSize: 22, color: _blue)),
          pw.SizedBox(height: 4),
          pw.Container(height: 2, width: 60, color: _blue),
          pw.SizedBox(height: 24),
          ..._tocItems(font, fontBold),
        ],
      ),
    ),
  );

  // ─── Контент ─────────────────────────────────────────────────────────────
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 48),
      theme: theme,
      header: (ctx) => _header(ctx, font, fontBold),
      footer: (ctx) => _footer(ctx, font),
      build: (ctx) => [

        // ═══════════════════════════════════════════════════════════════════
        // ЧАСТЬ 1 — УСТАНОВКА
        // ═══════════════════════════════════════════════════════════════════
        _partTitle('ЧАСТЬ 1', 'Установка', fontBold),

        // ── 1. Системные требования ──────────────────────────────────────
        _section('1. Системные требования', fontBold),
        _table(
          headers: ['Компонент', 'Минимум', 'Рекомендуется'],
          colWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(2),
          },
          rows: [
            ['ОС', 'Windows 10 (64-bit)', 'Windows 11'],
            ['Процессор', 'x64 любой', 'Intel Core i3 / AMD Ryzen'],
            ['ОЗУ', '4 GB', '8 GB'],
            ['Диск', '200 MB', '500 MB'],
            ['Дисплей', '1280×720', '1920×1080 и выше'],
          ],
          font: font, fontBold: fontBold,
        ),
        pw.SizedBox(height: 16),

        // ── 2. Способ 1: запуск .exe ─────────────────────────────────────
        _section('2. Способ 1 — Запуск готового .exe (рекомендуется)', fontBold),
        _body('Самый простой способ. Не требует установки Flutter или каких-либо дополнительных программ.', font),
        pw.SizedBox(height: 10),
        _subsection('2.1 Найти файл приложения', fontBold),
        _body('Файл .exe находится по пути:', font),
        _codebox(
          r'finapp\build\windows\x64\runner\Debug\finapp.exe',
          font,
          fontBold,
        ),
        pw.SizedBox(height: 10),
        _subsection('2.2 Создать ярлык на рабочем столе', fontBold),
        _steps([
          r'Откройте папку: finapp\build\windows\x64\runner\Debug\',
          'Найдите файл finapp.exe',
          'Нажмите правой кнопкой мыши → «Отправить» → «Рабочий стол (создать ярлык)»',
          'Ярлык появится на рабочем столе — двойной клик для запуска',
        ], font, fontBold),
        pw.SizedBox(height: 10),
        _tipBox('Совет: переименуйте ярлык в «FinApp» для удобства.', font, fontItalic),
        pw.SizedBox(height: 16),

        // ── 3. Способ 2: flutter run ────────────────────────────────────
        _section('3. Способ 2 — Запуск через Flutter (для разработчиков)', fontBold),
        _body('Этот способ нужен если вы хотите вносить изменения в код приложения.', font),
        pw.SizedBox(height: 10),
        _subsection('3.1 Установить Flutter', fontBold),
        _steps([
          'Откройте flutter.dev → нажмите «Get Started»',
          'Скачайте Flutter SDK для Windows (zip-архив)',
          'Распакуйте в папку, например: C:\\flutter\\',
          'Добавьте C:\\flutter\\bin в переменную PATH:',
          '   → Пуск → Система → Дополнительные параметры → Переменные среды',
          '   → В разделе «Системные переменные» найдите Path → Изменить → Создать → вставьте путь',
          'Откройте новый терминал и проверьте: flutter --version',
        ], font, fontBold),
        pw.SizedBox(height: 10),
        _subsection('3.2 Установить Visual Studio 2022', fontBold),
        _body('Необходимо для сборки Windows-приложений.', font),
        _steps([
          'Скачайте Visual Studio 2022 Community с visualstudio.microsoft.com',
          'При установке выберите компонент: «Разработка классических приложений на C++»',
          'Убедитесь что выбраны: MSVC v143, Windows 11 SDK',
          'Дождитесь завершения установки (может занять 30–60 минут)',
        ], font, fontBold),
        pw.SizedBox(height: 10),
        _subsection('3.3 Запустить приложение', fontBold),
        _steps([
          'Откройте терминал (PowerShell или CMD)',
          r'Перейдите в папку: cd C:\Users\ИМЯ\Desktop\CLaude\finapp',
          'Установите зависимости: flutter pub get',
          'Запустите: flutter run -d windows',
          'Подождите 20–40 секунд — приложение откроется',
        ], font, fontBold),
        _codebox(
          'cd C:\\Users\\ИМЯ\\Desktop\\CLaude\\finapp\n'
          'flutter pub get\n'
          'flutter run -d windows',
          font, fontBold,
        ),
        pw.SizedBox(height: 10),
        _infoBox('Горячие клавиши в режиме flutter run:', [
          'r  — Hot reload (применить изменения кода без перезапуска)',
          'R  — Hot restart (полный перезапуск)',
          'q  — Выйти из приложения',
          'd  — Отключить отладку (оставить приложение работать)',
        ], font, fontBold, _blueLight, _blue),
        pw.SizedBox(height: 16),

        // ── 4. Сборка Release-версии ─────────────────────────────────────
        _section('4. Сборка финальной версии (.exe)', fontBold),
        _body('Release-версия работает быстрее и не требует подключения к Flutter.', font),
        _codebox(
          'flutter build windows --release\n\n'
          r'# Готовый exe будет в: build\windows\x64\runner\Release\finapp.exe',
          font, fontBold,
        ),
        pw.SizedBox(height: 6),
        _warningBox(
          'Release-версию нельзя запустить на другом ПК без копирования всей папки Release (включая .dll файлы рядом с .exe).',
          font, fontItalic,
        ),
        pw.SizedBox(height: 20),

        // ═══════════════════════════════════════════════════════════════════
        // ЧАСТЬ 2 — ИСПОЛЬЗОВАНИЕ
        // ═══════════════════════════════════════════════════════════════════
        _partTitle('ЧАСТЬ 2', 'Использование', fontBold),

        // ── 5. Первый запуск ─────────────────────────────────────────────
        _section('5. Первый запуск', fontBold),
        _body(
          'При первом запуске приложение автоматически создаёт базу данных '
          'и добавляет компанию «Моя компания» с базовыми категориями и счётом. '
          'Всё готово к работе сразу.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsection('5.1 Интерфейс', fontBold),
        _body('Окно разделено на две части:', font),
        _steps([
          'Левая панель навигации — переключение между разделами',
          'Правая часть — содержимое выбранного раздела',
          'Шапка (AppBar) — название раздела, выбор компании, кнопки настроек и темы',
        ], font, fontBold),
        pw.SizedBox(height: 10),
        _infoBox('Разделы приложения:', [
          'Главная — сводный дашборд с балансами и графиком',
          'Счета — банковские счета и кассы',
          'Транзакции — все движения денег',
          'Отчёты — P&L, EBITDA, точка безубыточности',
          'Сделки — счета клиентам и дебиторка',
          'Задачи — задачи с исполнителями и дедлайнами',
          'Сотрудники — список команды',
          'Категории — группировка доходов и расходов',
        ], font, fontBold, _blueLight, _blue),
        pw.SizedBox(height: 16),

        // ── 6. Компании ──────────────────────────────────────────────────
        _section('6. Управление компаниями', fontBold),
        _body(
          'В одном приложении можно вести несколько компаний. '
          'Переключение между ними — через выпадающее меню в шапке.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsection('6.1 Создать новую компанию', fontBold),
        _steps([
          'Нажмите кнопку 🏢+ в правом верхнем углу',
          'Введите название компании',
          'Добавьте описание (необязательно)',
          'Выберите валюту: KGS (сом), RUB (рубль), USD, EUR, KZT, UZS',
          'Нажмите «Создать»',
        ], font, fontBold),
        pw.SizedBox(height: 10),
        _subsection('6.2 Настройки компании', fontBold),
        _steps([
          'Нажмите ⚙ (шестерёнка) в правом верхнем углу',
          'Измените название, описание или валюту',
          'Нажмите «Сохранить» или кнопку FAB внизу справа',
        ], font, fontBold),
        pw.SizedBox(height: 16),

        // ── 7. Счета ─────────────────────────────────────────────────────
        _section('7. Счета', fontBold),
        _body(
          'Счёт — место хранения денег (касса, банковский счёт, карта). '
          'Баланс обновляется автоматически при добавлении транзакций.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsection('7.1 Добавить счёт', fontBold),
        _steps([
          'Раздел «Счета» → нажмите кнопку + (синяя, внизу справа)',
          'Тип счёта: Наличные / Банк / Карта',
          'Название: «Касса», «Тинькофф», «MBANK» и т.д.',
          'Начальный баланс (если деньги уже есть)',
          'Нажмите «Сохранить»',
        ], font, fontBold),
        pw.SizedBox(height: 10),
        _subsection('7.2 Просмотр и редактирование', fontBold),
        _body('Нажмите на карточку счёта чтобы открыть историю операций. Долгое нажатие — редактировать или удалить.', font),
        pw.SizedBox(height: 16),

        // ── 8. Транзакции ────────────────────────────────────────────────
        _section('8. Транзакции', fontBold),
        _body('Все движения денег: доходы, расходы и переводы между счетами.', font),
        pw.SizedBox(height: 10),
        _subsection('8.1 Добавить транзакцию', fontBold),
        _steps([
          'Раздел «Транзакции» → кнопка «Добавить» (внизу справа)',
          'Выберите тип: Доход / Расход / Перевод',
          'Введите сумму',
          'Выберите счёт списания',
          'Для переводов — выберите счёт зачисления',
          'Выберите категорию (только для доходов и расходов)',
          'Укажите дату (по умолчанию — сегодня)',
          'Описание — необязательно',
          'Для расходов: ☑ «Постоянный расход» — для аренды, зарплаты (влияет на EBITDA)',
          'Нажмите «Сохранить»',
        ], font, fontBold),
        pw.SizedBox(height: 10),
        _subsection('8.2 Фильтр по периоду', fontBold),
        _body('По умолчанию показывается текущий месяц. Нажмите «Изменить» → выберите диапазон дат в календаре.', font),
        pw.SizedBox(height: 10),
        _subsection('8.3 Поиск', fontBold),
        _body('Поле поиска под строкой с датами. Фильтрует транзакции по описанию в реальном времени.', font),
        pw.SizedBox(height: 10),
        _subsection('8.4 Удаление', fontBold),
        _body('Долгое нажатие на транзакцию → «Удалить» → подтвердите. Баланс счёта скорректируется.', font),
        pw.SizedBox(height: 10),
        _subsection('8.5 Экспорт в CSV', fontBold),
        _steps([
          'Нажмите кнопку ⬇ в строке с периодом (рядом с «Изменить»)',
          'Файл сохранится в «Документы»: transactions_YYYYMMDD_HHMM.csv',
          'Откройте файл в Excel — поддерживает кириллицу (файл с BOM)',
        ], font, fontBold),
        pw.SizedBox(height: 16),

        // ── 9. Отчёты ────────────────────────────────────────────────────
        _section('9. Финансовые отчёты', fontBold),
        _body('Три вкладки: P&L, EBITDA, Безубыточность. Все данные за выбранный период.', font),
        pw.SizedBox(height: 10),
        _subsection('9.1 Выбор периода', fontBold),
        _body('Нажмите «Изменить» в верхней части экрана → выберите начало и конец периода.', font),
        pw.SizedBox(height: 10),
        _subsection('9.2 P&L — Прибыль и убытки', fontBold),
        _table(
          headers: ['Показатель', 'Описание'],
          colWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(2.5),
          },
          rows: [
            ['Доходы', 'Сумма всех поступлений за период'],
            ['Расходы', 'Сумма всех трат за период'],
            ['Прибыль', 'Доходы минус Расходы'],
            ['По категориям', 'Детализация с прогресс-барами'],
            ['Диаграмма', 'Круговая — структура расходов'],
          ],
          font: font, fontBold: fontBold,
        ),
        pw.SizedBox(height: 10),
        _subsection('9.3 EBITDA', fontBold),
        _body(
          'EBITDA = Доходы − Переменные расходы. '
          'Показывает операционную прибыль без учёта постоянных затрат. '
          'Расход считается постоянным только если при его создании '
          'отметить «Постоянный расход».',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsection('9.4 Точка безубыточности', fontBold),
        _body(
          'Минимальная выручка для покрытия постоянных расходов. '
          'Приложение покажет: достигнута точка безубыточности или нет, '
          'и на сколько не хватает.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsection('9.5 Экспорт P&L в CSV', fontBold),
        _body('Нажмите ⬇ в строке с периодом. Файл: pnl_дата_начало_дата_конец.csv', font),
        pw.SizedBox(height: 16),

        // ── 10. Сделки ───────────────────────────────────────────────────
        _section('10. Сделки и дебиторская задолженность', fontBold),
        _body('Раздел для выставления счетов клиентам и отслеживания оплаты.', font),
        pw.SizedBox(height: 10),
        _subsection('10.1 Создать счёт клиенту', fontBold),
        _steps([
          'Раздел «Сделки» → «Новый счёт»',
          'Имя клиента / организации',
          'Сумма сделки',
          'Валюта',
          'Описание (предмет договора, услуга)',
          'Срок оплаты — необязательно, при просрочке выделяется красным',
          'Нажмите «Сохранить»',
        ], font, fontBold),
        pw.SizedBox(height: 10),
        _subsection('10.2 Внести частичную или полную оплату', fontBold),
        _steps([
          'Нажмите на карточку счёта',
          'Кнопка «Внести оплату»',
          'Сумма оплаты (по умолчанию — весь остаток)',
          'Счёт зачисления — деньги поступят на выбранный счёт',
          'Дата и примечание',
          'Нажмите «Сохранить»',
        ], font, fontBold),
        pw.SizedBox(height: 6),
        _body('Статус обновится автоматически: Ожидает → Частично → Оплачен.', font),
        pw.SizedBox(height: 10),
        _subsection('10.3 Печать счёта в PDF', fontBold),
        _steps([
          'Откройте карточку счёта',
          'Нажмите кнопку 🖨 в правом верхнем углу',
          'Откроется диалог печати Windows',
          'Выберите принтер или «Microsoft Print to PDF» для сохранения в файл',
          'PDF будет содержать: клиент, сумма, история оплат, прогресс оплаты',
        ], font, fontBold),
        pw.SizedBox(height: 10),
        _infoBox('Совет по PDF на Windows:', [
          'В диалоге печати выберите «Microsoft Print to PDF»',
          'Укажите имя файла и папку для сохранения',
          'Готовый PDF можно отправить клиенту по email',
        ], font, fontBold, _greenLight, _green),
        pw.SizedBox(height: 10),
        _subsection('10.4 Экспорт всех счетов в CSV', fontBold),
        _body('Нажмите маленькую кнопку ⬇ над кнопкой «Новый счёт». Файл: invoices_YYYYMMDD_HHMM.csv', font),
        pw.SizedBox(height: 16),

        // ── 11. Задачи ───────────────────────────────────────────────────
        _section('11. Задачи', fontBold),
        _steps([
          'Раздел «Задачи» → кнопка + (добавить задачу)',
          'Название, описание, исполнитель, дедлайн, приоритет (Низкий/Средний/Высокий)',
          'Нажмите на задачу чтобы изменить статус: Новая → В работе → Выполнена',
          'Просроченные задачи выделяются красным',
          'Фильтры вверху: по статусу и по исполнителю',
        ], font, fontBold),
        pw.SizedBox(height: 16),

        // ── 12. Сотрудники ───────────────────────────────────────────────
        _section('12. Сотрудники', fontBold),
        _steps([
          'Раздел «Сотрудники» → кнопка +',
          'Имя, должность, цвет аватара',
          'На карточке сотрудника — статистика задач: открыто / в работе / выполнено',
        ], font, fontBold),
        pw.SizedBox(height: 16),

        // ── 13. Категории ────────────────────────────────────────────────
        _section('13. Категории', fontBold),
        _body('Категории группируют транзакции для отчётов P&L.', font),
        pw.SizedBox(height: 6),
        _infoBox('Категории по умолчанию:', [
          'Доходы: Выручка, Прочие доходы, Инвестиции',
          'Расходы: Зарплата, Аренда, Коммунальные услуги, Маркетинг, Оборудование, Прочие расходы',
        ], font, fontBold, _blueLight, _blue),
        pw.SizedBox(height: 8),
        _steps([
          'Раздел «Категории» → кнопка + → выберите Доход или Расход → введите название',
          'Удалить категорию: нажмите 🗑 на карточке категории',
        ], font, fontBold),
        pw.SizedBox(height: 16),

        // ── 14. Тёмная тема ──────────────────────────────────────────────
        _section('14. Тёмная тема', fontBold),
        _steps([
          'Нажмите 🌙 (луна) в правом верхнем углу для включения тёмной темы',
          'Нажмите ☀️ (солнце) для возврата к светлой теме',
          'Настройка сохраняется — при следующем запуске тема та же',
        ], font, fontBold),
        pw.SizedBox(height: 16),

        // ── 15. Google Sheets ────────────────────────────────────────────
        _section('15. Синхронизация с Google Sheets', fontBold),
        _body('Автоматическая выгрузка транзакций и счетов в Google Таблицы.', font),
        pw.SizedBox(height: 10),
        _subsection('15.1 Подготовка (один раз)', fontBold),
        _steps([
          'Откройте console.cloud.google.com и войдите в Google аккаунт',
          'Создайте новый проект → дайте ему любое название',
          'Меню: APIs & Services → Library → найдите «Google Sheets API» → Enable',
          'Меню: APIs & Services → Credentials → Create Credentials → OAuth client ID',
          'Application type: «Desktop app» → Create',
          'Скопируйте Client ID и Client Secret',
          'В блоке «Authorized redirect URIs» добавьте: http://localhost',
          'Создайте Google Таблицу на sheets.google.com',
          'Скопируйте ID таблицы из адресной строки браузера',
        ], font, fontBold),
        _codebox(
          'Пример URL таблицы:\nhttps://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/edit\n\nSpreadsheet ID = 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms',
          font, fontBold,
        ),
        pw.SizedBox(height: 10),
        _subsection('15.2 Настройка в приложении', fontBold),
        _steps([
          'Нажмите ⚙ в шапке → откроются Настройки компании',
          'Прокрутите вниз до раздела «Google Sheets»',
          'Вставьте Client ID, Client Secret, Spreadsheet ID',
          'Нажмите «Синхронизировать»',
          'В браузере откроется страница авторизации Google',
          'Войдите в аккаунт → нажмите «Разрешить»',
          'Вернитесь в приложение — данные загрузятся',
        ], font, fontBold),
        pw.SizedBox(height: 10),
        _infoBox('Что появится в таблице:', [
          'Лист «Транзакции» — все транзакции: дата, тип, счёт, категория, сумма',
          'Лист «Счета» — все клиентские счета: клиент, сумма, оплачено, остаток, статус',
          'При повторной синхронизации данные перезаписываются',
        ], font, fontBold, _blueLight, _blue),
        pw.SizedBox(height: 10),
        _warningBox(
          'При повторной синхронизации авторизация происходит автоматически (сохранён refresh token). '
          'Если появится ошибка авторизации — нажмите «Выйти» и авторизуйтесь заново.',
          font, fontItalic,
        ),
        pw.SizedBox(height: 16),

        // ── 16. Где хранятся данные ──────────────────────────────────────
        _section('16. Где хранятся данные', fontBold),
        _table(
          headers: ['Что', 'Путь на Windows'],
          colWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(2.5),
          },
          rows: [
            ['База данных', r'C:\Users\ИМЯ\Documents\finapp.sqlite'],
            ['CSV экспорт', r'C:\Users\ИМЯ\Documents\*.csv'],
            ['Настройки темы', 'Реестр Windows (SharedPreferences)'],
            ['Google токен', 'Реестр Windows (SharedPreferences)'],
          ],
          font: font, fontBold: fontBold,
        ),
        pw.SizedBox(height: 10),
        _tipBox(
          'Резервная копия: скопируйте файл finapp.sqlite в надёжное место. '
          'Это полная копия всех данных приложения.',
          font, fontItalic,
        ),
        pw.SizedBox(height: 16),

        // ── 17. Решение проблем ──────────────────────────────────────────
        _section('17. Решение проблем', fontBold),

        _faq(
          'Приложение не запускается (белый экран)',
          'Проверьте что все .dll файлы находятся в той же папке что и finapp.exe. '
          'Не запускайте .exe отдельно от папки.',
          font, fontBold,
        ),
        _faq(
          'Ошибка при запуске: «Visual C++ Redistributable»',
          r'Скачайте и установите: Microsoft Visual C++ Redistributable 2022 (x64) с сайта Microsoft.',
          font, fontBold,
        ),
        _faq(
          'CSV не открывается нормально в Excel (кракозябры)',
          'Откройте Excel → Данные → Из текста/CSV → выберите файл → '
          'укажите кодировку UTF-8. Или откройте файл двойным кликом — '
          'BOM в файле должен помочь Excel определить кодировку автоматически.',
          font, fontBold,
        ),
        _faq(
          'PDF при печати показывает квадраты вместо букв',
          'Нажмите «Синхронизировать» в настройках Google Sheets — '
          'это загрузит шрифт из интернета. Или проверьте наличие шрифта Roboto в системе.',
          font, fontBold,
        ),
        _faq(
          'Синхронизация с Google Sheets не работает',
          '1) Проверьте что Google Sheets API включен в вашем проекте. '
          '2) Убедитесь что http://localhost добавлен в Authorized redirect URIs. '
          '3) Нажмите «Выйти» в разделе Google Sheets и авторизуйтесь заново.',
          font, fontBold,
        ),
        _faq(
          'Баланс счёта не сходится',
          'Баланс пересчитывается автоматически при каждой транзакции. '
          'Если вы вручную изменили начальный баланс после добавления транзакций — '
          'создайте корректирующую транзакцию.',
          font, fontBold,
        ),
        pw.SizedBox(height: 20),

        // ── Финальный блок ───────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(
              colors: [_blue, _blueDark],
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
            ),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'FinApp v1.0',
                style: pw.TextStyle(
                  font: fontBold, fontSize: 16, color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Финансовое приложение для Windows и Android',
                style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Локальное хранилище · Экспорт CSV и PDF · Google Sheets',
                style: pw.TextStyle(font: fontItalic, fontSize: 10, color: PdfColor.fromInt(0xB3FFFFFF)),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final outputPath =
      '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME']}'
      '\\Documents\\finapp_windows_guide.pdf';
  await File(outputPath).writeAsBytes(await doc.save());
  print('✓ PDF сохранён: $outputPath');
}

// ─── TOC ────────────────────────────────────────────────────────────────────

List<pw.Widget> _tocItems(pw.Font font, pw.Font fontBold) {
  final items = [
    ('ЧАСТЬ 1 — УСТАНОВКА', '', true),
    ('1.', 'Системные требования', false),
    ('2.', 'Запуск готового .exe (рекомендуется)', false),
    ('3.', 'Запуск через Flutter (для разработчиков)', false),
    ('4.', 'Сборка финальной версии', false),
    ('ЧАСТЬ 2 — ИСПОЛЬЗОВАНИЕ', '', true),
    ('5.', 'Первый запуск и интерфейс', false),
    ('6.', 'Управление компаниями', false),
    ('7.', 'Счета', false),
    ('8.', 'Транзакции и экспорт CSV', false),
    ('9.', 'Финансовые отчёты (P&L, EBITDA)', false),
    ('10.', 'Сделки, PDF печать', false),
    ('11.', 'Задачи', false),
    ('12.', 'Сотрудники', false),
    ('13.', 'Категории', false),
    ('14.', 'Тёмная тема', false),
    ('15.', 'Синхронизация с Google Sheets', false),
    ('16.', 'Где хранятся данные', false),
    ('17.', 'Решение проблем', false),
  ];

  return items.map((item) {
    final (num, title, isPart) = item;
    if (isPart) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
        child: pw.Text(
          num,
          style: pw.TextStyle(font: fontBold, fontSize: 13, color: _blue),
        ),
      );
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 16),
          pw.Text(num,
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: _grey)),
          pw.SizedBox(width: 8),
          pw.Text(title,
              style: pw.TextStyle(font: font, fontSize: 11)),
        ],
      ),
    );
  }).toList();
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

pw.Widget _header(pw.Context ctx, pw.Font font, pw.Font fontBold) {
  if (ctx.pageNumber <= 2) return pw.SizedBox();
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _blue, width: 1)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('FinApp — Установка и использование на Windows',
            style: pw.TextStyle(font: font, fontSize: 9, color: _grey)),
        pw.Text('finapp', style: pw.TextStyle(font: fontBold, fontSize: 9, color: _blue)),
      ],
    ),
  );
}

pw.Widget _footer(pw.Context ctx, pw.Font font) {
  if (ctx.pageNumber <= 2) return pw.SizedBox();
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    child: pw.Center(
      child: pw.Text('— ${ctx.pageNumber} —',
          style: pw.TextStyle(font: font, fontSize: 9, color: _grey)),
    ),
  );
}

pw.Widget _partTitle(String part, String title, pw.Font fontBold) {
  return pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 16),
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      color: _blue,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(part,
            style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromInt(0xB3FFFFFF))),
        pw.SizedBox(height: 4),
        pw.Text(title,
            style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white)),
      ],
    ),
  );
}

pw.Widget _section(String text, pw.Font fontBold) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(text,
          style: pw.TextStyle(font: fontBold, fontSize: 14, color: _blue)),
      pw.SizedBox(height: 4),
      pw.Container(height: 2, width: 36, color: _blue),
      pw.SizedBox(height: 8),
    ],
  );
}

pw.Widget _subsection(String text, pw.Font fontBold) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Text(text,
        style: pw.TextStyle(font: fontBold, fontSize: 11, color: _greyDark)),
  );
}

pw.Widget _body(String text, pw.Font font) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Text(text,
        style: pw.TextStyle(font: font, fontSize: 11, lineSpacing: 3)),
  );
}

pw.Widget _steps(List<String> steps, pw.Font font, pw.Font fontBold) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 8, bottom: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: steps.asMap().entries.map((e) {
        final isSubstep = e.value.startsWith('   →');
        return pw.Padding(
          padding: pw.EdgeInsets.only(
              bottom: 4, left: isSubstep ? 28.0 : 0),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (!isSubstep)
                pw.Container(
                  width: 20,
                  height: 20,
                  alignment: pw.Alignment.center,
                  decoration: const pw.BoxDecoration(
                    color: _blue, shape: pw.BoxShape.circle,
                  ),
                  child: pw.Text('${e.key + 1}',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 9, color: PdfColors.white)),
                )
              else
                pw.Container(
                  width: 20,
                  height: 20,
                  alignment: pw.Alignment.center,
                  child: pw.Text('→',
                      style: pw.TextStyle(font: fontBold, fontSize: 10, color: _grey)),
                ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    isSubstep ? e.value.replaceFirst('   → ', '') : e.value,
                    style: pw.TextStyle(font: font, fontSize: 11, lineSpacing: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

pw.Widget _codebox(String text, pw.Font font, pw.Font fontBold) {
  return pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFF1E1E1E),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: font,
        fontSize: 10,
        color: const PdfColor.fromInt(0xFF9CDCFE),
        lineSpacing: 4,
      ),
    ),
  );
}

pw.Widget _infoBox(
  String title,
  List<String> items,
  pw.Font font,
  pw.Font fontBold,
  PdfColor bgColor,
  PdfColor accentColor,
) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: bgColor,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border(left: pw.BorderSide(color: accentColor, width: 3)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          pw.Text(title,
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: accentColor)),
          pw.SizedBox(height: 6),
        ],
        ...items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 11, color: accentColor)),
                  pw.Expanded(
                    child: pw.Text(item,
                        style: pw.TextStyle(font: font, fontSize: 11)),
                  ),
                ],
              ),
            )),
      ],
    ),
  );
}

pw.Widget _tipBox(String text, pw.Font font, pw.Font fontItalic) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _greenLight,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border(left: pw.BorderSide(color: _green, width: 3)),
    ),
    child: pw.Text(
      'Совет: $text',
      style: pw.TextStyle(font: fontItalic, fontSize: 11, color: _green),
    ),
  );
}

pw.Widget _warningBox(String text, pw.Font font, pw.Font fontItalic) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _orangeLight,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border(left: pw.BorderSide(color: _orange, width: 3)),
    ),
    child: pw.Text(
      'Внимание: $text',
      style: pw.TextStyle(font: fontItalic, fontSize: 11, color: _orange),
    ),
  );
}

pw.Widget _table({
  required List<String> headers,
  required List<List<String>> rows,
  required pw.Font font,
  required pw.Font fontBold,
  Map<int, pw.TableColumnWidth>? colWidths,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: colWidths ??
          {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(2),
          },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _blue),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: PdfColors.white)),
                  ))
              .toList(),
        ),
        ...rows.asMap().entries.map((entry) => pw.TableRow(
              decoration: pw.BoxDecoration(
                color: entry.key.isEven
                    ? PdfColors.white
                    : const PdfColor.fromInt(0xFFF8F9FA),
              ),
              children: entry.value
                  .map((cell) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: pw.Text(cell,
                            style: pw.TextStyle(font: font, fontSize: 10)),
                      ))
                  .toList(),
            )),
      ],
    ),
  );
}

pw.Widget _faq(
    String question, String answer, pw.Font font, pw.Font fontBold) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey200),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('В: $question',
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: _blue)),
          pw.SizedBox(height: 4),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12),
            child: pw.Text('О: $answer',
                style:
                    pw.TextStyle(font: font, fontSize: 11, lineSpacing: 2)),
          ),
        ],
      ),
    ),
  );
}
