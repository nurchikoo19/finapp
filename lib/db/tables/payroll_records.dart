import 'package:drift/drift.dart';
import 'companies.dart';
import 'employees.dart';
import 'accounts.dart';

class PayrollRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id)();
  IntColumn get employeeId => integer().references(Employees, #id)();
  DateTimeColumn get period => dateTime()();
  RealColumn get baseSalary => real()();
  RealColumn get bonuses => real().withDefault(const Constant(0.0))();
  RealColumn get deductions => real().withDefault(const Constant(0.0))();
  RealColumn get netAmount => real()();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
