import 'package:drift/drift.dart';
import 'companies.dart';
import 'categories.dart';

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  RealColumn get monthlyAmount => real()();
}
