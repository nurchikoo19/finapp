import 'package:drift/drift.dart';
import 'companies.dart';
import 'products.dart';

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  // in / out / adjustment
  TextColumn get type => text().withDefault(const Constant('in'))();
  RealColumn get quantity => real()();
  RealColumn get price => real().withDefault(const Constant(0.0))();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
