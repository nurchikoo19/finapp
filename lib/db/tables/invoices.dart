import 'package:drift/drift.dart';
import 'companies.dart';

class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id)();
  TextColumn get invoiceNumber => text().nullable()();
  TextColumn get clientName => text().withLength(min: 1, max: 300)();
  TextColumn get clientDetails => text().nullable()(); // INN / address of client
  TextColumn get description => text().nullable()();
  RealColumn get totalAmount => real()();
  TextColumn get currency => text().withDefault(const Constant('KGS'))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  // pending, partial, paid, cancelled
  TextColumn get status => text().withDefault(const Constant('pending'))();
  // Менеджер по продаже + его % комиссии
  IntColumn get salesPersonId => integer().nullable()();
  RealColumn get commissionPct => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
