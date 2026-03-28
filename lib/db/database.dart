import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables/companies.dart';
import 'tables/employees.dart';
import 'tables/accounts.dart';
import 'tables/categories.dart';
import 'tables/transactions.dart';
import 'tables/tasks.dart';
import 'tables/invoices.dart';
import 'tables/invoice_payments.dart';
import 'tables/budgets.dart';
import 'tables/products.dart';
import 'tables/stock_movements.dart';
import 'tables/contracts.dart';
import 'tables/payroll_records.dart';
import 'tables/invoice_items.dart';
import 'tables/stock_receipts.dart';
import 'tables/stock_receipt_items.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Companies,
  Employees,
  Accounts,
  Categories,
  Transactions,
  Tasks,
  Invoices,
  InvoicePayments,
  InvoiceItems,
  Budgets,
  Products,
  StockMovements,
  StockReceipts,
  StockReceiptItems,
  Contracts,
  PayrollRecords,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for unit tests.
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _insertDefaultData();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(invoices);
        await m.createTable(invoicePayments);
      }
      if (from < 3) {
        await m.createTable(budgets);
      }
      if (from < 4) {
        await m.createTable(products);
        await m.createTable(stockMovements);
      }
      if (from < 5) {
        await m.createTable(contracts);
      }
      if (from < 6) {
        await m.createTable(payrollRecords);
      }
      if (from < 7) {
        await m.addColumn(companies, companies.taxRegime);
        await m.addColumn(companies, companies.inn);
        await m.addColumn(companies, companies.address);
        await m.addColumn(companies, companies.bankDetails);
        await m.addColumn(invoices, invoices.invoiceNumber);
        await m.addColumn(invoices, invoices.clientDetails);
        await m.createTable(invoiceItems);
      }
      if (from < 8) {
        await m.addColumn(employees, employees.companyId);
        await customStatement(
          'UPDATE employees SET company_id = (SELECT id FROM companies ORDER BY id LIMIT 1) WHERE company_id IS NULL',
        );
      }
      if (from < 9) {
        await m.addColumn(transactions, transactions.isRecurring);
        await m.addColumn(transactions, transactions.recurrenceInterval);
      }
      if (from < 10) {
        await m.addColumn(invoices, invoices.salesPersonId);
        await m.addColumn(invoices, invoices.commissionPct);
      }
      if (from < 11) {
        await m.addColumn(products, products.minQuantity);
        await m.addColumn(contracts, contracts.signedDate);
      }
      if (from < 12) {
        await m.addColumn(categories, categories.taxRate);
      }
      if (from < 13) {
        await m.addColumn(transactions, transactions.exchangeRate);
      }
      if (from < 14) {
        await m.createTable(stockReceipts);
        await m.createTable(stockReceiptItems);
      }
    },
  );

  Future<void> _insertDefaultData() async {
    // Default company
    final companyId = await into(companies).insert(
      CompaniesCompanion.insert(
        name: 'Моя компания',
        currency: const Value('KGS'),
      ),
    );

    // Default categories - income
    final incomeCategories = ['Выручка', 'Прочие доходы', 'Инвестиции'];
    for (final cat in incomeCategories) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          companyId: companyId,
          name: cat,
          type: const Value('income'),
        ),
      );
    }

    // Default categories - expense
    final expenseCategories = [
      'Зарплата',
      'Аренда',
      'Коммунальные услуги',
      'Маркетинг',
      'Оборудование',
      'Прочие расходы',
    ];
    for (final cat in expenseCategories) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          companyId: companyId,
          name: cat,
          type: const Value('expense'),
        ),
      );
    }

    // Default account
    await into(accounts).insert(
      AccountsCompanion.insert(
        companyId: companyId,
        name: 'Основной счёт',
        type: const Value('bank'),
      ),
    );
  }

  // ─── Companies ───────────────────────────────────────────────────────────

  Future<List<Company>> getAllCompanies() => select(companies).get();

  Stream<List<Company>> watchAllCompanies() => select(companies).watch();

  Future<int> insertCompany(CompaniesCompanion entry) =>
      into(companies).insert(entry);

  Future<bool> updateCompany(CompaniesCompanion entry) =>
      update(companies).replace(entry);

  Future<int> deleteCompany(int id) =>
      (delete(companies)..where((t) => t.id.equals(id))).go();

  // ─── Employees ───────────────────────────────────────────────────────────

  Future<List<Employee>> getAllEmployees() => select(employees).get();

  Stream<List<Employee>> watchAllEmployees() => select(employees).watch();

  Stream<List<Employee>> watchEmployeesByCompany(int companyId) =>
      (select(employees)..where((e) => e.companyId.equals(companyId))).watch();

  Future<List<Employee>> getEmployeesByCompany(int companyId) =>
      (select(employees)..where((e) => e.companyId.equals(companyId))).get();

  Future<int> insertEmployee(EmployeesCompanion entry) =>
      into(employees).insert(entry);

  Future<bool> updateEmployee(EmployeesCompanion entry) =>
      update(employees).replace(entry);

  Future<int> deleteEmployee(int id) =>
      (delete(employees)..where((t) => t.id.equals(id))).go();

  // ─── Accounts ────────────────────────────────────────────────────────────

  Stream<List<Account>> watchAccountsByCompany(int companyId) =>
      (select(accounts)..where((t) => t.companyId.equals(companyId))).watch();

  Future<List<Account>> getAccountsByCompany(int companyId) =>
      (select(accounts)..where((t) => t.companyId.equals(companyId))).get();

  Future<int> insertAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<bool> updateAccount(AccountsCompanion entry) =>
      update(accounts).replace(entry);

  Future<int> deleteAccount(int id) =>
      (delete(accounts)..where((t) => t.id.equals(id))).go();

  Future<void> updateAccountBalance(int accountId, double delta) async {
    await customStatement(
      'UPDATE accounts SET balance = balance + ? WHERE id = ?',
      [delta, accountId],
    );
  }

  // ─── Categories ──────────────────────────────────────────────────────────

  Stream<List<Category>> watchCategoriesByCompany(int companyId) =>
      (select(categories)..where((t) => t.companyId.equals(companyId)))
          .watch();

  Future<List<Category>> getCategoriesByCompany(int companyId) =>
      (select(categories)..where((t) => t.companyId.equals(companyId))).get();

  Future<int> insertCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();

  Future<bool> updateCategory(CategoriesCompanion entry) =>
      update(categories).replace(entry);

  // ─── Transactions ─────────────────────────────────────────────────────────

  Stream<List<Transaction>> watchTransactionsByCompany(
    int companyId, {
    DateTime? from,
    DateTime? to,
  }) {
    final query = select(transactions)
      ..where((t) => t.companyId.equals(companyId))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    if (from != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(to));
    }
    return query.watch();
  }

  Future<List<Transaction>> getTransactionsByCompany(
    int companyId, {
    DateTime? from,
    DateTime? to,
  }) {
    final query = select(transactions)
      ..where((t) => t.companyId.equals(companyId))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    if (from != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(to));
    }
    return query.get();
  }

  Future<int> insertTransaction(TransactionsCompanion entry) async {
    final id = await into(transactions).insert(entry);
    final tx = entry;
    if (tx.type.value == 'income') {
      await updateAccountBalance(tx.accountId.value, tx.amount.value);
    } else if (tx.type.value == 'expense') {
      await updateAccountBalance(tx.accountId.value, -tx.amount.value);
    } else if (tx.type.value == 'transfer' &&
        tx.toAccountId.value != null) {
      final rate = tx.exchangeRate.value ?? 1.0;
      await updateAccountBalance(tx.accountId.value, -tx.amount.value);
      await updateAccountBalance(tx.toAccountId.value!, tx.amount.value * rate);
    }
    return id;
  }

  Future<int> deleteTransaction(int id) async {
    final tx = await (select(transactions)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    if (tx.type == 'income') {
      await updateAccountBalance(tx.accountId, -tx.amount);
    } else if (tx.type == 'expense') {
      await updateAccountBalance(tx.accountId, tx.amount);
    } else if (tx.type == 'transfer' && tx.toAccountId != null) {
      final rate = tx.exchangeRate ?? 1.0;
      await updateAccountBalance(tx.accountId, tx.amount);
      await updateAccountBalance(tx.toAccountId!, -(tx.amount * rate));
    }
    return (delete(transactions)..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateTransaction(int id, TransactionsCompanion entry) async {
    final old = await (select(transactions)..where((t) => t.id.equals(id))).getSingle();
    // Reverse old balance effect
    if (old.type == 'income') {
      await updateAccountBalance(old.accountId, -old.amount);
    } else if (old.type == 'expense') {
      await updateAccountBalance(old.accountId, old.amount);
    } else if (old.type == 'transfer' && old.toAccountId != null) {
      final oldRate = old.exchangeRate ?? 1.0;
      await updateAccountBalance(old.accountId, old.amount);
      await updateAccountBalance(old.toAccountId!, -(old.amount * oldRate));
    }
    await (update(transactions)..where((t) => t.id.equals(id))).write(entry);
    // Apply new balance effect
    if (entry.type.value == 'income') {
      await updateAccountBalance(entry.accountId.value, entry.amount.value);
    } else if (entry.type.value == 'expense') {
      await updateAccountBalance(entry.accountId.value, -entry.amount.value);
    } else if (entry.type.value == 'transfer' && entry.toAccountId.value != null) {
      final newRate = entry.exchangeRate.value ?? 1.0;
      await updateAccountBalance(entry.accountId.value, -entry.amount.value);
      await updateAccountBalance(entry.toAccountId.value!, entry.amount.value * newRate);
    }
  }

  /// Создаёт просроченные повторяющиеся транзакции.
  /// Вызывать при старте приложения.
  Future<void> processRecurringTransactions() async {
    final recurring = await (select(transactions)
          ..where((t) => t.isRecurring.equals(true)))
        .get();
    final now = DateTime.now();

    for (final tx in recurring) {
      if (tx.recurrenceInterval == null) continue;
      DateTime next = tx.date;
      outer:
      while (true) {
        switch (tx.recurrenceInterval) {
          case 'daily':
            next = next.add(const Duration(days: 1));
            break;
          case 'weekly':
            next = next.add(const Duration(days: 7));
            break;
          case 'monthly':
            next = DateTime(next.year, next.month + 1, next.day);
            break;
          default:
            break outer; // unknown interval — stop processing this tx
        }
        if (next.isAfter(now)) break;
        // Проверяем, не создана ли уже транзакция на эту дату
        final existing = await (select(transactions)
              ..where((t) =>
                  t.companyId.equals(tx.companyId) &
                  t.accountId.equals(tx.accountId) &
                  t.amount.equals(tx.amount) &
                  t.date.equals(next)))
            .get();
        if (existing.isEmpty) {
          await insertTransaction(TransactionsCompanion.insert(
            companyId: tx.companyId,
            accountId: tx.accountId,
            categoryId: Value(tx.categoryId),
            amount: tx.amount,
            type: tx.type,
            date: next,
            description: Value(tx.description),
            isFixed: Value(tx.isFixed),
            toAccountId: Value(tx.toAccountId),
            isRecurring: const Value(false),
          ));
        }
      }
    }
  }

  // ─── Tasks ────────────────────────────────────────────────────────────────

  Stream<List<Task>> watchTasksByCompany(int companyId) =>
      (select(tasks)
            ..where((t) => t.companyId.equals(companyId))
            ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
          .watch();

  Future<List<Task>> getTasksByCompany(int companyId) =>
      (select(tasks)..where((t) => t.companyId.equals(companyId))).get();

  Future<int> insertTask(TasksCompanion entry) => into(tasks).insert(entry);

  Future<bool> updateTask(TasksCompanion entry) =>
      update(tasks).replace(entry);

  Future<int> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  // ─── Reports ──────────────────────────────────────────────────────────────

  Future<Map<String, double>> getPnLByCategory(
    int companyId,
    DateTime from,
    DateTime to,
  ) async {
    final txList = await getTransactionsByCompany(companyId, from: from, to: to);
    final catList = await getCategoriesByCompany(companyId);
    final catMap = {for (final c in catList) c.id: c.name};

    final result = <String, double>{};
    for (final tx in txList) {
      if (tx.type == 'transfer') continue;
      final catName = tx.categoryId != null
          ? (catMap[tx.categoryId!] ?? 'Без категории')
          : 'Без категории';
      final sign = tx.type == 'income' ? 1.0 : -1.0;
      result[catName] = (result[catName] ?? 0.0) + sign * tx.amount;
    }
    return result;
  }

  Future<double> getEBITDA(
    int companyId,
    DateTime from,
    DateTime to,
  ) async {
    final txList = await getTransactionsByCompany(companyId, from: from, to: to);
    double ebitda = 0;
    for (final tx in txList) {
      if (tx.type == 'income') {
        ebitda += tx.amount;
      } else if (tx.type == 'expense' && !tx.isFixed) {
        ebitda -= tx.amount;
      }
    }
    return ebitda;
  }

  Future<Map<String, double>> getMonthlyTotals(
    int companyId,
    int monthsBack,
  ) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - monthsBack + 1, 1);
    final txList = await getTransactionsByCompany(companyId, from: from);

    final income = <String, double>{};
    final expense = <String, double>{};

    for (final tx in txList) {
      if (tx.type == 'transfer') continue;
      final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      if (tx.type == 'income') {
        income[key] = (income[key] ?? 0) + tx.amount;
      } else {
        expense[key] = (expense[key] ?? 0) + tx.amount;
      }
    }

    final result = <String, double>{};
    for (final k in income.keys) { result['income_$k'] = income[k]!; }
    for (final k in expense.keys) { result['expense_$k'] = expense[k]!; }
    return result;
  }

  // ─── Budgets ──────────────────────────────────────────────────────────────

  Future<List<Budget>> getBudgetsByCompany(int companyId) =>
      (select(budgets)..where((t) => t.companyId.equals(companyId))).get();

  Future<void> upsertBudget(
      int companyId, int categoryId, double amount) async {
    final existing = await (select(budgets)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.categoryId.equals(categoryId)))
        .getSingleOrNull();
    if (amount <= 0) {
      if (existing != null) {
        await (delete(budgets)..where((t) => t.id.equals(existing.id))).go();
      }
      return;
    }
    if (existing != null) {
      await (update(budgets)..where((t) => t.id.equals(existing.id)))
          .write(BudgetsCompanion(monthlyAmount: Value(amount)));
    } else {
      await into(budgets).insert(BudgetsCompanion.insert(
        companyId: companyId,
        categoryId: categoryId,
        monthlyAmount: amount,
      ));
    }
  }

  Future<double> getTotalBalance(int companyId) async {
    final accs = await getAccountsByCompany(companyId);
    return accs.fold<double>(0.0, (s, a) => s + a.balance);
  }

  // ─── Invoices ─────────────────────────────────────────────────────────────

  Stream<List<Invoice>> watchInvoicesByCompany(int companyId) =>
      (select(invoices)
            ..where((t) => t.companyId.equals(companyId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<int> insertInvoice(InvoicesCompanion entry) =>
      into(invoices).insert(entry);

  Future<bool> updateInvoice(InvoicesCompanion entry) =>
      update(invoices).replace(entry);

  Future<int> deleteInvoice(int id) async {
    await (delete(invoicePayments)..where((t) => t.invoiceId.equals(id))).go();
    await (delete(invoiceItems)..where((t) => t.invoiceId.equals(id))).go();
    return (delete(invoices)..where((t) => t.id.equals(id))).go();
  }

  Future<List<Invoice>> getInvoicesBySalesPerson(int employeeId) =>
      (select(invoices)..where((i) => i.salesPersonId.equals(employeeId))).get();

  // ─── Invoice Items ─────────────────────────────────────────────────────────

  Future<List<InvoiceItem>> getItemsByInvoice(int invoiceId) =>
      (select(invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();

  Stream<List<InvoiceItem>> watchItemsByInvoice(int invoiceId) =>
      (select(invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).watch();

  Future<void> replaceInvoiceItems(
      int invoiceId, List<InvoiceItemsCompanion> items) async {
    await (delete(invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).go();
    for (final item in items) {
      await into(invoiceItems).insert(item);
    }
    // Recompute invoice totalAmount from items
    if (items.isNotEmpty) {
      final total = items.fold<double>(
          0.0, (s, it) => s + it.qty.value * it.unitPrice.value);
      await (update(invoices)..where((t) => t.id.equals(invoiceId)))
          .write(InvoicesCompanion(totalAmount: Value(total)));
    }
  }

  // ─── Invoice Payments ─────────────────────────────────────────────────────

  Future<List<InvoicePayment>> getPaymentsByInvoice(int invoiceId) =>
      (select(invoicePayments)
            ..where((t) => t.invoiceId.equals(invoiceId))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

  Stream<List<InvoicePayment>> watchPaymentsByInvoice(int invoiceId) =>
      (select(invoicePayments)
            ..where((t) => t.invoiceId.equals(invoiceId))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .watch();

  Future<int> insertInvoicePayment(InvoicePaymentsCompanion entry) async {
    final id = await into(invoicePayments).insert(entry);
    await _refreshInvoiceStatus(entry.invoiceId.value);
    if (entry.accountId.value != null) {
      await updateAccountBalance(entry.accountId.value!, entry.amount.value);
    }
    return id;
  }

  Future<int> deleteInvoicePayment(int id) async {
    final p = await (select(invoicePayments)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    if (p.accountId != null) {
      await updateAccountBalance(p.accountId!, -p.amount);
    }
    final result =
        await (delete(invoicePayments)..where((t) => t.id.equals(id))).go();
    await _refreshInvoiceStatus(p.invoiceId);
    return result;
  }

  Future<void> _refreshInvoiceStatus(int invoiceId) async {
    final inv = await (select(invoices)
          ..where((t) => t.id.equals(invoiceId)))
        .getSingleOrNull();
    if (inv == null) return;
    final payments = await getPaymentsByInvoice(invoiceId);
    final paid = payments.fold(0.0, (s, p) => s + p.amount);
    String status;
    if (paid <= 0) {
      status = 'pending';
    } else if (paid >= inv.totalAmount) {
      status = 'paid';
    } else {
      status = 'partial';
    }
    await (update(invoices)..where((t) => t.id.equals(invoiceId))).write(
      InvoicesCompanion(status: Value(status)),
    );
  }

  Future<double> getPaidAmountForInvoice(int invoiceId) async {
    final payments = await getPaymentsByInvoice(invoiceId);
    return payments.fold<double>(0.0, (s, p) => s + p.amount);
  }

  // ─── Products ─────────────────────────────────────────────────────────────

  Stream<List<Product>> watchProductsByCompany(int companyId) =>
      (select(products)..where((t) => t.companyId.equals(companyId))).watch();

  Future<int> insertProduct(ProductsCompanion entry) =>
      into(products).insert(entry);

  Future<bool> updateProduct(ProductsCompanion entry) =>
      update(products).replace(entry);

  Future<int> deleteProduct(int id) =>
      (delete(products)..where((t) => t.id.equals(id))).go();

  // ─── Stock Movements ──────────────────────────────────────────────────────

  Future<List<StockMovement>> getStockMovementsByProduct(int productId) =>
      (select(stockMovements)
            ..where((t) => t.productId.equals(productId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<int> insertStockMovement(StockMovementsCompanion entry) async {
    final id = await into(stockMovements).insert(entry);
    final type = entry.type.value;
    final qty = entry.quantity.value;
    final delta = type == 'in' ? qty : (type == 'out' ? -qty : qty);
    await customStatement(
      'UPDATE products SET quantity = quantity + ? WHERE id = ?',
      [delta, entry.productId.value],
    );
    return id;
  }

  // ─── Stock Receipts ───────────────────────────────────────────────────────

  Stream<List<StockReceipt>> watchReceiptsByCompany(int companyId) =>
      (select(stockReceipts)
            ..where((r) => r.companyId.equals(companyId))
            ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
          .watch();

  Future<StockReceipt?> getReceiptById(int id) =>
      (select(stockReceipts)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<int> insertReceipt(StockReceiptsCompanion entry) =>
      into(stockReceipts).insert(entry);

  Future<bool> updateReceipt(StockReceiptsCompanion entry) =>
      update(stockReceipts).replace(entry);

  Future<void> deleteReceipt(int id) async {
    await (delete(stockReceiptItems)..where((i) => i.receiptId.equals(id))).go();
    await (delete(stockReceipts)..where((r) => r.id.equals(id))).go();
  }

  Future<List<StockReceiptItem>> getItemsByReceipt(int receiptId) =>
      (select(stockReceiptItems)
            ..where((i) => i.receiptId.equals(receiptId)))
          .get();

  Future<void> replaceReceiptItems(
      int receiptId, List<StockReceiptItemsCompanion> items) async {
    await (delete(stockReceiptItems)
          ..where((i) => i.receiptId.equals(receiptId)))
        .go();
    for (final item in items) {
      await into(stockReceiptItems).insert(item);
    }
    final total = items.fold<double>(
        0.0, (s, it) => s + it.qty.value * it.unitPrice.value);
    await (update(stockReceipts)..where((r) => r.id.equals(receiptId)))
        .write(StockReceiptsCompanion(totalAmount: Value(total)));
  }

  /// Проводит накладную: создаёт новые товары (если нужно) и StockMovement'ы.
  Future<void> postReceipt(int receiptId) async {
    final receipt = await getReceiptById(receiptId);
    if (receipt == null || receipt.status == 'posted') return;

    final items = await getItemsByReceipt(receiptId);
    for (final item in items) {
      var productId = item.productId;

      if (productId == null) {
        // Создаём новый товар прямо при проведении
        productId = await insertProduct(ProductsCompanion.insert(
          companyId: receipt.companyId,
          name: item.productName,
          unit: Value(item.unit),
          purchasePrice: Value(item.unitPrice),
          salePrice: Value(item.salePrice),
        ));
        // Связываем строку накладной с созданным товаром
        await (update(stockReceiptItems)..where((i) => i.id.equals(item.id)))
            .write(StockReceiptItemsCompanion(productId: Value(productId)));
      }

      await insertStockMovement(StockMovementsCompanion.insert(
        companyId: receipt.companyId,
        productId: productId,
        type: const Value('in'),
        quantity: item.qty,
        price: Value(item.unitPrice),
        date: receipt.date,
        note: Value('Накладная ${receipt.number}'),
      ));
    }

    await (update(stockReceipts)..where((r) => r.id.equals(receiptId)))
        .write(StockReceiptsCompanion(status: const Value('posted')));
  }

  // ─── Contracts ────────────────────────────────────────────────────────────

  Stream<List<Contract>> watchContractsByCompany(int companyId) =>
      (select(contracts)
            ..where((t) => t.companyId.equals(companyId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<List<Contract>> getContractsByCompany(int companyId) =>
      (select(contracts)..where((t) => t.companyId.equals(companyId))).get();

  Future<int> insertContract(ContractsCompanion entry) =>
      into(contracts).insert(entry);

  Future<bool> updateContract(ContractsCompanion entry) =>
      update(contracts).replace(entry);

  Future<int> deleteContract(int id) =>
      (delete(contracts)..where((t) => t.id.equals(id))).go();

  // ─── Payroll ──────────────────────────────────────────────────────────────

  Stream<List<PayrollRecord>> watchPayrollByCompany(int companyId) =>
      (select(payrollRecords)
            ..where((t) => t.companyId.equals(companyId))
            ..orderBy([(t) => OrderingTerm.desc(t.period)]))
          .watch();

  Future<List<PayrollRecord>> getPayrollByPeriod(
      int companyId, DateTime period) =>
      (select(payrollRecords)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.period.equals(period)))
          .get();

  Future<List<PayrollRecord>> getPayrollByRange(
      int companyId, DateTime from, DateTime to) =>
      (select(payrollRecords)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.period.isBiggerOrEqualValue(from))
            ..where((t) => t.period.isSmallerOrEqualValue(to))
            ..orderBy([(t) => OrderingTerm.desc(t.period)]))
          .get();

  Future<int> insertPayroll(PayrollRecordsCompanion entry) async {
    final id = await into(payrollRecords).insert(entry);
    if (entry.accountId.value != null && entry.paidAt.value != null) {
      await updateAccountBalance(
          entry.accountId.value!, -entry.netAmount.value);
    }
    return id;
  }

  Future<int> deletePayroll(int id) async {
    final rec = await (select(payrollRecords)..where((t) => t.id.equals(id)))
        .getSingle();
    if (rec.accountId != null && rec.paidAt != null) {
      await updateAccountBalance(rec.accountId!, rec.netAmount);
    }
    return (delete(payrollRecords)..where((t) => t.id.equals(id))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final oldFile = File(p.join(dbFolder.path, 'finapp.sqlite'));
    final file = File(p.join(dbFolder.path, 'tabys.sqlite'));
    // One-time migration: rename legacy DB file for existing users.
    if (await oldFile.exists() && !await file.exists()) {
      await oldFile.rename(file.path);
    }
    return NativeDatabase.createInBackground(file);
  });
}
