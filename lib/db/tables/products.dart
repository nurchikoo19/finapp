import 'package:drift/drift.dart';
import 'companies.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id)();
  TextColumn get name => text().withLength(min: 1, max: 300)();
  TextColumn get unit => text().withDefault(const Constant('шт'))();
  RealColumn get purchasePrice => real().withDefault(const Constant(0.0))();
  RealColumn get salePrice => real().withDefault(const Constant(0.0))();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  RealColumn get minQuantity => real().withDefault(const Constant(0.0))();
  TextColumn get description => text().nullable()();
}
