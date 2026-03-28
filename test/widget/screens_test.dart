import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabys/app.dart';
import 'package:tabys/db/database.dart';
import 'package:tabys/providers/database_provider.dart';

// ─── Мок БД: переопределяет stream-методы, чтобы не создавать ──────────────
// Drift QueryStream-подписки. Drift вызывает StreamQueryStore.markAsClosed()
// при отмене подписки, что создаёт Timer(Duration.zero,...). Заменяя их на
// Stream.value([]) мы полностью избегаем этих таймеров в тестах.
class _MockAppDatabase extends AppDatabase {
  _MockAppDatabase() : super.forTesting();

  @override
  Stream<List<Invoice>> watchInvoicesByCompany(int companyId) =>
      Stream.value([]);
}

// ─── Статические тестовые данные ──────────────────────────────────────────

final _mockCompany = Company(
  id: 1,
  name: 'Моя компания',
  currency: 'KGS',
  createdAt: DateTime(2024, 1, 1),
);

final _mockAccount = Account(
  id: 1,
  companyId: 1,
  name: 'Основной счёт',
  type: 'bank',
  balance: 0.0,
  currency: 'KGS',
);

// Все StreamProvider'ы заменены статическими данными, чтобы в дереве
// виджетов не было реальных Drift-стримов. Без стримов нет zero-duration
// таймеров Drift при dispose, и _verifyInvariants не падает.
List<Override> _mockOverrides(AppDatabase testDb) => [
      databaseProvider.overrideWithValue(testDb),
      companiesProvider.overrideWith(
        (ref) => Stream.value([_mockCompany]),
      ),
      selectedCompanyProvider.overrideWith(
        (ref) => _mockCompany,
      ),
      accountsProvider.overrideWith(
        (ref) => Stream.value([_mockAccount]),
      ),
      transactionsProvider.overrideWith(
        (ref) => Stream.value([]),
      ),
      tasksProvider.overrideWith(
        (ref) => Stream.value([]),
      ),
      filteredTasksProvider.overrideWith(
        (ref) => [],
      ),
      employeesProvider.overrideWith(
        (ref) => Stream.value([]),
      ),
      categoriesProvider.overrideWith(
        (ref) => Stream.value([]),
      ),
      productsProvider.overrideWith(
        (ref) => Stream.value([]),
      ),
      contractsProvider.overrideWith(
        (ref) => Stream.value([]),
      ),
      payrollProvider.overrideWith(
        (ref) => Stream.value([]),
      ),
    ];

Widget _makeApp(AppDatabase testDb) {
  return ProviderScope(
    overrides: _mockOverrides(testDb),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      locale: const Locale('ru'),
      home: const TabysApp(),
    ),
  );
}

// Создаёт БД для теста и регистрирует очистку.
// Виджет заменяется на SizedBox до закрытия БД, чтобы:
//   1. ProviderScope.dispose отменил оставшиеся подписки
//   2. Drift-таймеры (если есть) были созданы и сразу уничтожены
//   3. БД закрывается последней
AppDatabase _setupDb(WidgetTester tester) {
  final db = _MockAppDatabase();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
    await db.close();
    await tester.pump(Duration.zero);
  });
  return db;
}

Future<void> _openDrawer(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(_makeApp(db));
  await tester.pump();
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  // ─── AppBar ────────────────────────────────────────────────────────────

  group('Tabys — AppBar', () {
    testWidgets('начальный заголовок — Главная', (tester) async {
      final db = _setupDb(tester);
      await tester.pumpWidget(_makeApp(db));
      await tester.pump();

      expect(find.text('Главная'), findsWidgets);
    });

    testWidgets('кнопка меню присутствует', (tester) async {
      final db = _setupDb(tester);
      await tester.pumpWidget(_makeApp(db));
      await tester.pump();

      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('кнопка настроек компании присутствует', (tester) async {
      final db = _setupDb(tester);
      await tester.pumpWidget(_makeApp(db));
      await tester.pump();

      // selectedCompany != null → показывает иконку настроек
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('кнопка темы присутствует', (tester) async {
      final db = _setupDb(tester);
      await tester.pumpWidget(_makeApp(db));
      await tester.pump();

      final hasDark = find.byIcon(Icons.dark_mode).evaluate().isNotEmpty;
      final hasLight = find.byIcon(Icons.light_mode).evaluate().isNotEmpty;
      expect(hasDark || hasLight, isTrue);
    });
  });

  // ─── Drawer ────────────────────────────────────────────────────────────

  group('Tabys — Drawer', () {
    testWidgets('нажатие меню открывает drawer', (tester) async {
      final db = _setupDb(tester);
      await _openDrawer(tester, db);

      expect(find.text('Счета'), findsWidgets);
    });

    testWidgets('drawer содержит все разделы навигации', (tester) async {
      final db = _setupDb(tester);
      await _openDrawer(tester, db);

      for (final label in [
        'Главная',
        'Счета',
        'Транзакции',
        'Отчёты',
        'Сделки',
        'Задачи',
        'Сотрудники',
        'Категории',
        'Склад',
        'Договоры',
        'Зарплата',
      ]) {
        // skipOffstage: false — items built but scrolled off-screen are found
        expect(find.text(label, skipOffstage: false), findsWidgets,
            reason: 'Не найдено: $label');
      }
    });

    testWidgets('drawer показывает название мок-компании', (tester) async {
      final db = _setupDb(tester);
      await _openDrawer(tester, db);

      expect(find.text('Моя компания'), findsOneWidget);
    });

    testWidgets('нажатие на компанию раскрывает список', (tester) async {
      final db = _setupDb(tester);
      await _openDrawer(tester, db);
      await tester.tap(find.text('Моя компания'));
      await tester.pump();

      expect(find.text('Добавить компанию'), findsOneWidget);
    });
  });

  // ─── Навигация ─────────────────────────────────────────────────────────

  group('Tabys — навигация', () {
    Future<void> navigateTo(
        WidgetTester tester, AppDatabase db, String label) async {
      await _openDrawer(tester, db);
      await tester.tap(find.text(label).last);
      await tester.pump();
    }

    testWidgets('переход на Счета', (tester) async {
      final db = _setupDb(tester);
      await navigateTo(tester, db, 'Счета');
      expect(find.text('Счета'), findsWidgets);
    });

    testWidgets('переход на Транзакции', (tester) async {
      final db = _setupDb(tester);
      await navigateTo(tester, db, 'Транзакции');
      expect(find.text('Транзакции'), findsWidgets);
    });

    testWidgets('переход на Задачи', (tester) async {
      final db = _setupDb(tester);
      await navigateTo(tester, db, 'Задачи');
      expect(find.text('Задачи'), findsWidgets);
    });

    testWidgets('переход на Сотрудники', (tester) async {
      final db = _setupDb(tester);
      await navigateTo(tester, db, 'Сотрудники');
      expect(find.text('Сотрудники'), findsWidgets);
    });

    testWidgets('переход на Категории', (tester) async {
      final db = _setupDb(tester);
      await navigateTo(tester, db, 'Категории');
      expect(find.text('Категории'), findsWidgets);
    });
  });

  // ─── Dashboard ─────────────────────────────────────────────────────────

  group('DashboardScreen', () {
    testWidgets('рендерится без исключений', (tester) async {
      final db = _setupDb(tester);
      await tester.pumpWidget(_makeApp(db));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('не показывает "Нет компаний" если есть компания',
        (tester) async {
      final db = _setupDb(tester);
      await tester.pumpWidget(_makeApp(db));
      await tester.pump();

      expect(find.text('Нет компаний. Создайте компанию.'), findsNothing);
    });
  });
}
