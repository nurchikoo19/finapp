import 'package:drift/drift.dart';
import 'stock_receipts.dart';
import 'products.dart';

class StockReceiptItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get receiptId => integer().references(StockReceipts, #id)();
  // null = new product to be created on posting
  IntColumn get productId =>
      integer().nullable().references(Products, #id)();
  TextColumn get productName => text()();
  TextColumn get unit => text().withDefault(const Constant('шт'))();
  RealColumn get qty => real()();
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
  // sale price — used only when creating a new product on posting
  RealColumn get salePrice => real().withDefault(const Constant(0.0))();
}
