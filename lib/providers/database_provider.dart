import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ─── Company Providers ────────────────────────────────────────────────────

final companiesProvider = StreamProvider<List<Company>>((ref) {
  return ref.watch(databaseProvider).watchAllCompanies();
});

final selectedCompanyIdProvider = StateProvider<int?>((ref) => null);

final selectedCompanyProvider = Provider<Company?>((ref) {
  final companies = ref.watch(companiesProvider).valueOrNull;
  final id = ref.watch(selectedCompanyIdProvider);
  if (companies == null || companies.isEmpty) return null;
  if (id == null) return companies.first;
  try {
    return companies.firstWhere((c) => c.id == id);
  } catch (_) {
    return companies.first;
  }
});

// ─── Employee Providers ───────────────────────────────────────────────────

final employeesProvider = StreamProvider<List<Employee>>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchEmployeesByCompany(company.id);
});

// ─── Account Providers ────────────────────────────────────────────────────

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchAccountsByCompany(company.id);
});

// ─── Category Providers ───────────────────────────────────────────────────

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchCategoriesByCompany(company.id);
});

// ─── Transaction Providers ────────────────────────────────────────────────

final transactionDateRangeProvider = StateProvider<DateRange>((ref) {
  final now = DateTime.now();
  return DateRange(
    from: DateTime(now.year, now.month, 1),
    to: DateTime(now.year, now.month + 1, 0),
  );
});

final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return const Stream.empty();
  final range = ref.watch(transactionDateRangeProvider);
  return ref
      .watch(databaseProvider)
      .watchTransactionsByCompany(company.id, from: range.from, to: range.to);
});

// ─── Task Providers ────────────────────────────────────────────────────────

final tasksProvider = StreamProvider<List<Task>>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchTasksByCompany(company.id);
});

final taskFilterEmployeeProvider = StateProvider<int?>((ref) => null);
final taskFilterStatusProvider = StateProvider<String?>((ref) => null);
final taskSearchProvider = StateProvider<String>((ref) => '');
final taskSortProvider = StateProvider<String>((ref) => 'none');

final filteredTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksProvider).valueOrNull ?? [];
  final employeeId = ref.watch(taskFilterEmployeeProvider);
  final status = ref.watch(taskFilterStatusProvider);
  final search = ref.watch(taskSearchProvider).toLowerCase();
  final sort = ref.watch(taskSortProvider);

  var filtered = tasks.where((t) {
    if (employeeId != null && t.assignedTo != employeeId) return false;
    if (status != null && t.status != status) return false;
    if (search.isNotEmpty &&
        !t.title.toLowerCase().contains(search) &&
        !(t.description?.toLowerCase().contains(search) ?? false)) {
      return false;
    }
    return true;
  }).toList();

  if (sort == 'deadline') {
    filtered.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
  } else if (sort == 'priority') {
    const order = {'high': 0, 'medium': 1, 'low': 2};
    filtered.sort((a, b) =>
        (order[a.priority] ?? 1).compareTo(order[b.priority] ?? 1));
  }

  return filtered;
});

// ─── Invoices Provider ────────────────────────────────────────────────────

final invoicesProvider = StreamProvider<List<Invoice>>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchInvoicesByCompany(company.id);
});

// Last 6 months of transactions for P&L chart
final last6MonthsTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return const Stream.empty();
  final now = DateTime.now();
  final from = DateTime(now.year, now.month - 5, 1);
  final to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  return ref
      .watch(databaseProvider)
      .watchTransactionsByCompany(company.id, from: from, to: to);
});

// ─── Products Provider ────────────────────────────────────────────────────

final productsProvider = StreamProvider<List<Product>>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchProductsByCompany(company.id);
});

// ─── Contracts Provider ───────────────────────────────────────────────────

final contractsProvider = StreamProvider<List<Contract>>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchContractsByCompany(company.id);
});

// ─── Payroll Provider ─────────────────────────────────────────────────────

final payrollProvider = StreamProvider<List<PayrollRecord>>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchPayrollByCompany(company.id);
});

class DateRange {
  final DateTime from;
  final DateTime to;
  const DateRange({required this.from, required this.to});
}
