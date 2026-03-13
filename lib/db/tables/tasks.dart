import 'package:drift/drift.dart';
import 'companies.dart';
import 'employees.dart';

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id)();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get description => text().nullable()();
  IntColumn get assignedTo => integer().nullable().references(Employees, #id)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('new'))(); // new, in_progress, done, cancelled
  TextColumn get priority => text().withDefault(const Constant('medium'))(); // low, medium, high
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
