import 'package:drift/drift.dart';
import 'companies.dart';

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId => integer().references(Companies, #id)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get type => text().withDefault(const Constant('cash'))(); // cash, bank, card
  TextColumn get bankName => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get currency => text().withDefault(const Constant('RUB'))();
}
