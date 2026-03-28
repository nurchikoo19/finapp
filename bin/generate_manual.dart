// ignore_for_file: avoid_print
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Run from project root: dart run bin/generate_manual.dart

const _blue = PdfColor.fromInt(0xFF1565C0);
const _blueLight = PdfColor.fromInt(0xFFE3F2FD);
const _grey = PdfColor.fromInt(0xFF616161);
const _greyLight = PdfColor.fromInt(0xFFF5F5F5);
const _green = PdfColor.fromInt(0xFF2E7D32);
const _greenLight = PdfColor.fromInt(0xFFE8F5E9);
const _orange = PdfColor.fromInt(0xFFE65100);
const _orangeLight = PdfColor.fromInt(0xFFFFF3E0);

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

  // ─── Cover page ─────────────────────────────────────────────────────────
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(
        children: [
          // Blue top block
          pw.Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: pw.Container(
              height: 320,
              color: _blue,
            ),
          ),
          pw.Positioned.fill(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 60),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 100),
                  pw.Text(
                    'Tabys',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 52,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Финансовое приложение\nдля управления бизнесом',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 22,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    width: 60,
                    height: 3,
                    color: PdfColors.white,
                  ),
                  pw.SizedBox(height: 160),
                  pw.Text(
                    'Руководство пользователя',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 18,
                      color: _blue,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Версия 1.0  ·  ${DateFormat('MMMM yyyy', 'ru').format(DateTime.now())}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 13,
                      color: _grey,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Платформы: Windows · Android',
                    style: pw.TextStyle(font: font, fontSize: 12, color: _grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ─── Content pages ───────────────────────────────────────────────────────
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 48),
      theme: theme,
      header: (ctx) => _header(ctx, font, fontBold),
      footer: (ctx) => _footer(ctx, font),
      build: (ctx) => [
        // ── 1. ВВЕДЕНИЕ ─────────────────────────────────────────────────
        _sectionTitle('1. Введение', fontBold),
        _body(
          'Tabys — это локальное финансовое приложение для малого и среднего бизнеса. '
          'Все данные хранятся на вашем устройстве в базе данных SQLite. '
          'Интернет нужен только для синхронизации с Google Sheets.',
          font,
        ),
        pw.SizedBox(height: 8),
        _infoBox(
          'Возможности приложения:',
          [
            'Учёт доходов и расходов по нескольким компаниям',
            'Управление счетами (наличные, банк, карта)',
            'Финансовые отчёты: P&L, EBITDA, точка безубыточности',
            'Управление сделками и дебиторской задолженностью',
            'Управление задачами с назначением на сотрудников',
            'Экспорт данных в CSV и PDF',
            'Синхронизация с Google Sheets',
          ],
          font,
          fontBold,
          _blueLight,
          _blue,
        ),
        pw.SizedBox(height: 20),

        // ── 2. ПЕРВЫЙ ЗАПУСК ─────────────────────────────────────────────
        _sectionTitle('2. Первый запуск', fontBold),
        _body(
          'При первом запуске приложение автоматически создаёт базу данных '
          'и добавляет компанию-образец «Моя компания» с базовыми категориями и счётом.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('2.1 Навигация', fontBold),
        _body(
          'На широком экране (≥ 600px) — вертикальная панель навигации слева. '
          'На узком экране — нижняя панель. Разделы:',
          font,
        ),
        pw.SizedBox(height: 6),
        _table(
          headers: ['Раздел', 'Назначение'],
          rows: [
            ['Главная', 'Сводка: балансы, доходы, расходы, график, задачи'],
            ['Счета', 'Банковские счета и кассы компании'],
            ['Транзакции', 'История доходов, расходов и переводов'],
            ['Отчёты', 'P&L, EBITDA, точка безубыточности'],
            ['Сделки', 'Счета клиентам и дебиторская задолженность'],
            ['Задачи', 'Список задач с исполнителями и дедлайнами'],
            ['Сотрудники', 'Список сотрудников и статистика задач'],
            ['Категории', 'Категории доходов и расходов'],
          ],
          font: font,
          fontBold: fontBold,
        ),
        pw.SizedBox(height: 20),

        // ── 3. КОМПАНИИ ──────────────────────────────────────────────────
        _sectionTitle('3. Управление компаниями', fontBold),
        _body(
          'Tabys поддерживает работу с несколькими компаниями. '
          'Переключение между ними — через выпадающее меню в шапке приложения.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('3.1 Создать компанию', fontBold),
        _steps(
          [
            'Нажмите кнопку 🏢+ (Add Business) в правом углу шапки',
            'Введите название компании',
            'При необходимости — описание',
            'Выберите валюту (KGS, RUB, USD, EUR, KZT, UZS)',
            'Нажмите «Создать»',
          ],
          font,
          fontBold,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('3.2 Настройки компании', fontBold),
        _body(
          'Нажмите ⚙ (шестерёнка) в правом углу шапки. '
          'Здесь можно изменить название, описание, валюту, '
          'настроить Google Sheets или удалить компанию.',
          font,
        ),
        pw.SizedBox(height: 20),

        // ── 4. СЧЕТА ─────────────────────────────────────────────────────
        _sectionTitle('4. Счета', fontBold),
        _body(
          'Счета — это места хранения денег: кассы, банковские счета, карты. '
          'Каждый счёт принадлежит конкретной компании. '
          'Баланс счёта обновляется автоматически при добавлении транзакций.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('4.1 Добавить счёт', fontBold),
        _steps(
          [
            'Перейдите в раздел «Счета»',
            'Нажмите кнопку + (синяя кнопка внизу справа)',
            'Выберите тип: Наличные / Банк / Карта',
            'Введите название (например: «Касса», «Тинькофф», «MBANK»)',
            'При необходимости укажите название банка',
            'Нажмите «Сохранить»',
          ],
          font,
          fontBold,
        ),
        pw.SizedBox(height: 10),
        _tipBox(
          'Совет: создайте отдельный счёт для каждого источника денег. '
          'Это позволит точно отслеживать движение средств.',
          font,
          fontItalic,
        ),
        pw.SizedBox(height: 20),

        // ── 5. ТРАНЗАКЦИИ ────────────────────────────────────────────────
        _sectionTitle('5. Транзакции', fontBold),
        _body(
          'Транзакции — это все движения денег: доходы, расходы и переводы между счетами. '
          'Раздел показывает транзакции за выбранный период.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('5.1 Добавить транзакцию', fontBold),
        _steps(
          [
            'Перейдите в раздел «Транзакции»',
            'Нажмите кнопку «Добавить»',
            'Выберите тип: Доход / Расход / Перевод',
            'Введите сумму',
            'Выберите счёт (из какого счёта)',
            'Для переводов — выберите счёт назначения',
            'Выберите категорию (для доходов и расходов)',
            'Укажите дату',
            'При необходимости добавьте описание',
            'Для расходов: отметьте «Постоянный расход» если это аренда, зарплата и т.д. (влияет на EBITDA)',
            'Нажмите «Сохранить»',
          ],
          font,
          fontBold,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('5.2 Фильтр по периоду', fontBold),
        _body(
          'В верхней части экрана показан текущий период. '
          'Нажмите «Изменить» чтобы выбрать произвольный диапазон дат.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('5.3 Поиск', fontBold),
        _body(
          'Под строкой с датами есть поле поиска. '
          'Введите текст чтобы отфильтровать транзакции по описанию.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('5.4 Удалить транзакцию', fontBold),
        _body(
          'Удерживайте (долгое нажатие) на транзакцию → подтвердите удаление. '
          'Баланс счёта скорректируется автоматически.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('5.5 Экспорт в CSV', fontBold),
        _body(
          'Нажмите кнопку ⬇ (рядом с кнопкой «Изменить» период). '
          'Файл сохранится в папку «Документы» с именем вида '
          'transactions_20250310_1430.csv.',
          font,
        ),
        pw.SizedBox(height: 20),

        // ── 6. ОТЧЁТЫ ────────────────────────────────────────────────────
        _sectionTitle('6. Финансовые отчёты', fontBold),
        _body(
          'Раздел «Отчёты» содержит три вкладки: P&L, EBITDA, Безубыточность. '
          'Данные рассчитываются за выбранный период.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('6.1 P&L (Прибыль и убытки)', fontBold),
        _body(
          'Показывает доходы и расходы в разбивке по категориям, '
          'а также итоговую прибыль. Круговая диаграмма отображает '
          'структуру расходов по категориям.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('6.2 EBITDA', fontBold),
        _body(
          'EBITDA = Доходы − Переменные расходы. '
          'Постоянные расходы (аренда, зарплата и т.д.) исключаются из расчёта. '
          'Чтобы расход учитывался как постоянный — отметьте чекбокс '
          '«Постоянный расход» при создании транзакции.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('6.3 Точка безубыточности', fontBold),
        _body(
          'Показывает минимальную выручку для покрытия постоянных расходов. '
          'Формула: Постоянные расходы ÷ Валовая маржа. '
          'Приложение покажет — превысила ли текущая выручка точку безубыточности.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('6.4 Экспорт P&L в CSV', fontBold),
        _body(
          'Нажмите кнопку ⬇ в строке с периодом. '
          'Файл сохранится с именем вида pnl_01.01.2025_31.01.2025_20250310.csv.',
          font,
        ),
        pw.SizedBox(height: 20),

        // ── 7. СДЕЛКИ И ИНВОЙСЫ ─────────────────────────────────────────
        _sectionTitle('7. Сделки и дебиторская задолженность', fontBold),
        _body(
          'Раздел «Сделки» позволяет выставлять счета клиентам и '
          'отслеживать получение оплаты частями. '
          'Наверху показана сводная статистика по всем счетам.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('7.1 Создать счёт клиенту', fontBold),
        _steps(
          [
            'Перейдите в раздел «Сделки»',
            'Нажмите «Новый счёт»',
            'Введите имя клиента или организации',
            'Укажите сумму сделки',
            'Выберите валюту',
            'При необходимости добавьте описание',
            'Укажите срок оплаты (необязательно)',
            'Нажмите «Сохранить»',
          ],
          font,
          fontBold,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('7.2 Внести оплату', fontBold),
        _steps(
          [
            'Нажмите на карточку счёта чтобы открыть детали',
            'Нажмите «Внести оплату»',
            'Введите сумму оплаты (по умолчанию — остаток)',
            'Выберите счёт для зачисления (или оставьте пустым)',
            'Укажите дату и примечание',
            'Нажмите «Сохранить»',
          ],
          font,
          fontBold,
        ),
        _body(
          'Статус счёта обновится автоматически: '
          '«Ожидает» → «Частично» → «Оплачен».',
          font,
        ),
        pw.SizedBox(height: 10),
        _infoBox(
          'Статусы счетов:',
          [
            'Ожидает — оплата не внесена',
            'Частично — оплачена часть суммы',
            'Оплачен — полная оплата получена',
            'Отменён — сделка отменена',
          ],
          font,
          fontBold,
          _blueLight,
          _blue,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('7.3 Печать счёта в PDF', fontBold),
        _steps(
          [
            'Откройте счёт (нажмите на карточку)',
            'Нажмите кнопку 🖨 (Печать) в шапке экрана',
            'Выберите принтер или «Сохранить как PDF»',
            'PDF содержит: данные клиента, суммы, историю оплат, прогресс-бар',
          ],
          font,
          fontBold,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('7.4 Экспорт счетов в CSV', fontBold),
        _body(
          'Нажмите маленькую кнопку ⬇ над кнопкой «Новый счёт». '
          'Файл содержит все счета с суммами, статусами и сроками.',
          font,
        ),
        pw.SizedBox(height: 20),

        // ── 8. ЗАДАЧИ ────────────────────────────────────────────────────
        _sectionTitle('8. Управление задачами', fontBold),
        _body(
          'Раздел «Задачи» для управления рабочими задачами с '
          'назначением на сотрудников, дедлайнами и приоритетами.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('8.1 Создать задачу', fontBold),
        _steps(
          [
            'Перейдите в раздел «Задачи»',
            'Нажмите кнопку + (внизу справа)',
            'Введите название задачи',
            'При необходимости — описание',
            'Назначьте исполнителя (из списка сотрудников)',
            'Укажите дедлайн',
            'Выберите приоритет: Низкий / Средний / Высокий',
            'Нажмите «Создать»',
          ],
          font,
          fontBold,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('8.2 Изменить статус', fontBold),
        _body(
          'Нажмите на задачу → измените статус. '
          'Жизненный цикл задачи:',
          font,
        ),
        pw.SizedBox(height: 6),
        _body('Новая  →  В работе  →  Выполнена  (или Отменена)', fontBold),
        pw.SizedBox(height: 10),
        _subsectionTitle('8.3 Фильтры', fontBold),
        _body(
          'В верхней части экрана — фильтры по статусу и исполнителю. '
          'Просроченные задачи выделяются красным цветом.',
          font,
        ),
        pw.SizedBox(height: 20),

        // ── 9. СОТРУДНИКИ ────────────────────────────────────────────────
        _sectionTitle('9. Сотрудники', fontBold),
        _body(
          'Список сотрудников компании. '
          'У каждого сотрудника отображается статистика задач: '
          'сколько открыто, в работе и выполнено.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('9.1 Добавить сотрудника', fontBold),
        _steps(
          [
            'Перейдите в раздел «Сотрудники»',
            'Нажмите кнопку +',
            'Введите имя сотрудника',
            'Укажите должность/роль',
            'Выберите цвет аватара',
            'Нажмите «Добавить»',
          ],
          font,
          fontBold,
        ),
        pw.SizedBox(height: 20),

        // ── 10. КАТЕГОРИИ ────────────────────────────────────────────────
        _sectionTitle('10. Категории', fontBold),
        _body(
          'Категории помогают группировать транзакции для отчётов. '
          'Разделены на доходные и расходные. '
          'По умолчанию созданы базовые категории.',
          font,
        ),
        pw.SizedBox(height: 10),
        _infoBox(
          'Категории по умолчанию:',
          [
            'Доходы: Выручка, Прочие доходы, Инвестиции',
            'Расходы: Зарплата, Аренда, Коммунальные услуги, Маркетинг, Оборудование, Прочие расходы',
          ],
          font,
          fontBold,
          _greenLight,
          _green,
        ),
        pw.SizedBox(height: 10),
        _body(
          'Добавить свою категорию: перейдите в раздел «Категории» → '
          'нажмите + → выберите тип (Доход/Расход) → введите название.',
          font,
        ),
        pw.SizedBox(height: 20),

        // ── 11. ТЁМНАЯ ТЕМА ──────────────────────────────────────────────
        _sectionTitle('11. Тёмная тема', fontBold),
        _body(
          'Нажмите кнопку 🌙 / ☀️ в правом углу шапки приложения. '
          'Выбор темы сохраняется между запусками приложения.',
          font,
        ),
        pw.SizedBox(height: 20),

        // ── 12. GOOGLE SHEETS ────────────────────────────────────────────
        _sectionTitle('12. Синхронизация с Google Sheets', fontBold),
        _body(
          'Приложение может автоматически выгружать данные в Google Таблицы. '
          'После первой авторизации повторная авторизация не нужна.',
          font,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('12.1 Подготовка в Google Cloud Console', fontBold),
        _steps(
          [
            'Откройте console.cloud.google.com',
            'Создайте новый проект (или выберите существующий)',
            'Перейдите: APIs & Services → Library',
            'Найдите «Google Sheets API» → нажмите Enable',
            'Перейдите: APIs & Services → Credentials',
            'Нажмите «Create Credentials» → «OAuth client ID»',
            'Тип приложения: «Desktop app»',
            'Нажмите Create → скопируйте Client ID и Client Secret',
            'В разделе «Authorized redirect URIs» добавьте: http://localhost',
          ],
          font,
          fontBold,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('12.2 Создать Google Таблицу', fontBold),
        _steps(
          [
            'Откройте sheets.google.com → создайте новую таблицу',
            'Скопируйте ID из адресной строки: '
                'docs.google.com/spreadsheets/d/ВОТ_ЭТОТ_ID/edit',
          ],
          font,
          fontBold,
        ),
        pw.SizedBox(height: 10),
        _subsectionTitle('12.3 Настройка в приложении', fontBold),
        _steps(
          [
            'Нажмите ⚙ в шапке → откроются настройки компании',
            'Прокрутите вниз до раздела «Google Sheets»',
            'Вставьте Client ID',
            'Вставьте Client Secret',
            'Вставьте Spreadsheet ID',
            'Нажмите «Синхронизировать»',
            'В браузере откроется страница авторизации Google — разрешите доступ',
            'После авторизации данные загрузятся в таблицу',
          ],
          font,
          fontBold,
        ),
        pw.SizedBox(height: 10),
        _infoBox(
          'Что синхронизируется:',
          [
            'Лист «Транзакции» — все транзакции за всё время',
            'Лист «Счета» — все счета клиентам с суммами и статусами',
            'Данные полностью перезаписываются при каждой синхронизации',
          ],
          font,
          fontBold,
          _blueLight,
          _blue,
        ),
        pw.SizedBox(height: 10),
        _warningBox(
          'При повторной синхронизации токен обновляется автоматически. '
          'Если авторизация сбросилась — нажмите «Выйти» и авторизуйтесь снова.',
          font,
          fontItalic,
        ),
        pw.SizedBox(height: 20),

        // ── 13. ЧАСТО ЗАДАВАЕМЫЕ ВОПРОСЫ ────────────────────────────────
        _sectionTitle('13. Часто задаваемые вопросы', fontBold),
        _faq(
          'Где хранятся данные?',
          'На вашем устройстве в файле tabys.sqlite. '
          'Windows: в папке Documents. '
          'Android: во внутреннем хранилище приложения.',
          font,
          fontBold,
        ),
        _faq(
          'Можно ли перенести данные на другое устройство?',
          'Синхронизация через Google Sheets выгружает транзакции и счета. '
          'Прямого переноса базы данных пока нет.',
          font,
          fontBold,
        ),
        _faq(
          'Где хранятся экспортированные CSV файлы?',
          'В папке «Документы» вашего пользователя. '
          'Windows: C:\\Users\\ИМЯ\\Documents\\. '
          'Имя файла содержит дату и время экспорта.',
          font,
          fontBold,
        ),
        _faq(
          'Как удалить компанию?',
          'Настройки компании (⚙) → прокрутите вниз → «Удалить компанию». '
          'Внимание: удалятся все счета, транзакции, задачи и категории компании.',
          font,
          fontBold,
        ),
        _faq(
          'Почему EBITDA не совпадает с прибылью?',
          'EBITDA не учитывает постоянные расходы. '
          'При добавлении расхода отметьте «Постоянный расход» для аренды, '
          'зарплаты и амортизации — тогда расчёт будет точным.',
          font,
          fontBold,
        ),
        _faq(
          'Что делать если PDF не открывается?',
          'Убедитесь что на устройстве есть приложение для просмотра PDF. '
          'На Windows PDF открывается через браузер или встроенный просмотрщик.',
          font,
          fontBold,
        ),
        pw.SizedBox(height: 30),

        // ── Подвал ───────────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: _greyLight,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Tabys v1.0',
                style: pw.TextStyle(font: fontBold, fontSize: 14, color: _blue),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Платформы: Windows · Android  ·  База данных: SQLite (Drift)',
                style: pw.TextStyle(font: font, fontSize: 11, color: _grey),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final outputPath =
      '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME']}'
      '\\Documents\\tabys_manual.pdf';
  final file = File(outputPath);
  await file.writeAsBytes(await doc.save());
  print('✓ PDF сохранён: $outputPath');
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

pw.Widget _header(pw.Context ctx, pw.Font font, pw.Font fontBold) {
  if (ctx.pageNumber == 1) return pw.SizedBox();
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _blue, width: 1)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Tabys — Руководство пользователя',
            style: pw.TextStyle(font: font, fontSize: 9, color: _grey)),
        pw.Text('tabys',
            style: pw.TextStyle(font: fontBold, fontSize: 9, color: _blue)),
      ],
    ),
  );
}

pw.Widget _footer(pw.Context ctx, pw.Font font) {
  if (ctx.pageNumber == 1) return pw.SizedBox();
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          '— ${ctx.pageNumber} —',
          style: pw.TextStyle(font: font, fontSize: 9, color: _grey),
        ),
      ],
    ),
  );
}

pw.Widget _sectionTitle(String text, pw.Font fontBold) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        text,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 16,
          color: _blue,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Container(height: 2, width: 40, color: _blue),
      pw.SizedBox(height: 10),
    ],
  );
}

pw.Widget _subsectionTitle(String text, pw.Font fontBold) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.black),
    ),
  );
}

pw.Widget _body(String text, pw.Font font) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(font: font, fontSize: 11, lineSpacing: 3),
    ),
  );
}

pw.Widget _steps(List<String> steps, pw.Font font, pw.Font fontBold) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 8, bottom: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: steps.asMap().entries.map((e) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 20,
                height: 20,
                alignment: pw.Alignment.center,
                decoration: const pw.BoxDecoration(
                  color: _blue,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Text(
                  '${e.key + 1}',
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 9, color: PdfColors.white),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    e.value,
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

pw.Widget _infoBox(
  String title,
  List<String> items,
  pw.Font font,
  pw.Font fontBold,
  PdfColor bgColor,
  PdfColor accentColor,
) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 6),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: bgColor,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border(left: pw.BorderSide(color: accentColor, width: 3)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(font: fontBold, fontSize: 11, color: accentColor)),
        pw.SizedBox(height: 6),
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
    margin: const pw.EdgeInsets.only(bottom: 6),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _greenLight,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border(left: pw.BorderSide(color: _green, width: 3)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('💡 ',
            style: pw.TextStyle(font: font, fontSize: 11, color: _green)),
        pw.Expanded(
          child: pw.Text(text,
              style: pw.TextStyle(font: fontItalic, fontSize: 11, color: _green)),
        ),
      ],
    ),
  );
}

pw.Widget _warningBox(String text, pw.Font font, pw.Font fontItalic) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 6),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _orangeLight,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border(left: pw.BorderSide(color: _orange, width: 3)),
    ),
    child: pw.Text(
      '⚠ $text',
      style: pw.TextStyle(font: fontItalic, fontSize: 11, color: _orange),
    ),
  );
}

pw.Widget _table({
  required List<String> headers,
  required List<List<String>> rows,
  required pw.Font font,
  required pw.Font fontBold,
}) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300),
    columnWidths: {
      0: const pw.FlexColumnWidth(1.2),
      1: const pw.FlexColumnWidth(2.8),
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
              color:
                  entry.key.isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF8F9FA),
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
  );
}

pw.Widget _faq(
    String question, String answer, pw.Font font, pw.Font fontBold) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'В: $question',
          style: pw.TextStyle(font: fontBold, fontSize: 11, color: _blue),
        ),
        pw.SizedBox(height: 3),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 16),
          child: pw.Text(
            'О: $answer',
            style: pw.TextStyle(font: font, fontSize: 11, lineSpacing: 2),
          ),
        ),
      ],
    ),
  );
}
