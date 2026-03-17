import 'package:drift/drift.dart';
import 'companies.dart';

class StockReceipts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id)();
  TextColumn get number => text()();
  TextColumn get supplierName => text().nullable()();
  DateTimeColumn get date => dateTime()();
  // draft | posted
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get note => text().nullable()();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
