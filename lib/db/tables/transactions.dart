import 'package:drift/drift.dart';
import 'companies.dart';
import 'accounts.dart';
import 'categories.dart';

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // income, expense, transfer
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().nullable()();
  BoolColumn get isFixed => boolean().withDefault(const Constant(false))();
  // For transfers: target account id
  IntColumn get toAccountId => integer().nullable()();
  // For cross-currency transfers: units of source currency per 1 unit of destination currency.
  // null means same currency (rate = 1.0).
  RealColumn get exchangeRate => real().nullable()();
  // Recurring: if true, auto-creates copies on schedule
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  // daily / weekly / monthly — null if not recurring
  TextColumn get recurrenceInterval => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
