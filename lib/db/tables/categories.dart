import 'package:drift/drift.dart';
import 'companies.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get type => text().withDefault(const Constant('expense'))(); // income, expense
  IntColumn get parentId => integer().nullable()();
  // Ставка налога для доходной категории (%, напр. 2.0, 4.0, 6.0).
  // null = ставка не указана.
  RealColumn get taxRate => real().nullable()();
}
