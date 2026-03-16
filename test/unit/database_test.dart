import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabys/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  // After onCreate, default data exists:
  //   Company id=1, Categories id=1..9, Account id=1 (balance=0.0)

  // ─── Баланс счёта ────────────────────────────────────────────────────────

  group('Транзакции: обновление баланса', () {
    test('доход увеличивает баланс', () async {
      await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 1000.0,
        type: 'income',
        date: DateTime(2024, 1, 1),
      ));

      final accounts = await db.getAccountsByCompany(1);
      expect(accounts.first.balance, equals(1000.0));
    });

    test('расход уменьшает баланс', () async {
      await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 400.0,
        type: 'expense',
        date: DateTime(2024, 1, 1),
      ));

      final accounts = await db.getAccountsByCompany(1);
      expect(accounts.first.balance, equals(-400.0));
    });

    test('удаление дохода возвращает баланс к нулю', () async {
      final id = await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 2000.0,
        type: 'income',
        date: DateTime(2024, 1, 1),
      ));

      await db.deleteTransaction(id);

      final accounts = await db.getAccountsByCompany(1);
      expect(accounts.first.balance, equals(0.0));
    });

    test('удаление расхода возвращает баланс к нулю', () async {
      final id = await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 300.0,
        type: 'expense',
        date: DateTime(2024, 1, 1),
      ));

      await db.deleteTransaction(id);

      final accounts = await db.getAccountsByCompany(1);
      expect(accounts.first.balance, equals(0.0));
    });

    test('перевод: дебетует источник и кредитует назначение', () async {
      // Пополняем исходный счёт
      await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 5000.0,
        type: 'income',
        date: DateTime(2024, 1, 1),
      ));

      final account2Id = await db.insertAccount(AccountsCompanion.insert(
        companyId: 1,
        name: 'Второй счёт',
      ));

      await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 1500.0,
        type: 'transfer',
        date: DateTime(2024, 1, 2),
        toAccountId: Value(account2Id),
      ));

      final accounts = await db.getAccountsByCompany(1);
      final src = accounts.firstWhere((a) => a.id == 1);
      final dst = accounts.firstWhere((a) => a.id == account2Id);

      expect(src.balance, equals(3500.0));
      expect(dst.balance, equals(1500.0));
    });

    test('обновление транзакции: корректно пересчитывает баланс', () async {
      final id = await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 1000.0,
        type: 'income',
        date: DateTime(2024, 1, 1),
      ));

      // Меняем доход 1000 на расход 500
      await db.updateTransaction(
        id,
        TransactionsCompanion(
          companyId: const Value(1),
          accountId: const Value(1),
          amount: const Value(500.0),
          type: const Value('expense'),
          date: Value(DateTime(2024, 1, 1)),
        ),
      );

      final accounts = await db.getAccountsByCompany(1);
      expect(accounts.first.balance, equals(-500.0));
    });
  });

  // ─── Счета ───────────────────────────────────────────────────────────────

  group('getTotalBalance', () {
    test('суммирует балансы всех счетов компании', () async {
      final account2Id = await db.insertAccount(AccountsCompanion.insert(
        companyId: 1,
        name: 'Кэш',
      ));

      await db.updateAccountBalance(1, 3000.0);
      await db.updateAccountBalance(account2Id, 1200.0);

      final total = await db.getTotalBalance(1);
      expect(total, equals(4200.0));
    });
  });

  // ─── Счета-фактуры ───────────────────────────────────────────────────────

  group('Счета-фактуры: статус по оплатам', () {
    late int invoiceId;

    setUp(() async {
      invoiceId = await db.insertInvoice(InvoicesCompanion.insert(
        companyId: 1,
        clientName: 'ООО «Тест»',
        totalAmount: 1000.0,
      ));
    });

    test('новый счёт имеет статус pending', () async {
      final inv = await (db.select(db.invoices)
            ..where((t) => t.id.equals(invoiceId)))
          .getSingle();
      expect(inv.status, equals('pending'));
    });

    test('частичная оплата → статус partial', () async {
      await db.insertInvoicePayment(InvoicePaymentsCompanion.insert(
        invoiceId: invoiceId,
        amount: 400.0,
        date: DateTime(2024, 1, 5),
      ));

      final inv = await (db.select(db.invoices)
            ..where((t) => t.id.equals(invoiceId)))
          .getSingle();
      expect(inv.status, equals('partial'));
    });

    test('полная оплата → статус paid', () async {
      await db.insertInvoicePayment(InvoicePaymentsCompanion.insert(
        invoiceId: invoiceId,
        amount: 1000.0,
        date: DateTime(2024, 1, 5),
      ));

      final inv = await (db.select(db.invoices)
            ..where((t) => t.id.equals(invoiceId)))
          .getSingle();
      expect(inv.status, equals('paid'));
    });

    test('удаление платежа возвращает статус к pending', () async {
      final paymentId = await db.insertInvoicePayment(
        InvoicePaymentsCompanion.insert(
          invoiceId: invoiceId,
          amount: 1000.0,
          date: DateTime(2024, 1, 5),
        ),
      );

      await db.deleteInvoicePayment(paymentId);

      final inv = await (db.select(db.invoices)
            ..where((t) => t.id.equals(invoiceId)))
          .getSingle();
      expect(inv.status, equals('pending'));
    });

    test('getPaidAmountForInvoice суммирует все платежи', () async {
      await db.insertInvoicePayment(InvoicePaymentsCompanion.insert(
        invoiceId: invoiceId,
        amount: 300.0,
        date: DateTime(2024, 1, 1),
      ));
      await db.insertInvoicePayment(InvoicePaymentsCompanion.insert(
        invoiceId: invoiceId,
        amount: 200.0,
        date: DateTime(2024, 1, 2),
      ));

      final paid = await db.getPaidAmountForInvoice(invoiceId);
      expect(paid, equals(500.0));
    });
  });

  // ─── Бюджет ──────────────────────────────────────────────────────────────

  group('upsertBudget', () {
    test('создаёт новую запись бюджета', () async {
      await db.upsertBudget(1, 1, 5000.0);

      final budgets = await db.getBudgetsByCompany(1);
      expect(budgets.length, equals(1));
      expect(budgets.first.monthlyAmount, equals(5000.0));
    });

    test('обновляет существующую запись', () async {
      await db.upsertBudget(1, 1, 5000.0);
      await db.upsertBudget(1, 1, 8000.0);

      final budgets = await db.getBudgetsByCompany(1);
      expect(budgets.length, equals(1));
      expect(budgets.first.monthlyAmount, equals(8000.0));
    });

    test('amount = 0 удаляет запись', () async {
      await db.upsertBudget(1, 1, 5000.0);
      await db.upsertBudget(1, 1, 0.0);

      final budgets = await db.getBudgetsByCompany(1);
      expect(budgets.isEmpty, isTrue);
    });
  });

  // ─── Финансовые отчёты ───────────────────────────────────────────────────

  group('getPnLByCategory', () {
    test('группирует по названию категории с правильными знаками', () async {
      // categories id=1 → 'Выручка' (income), id=4 → 'Зарплата' (expense)
      await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 10000.0,
        type: 'income',
        date: DateTime(2024, 3, 1),
        categoryId: const Value(1),
      ));
      await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 3000.0,
        type: 'expense',
        date: DateTime(2024, 3, 5),
        categoryId: const Value(4),
      ));
      await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 2000.0,
        type: 'income',
        date: DateTime(2024, 3, 10),
        categoryId: const Value(1),
      ));

      final pnl = await db.getPnLByCategory(
        1,
        DateTime(2024, 3, 1),
        DateTime(2024, 3, 31),
      );

      expect(pnl['Выручка'], equals(12000.0));
      expect(pnl['Зарплата'], equals(-3000.0));
    });

    test('переводы не попадают в P&L', () async {
      final account2Id = await db.insertAccount(AccountsCompanion.insert(
        companyId: 1,
        name: 'Счёт 2',
      ));
      await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 500.0,
        type: 'transfer',
        date: DateTime(2024, 3, 1),
        toAccountId: Value(account2Id),
      ));

      final pnl = await db.getPnLByCategory(
        1,
        DateTime(2024, 3, 1),
        DateTime(2024, 3, 31),
      );

      expect(pnl.isEmpty, isTrue);
    });
  });

  group('getEBITDA', () {
    test('включает переменные расходы и исключает постоянные', () async {
      await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 10000.0,
        type: 'income',
        date: DateTime(2024, 3, 1),
      ));
      // переменный расход (isFixed = false по умолчанию)
      await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 2000.0,
        type: 'expense',
        date: DateTime(2024, 3, 2),
      ));
      // постоянный расход (амортизация и т.п.) — не входит в EBITDA
      await db.insertTransaction(TransactionsCompanion.insert(
        companyId: 1,
        accountId: 1,
        amount: 1000.0,
        type: 'expense',
        date: DateTime(2024, 3, 3),
        isFixed: const Value(true),
      ));

      final ebitda = await db.getEBITDA(1, DateTime(2024, 3, 1), DateTime(2024, 3, 31));
      // EBITDA = доходы − переменные расходы = 10000 − 2000 = 8000
      expect(ebitda, equals(8000.0));
    });
  });

  // ─── Склад ───────────────────────────────────────────────────────────────

  group('Складские движения', () {
    late int productId;

    setUp(() async {
      productId = await db.insertProduct(ProductsCompanion.insert(
        companyId: 1,
        name: 'Товар А',
      ));
    });

    test('приход увеличивает количество', () async {
      await db.insertStockMovement(StockMovementsCompanion.insert(
        companyId: 1,
        productId: productId,
        type: const Value('in'),
        quantity: 50.0,
        date: DateTime(2024, 3, 1),
      ));

      final products = await (db.select(db.products)
            ..where((p) => p.id.equals(productId)))
          .get();
      expect(products.first.quantity, equals(50.0));
    });

    test('расход уменьшает количество', () async {
      await db.insertStockMovement(StockMovementsCompanion.insert(
        companyId: 1,
        productId: productId,
        type: const Value('in'),
        quantity: 50.0,
        date: DateTime(2024, 3, 1),
      ));
      await db.insertStockMovement(StockMovementsCompanion.insert(
        companyId: 1,
        productId: productId,
        type: const Value('out'),
        quantity: 20.0,
        date: DateTime(2024, 3, 2),
      ));

      final products = await (db.select(db.products)
            ..where((p) => p.id.equals(productId)))
          .get();
      expect(products.first.quantity, equals(30.0));
    });
  });

  // ─── Зарплата ─────────────────────────────────────────────────────────────

  group('Начисление зарплаты', () {
    late int employeeId;

    setUp(() async {
      employeeId = await db.insertEmployee(EmployeesCompanion.insert(
        companyId: const Value(1),
        name: 'Иван Иванов',
      ));
    });

    test('оплаченная зарплата списывается со счёта', () async {
      await db.insertPayroll(PayrollRecordsCompanion.insert(
        companyId: 1,
        employeeId: employeeId,
        period: DateTime(2024, 3, 1),
        baseSalary: 50000.0,
        netAmount: 43500.0,
        accountId: const Value(1),
        paidAt: Value(DateTime(2024, 3, 31)),
      ));

      final accounts = await db.getAccountsByCompany(1);
      expect(accounts.first.balance, equals(-43500.0));
    });

    test('удаление оплаченной зарплаты восстанавливает баланс', () async {
      final id = await db.insertPayroll(PayrollRecordsCompanion.insert(
        companyId: 1,
        employeeId: employeeId,
        period: DateTime(2024, 3, 1),
        baseSalary: 50000.0,
        netAmount: 43500.0,
        accountId: const Value(1),
        paidAt: Value(DateTime(2024, 3, 31)),
      ));

      await db.deletePayroll(id);

      final accounts = await db.getAccountsByCompany(1);
      expect(accounts.first.balance, equals(0.0));
    });
  });

  // ─── Компании ─────────────────────────────────────────────────────────────

  group('Companies CRUD', () {
    test('вставка и получение компании', () async {
      final id = await db.insertCompany(CompaniesCompanion.insert(
        name: 'Новая компания',
        currency: const Value('USD'),
      ));

      final companies = await db.getAllCompanies();
      final found = companies.firstWhere((c) => c.id == id);
      expect(found.name, equals('Новая компания'));
      expect(found.currency, equals('USD'));
    });

    test('обновление компании', () async {
      final companies = await db.getAllCompanies();
      final existing = companies.first;

      await db.updateCompany(existing.toCompanion(true).copyWith(
        name: const Value('Переименованная'),
      ));

      final updated = await db.getAllCompanies();
      expect(updated.first.name, equals('Переименованная'));
    });

    test('удаление компании', () async {
      final id = await db.insertCompany(CompaniesCompanion.insert(
        name: 'Временная',
        currency: const Value('KGS'),
      ));

      await db.deleteCompany(id);

      final companies = await db.getAllCompanies();
      expect(companies.any((c) => c.id == id), isFalse);
    });
  });
}
