import 'package:drift/drift.dart';
import 'companies.dart';

class Employees extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().nullable().references(Companies, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get role => text().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0xFF2196F3))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
