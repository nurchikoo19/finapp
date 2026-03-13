import 'package:drift/drift.dart';
import 'companies.dart';

class Contracts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id)();
  TextColumn get counterparty => text().withLength(min: 1, max: 300)();
  // client / supplier
  TextColumn get type => text().withDefault(const Constant('client'))();
  TextColumn get number => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  RealColumn get totalAmount => real()();
  TextColumn get currency => text().withDefault(const Constant('KGS'))();
  // active / completed / cancelled / expired
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get signedDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
