import 'package:drift/drift.dart';
import 'invoices.dart';

class InvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(Invoices, #id)();
  TextColumn get description => text()();
  RealColumn get qty => real().withDefault(const Constant(1.0))();
  TextColumn get unit => text().withDefault(const Constant('шт'))();
  RealColumn get unitPrice => real()();
  // НДС rate in percent: 0 or 12
  RealColumn get vatRate => real().withDefault(const Constant(0.0))();
}
