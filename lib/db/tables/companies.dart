import 'package:drift/drift.dart';

class Companies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('RUB'))();
  // osn / usn / patent
  TextColumn get taxRegime => text().nullable()();
  TextColumn get inn => text().nullable()();
  TextColumn get address => text().nullable()();
  // Bank details for PDF invoices (free-form, e.g. "Банк: Дос-Кредобанк, р/с 1234...")
  TextColumn get bankDetails => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
