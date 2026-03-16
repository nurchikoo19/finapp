import 'package:flutter_test/flutter_test.dart';
import 'package:tabys/utils/num_to_words.dart';

void main() {
  group('numToWordsSom — нули и однозначные', () {
    test('0', () => expect(numToWordsSom(0), 'Ноль сом 00 тыйын'));
    test('1', () => expect(numToWordsSom(1), 'Один сом 00 тыйын'));
    test('2', () => expect(numToWordsSom(2), 'Два сом 00 тыйын'));
    test('5', () => expect(numToWordsSom(5), 'Пять сом 00 тыйын'));
    test('9', () => expect(numToWordsSom(9), 'Девять сом 00 тыйын'));
  });

  group('numToWordsSom — десятки и подростковые числа', () {
    test('10', () => expect(numToWordsSom(10), 'Десять сом 00 тыйын'));
    test('11 (исключение из правила)', () => expect(numToWordsSom(11), 'Одиннадцать сом 00 тыйын'));
    test('12', () => expect(numToWordsSom(12), 'Двенадцать сом 00 тыйын'));
    test('19', () => expect(numToWordsSom(19), 'Девятнадцать сом 00 тыйын'));
    test('20', () => expect(numToWordsSom(20), 'Двадцать сом 00 тыйын'));
    test('21', () => expect(numToWordsSom(21), 'Двадцать один сом 00 тыйын'));
    test('99', () => expect(numToWordsSom(99), 'Девяносто девять сом 00 тыйын'));
  });

  group('numToWordsSom — сотни', () {
    test('100', () => expect(numToWordsSom(100), 'Сто сом 00 тыйын'));
    test('200', () => expect(numToWordsSom(200), 'Двести сом 00 тыйын'));
    test('500', () => expect(numToWordsSom(500), 'Пятьсот сом 00 тыйын'));
    test('900', () => expect(numToWordsSom(900), 'Девятьсот сом 00 тыйын'));
    test('111', () => expect(numToWordsSom(111), 'Сто одиннадцать сом 00 тыйын'));
    test('321', () => expect(numToWordsSom(321), 'Триста двадцать один сом 00 тыйын'));
  });

  group('numToWordsSom — тысячи (женский род)', () {
    test('1000 → одна тысяча', () => expect(numToWordsSom(1000), 'Одна тысяча сом 00 тыйын'));
    test('2000 → две тысячи', () => expect(numToWordsSom(2000), 'Две тысячи сом 00 тыйын'));
    test('3000 → три тысячи', () => expect(numToWordsSom(3000), 'Три тысячи сом 00 тыйын'));
    test('5000 → пять тысяч', () => expect(numToWordsSom(5000), 'Пять тысяч сом 00 тыйын'));
    test('11000 → одиннадцать тысяч (исключение)', () => expect(numToWordsSom(11000), 'Одиннадцать тысяч сом 00 тыйын'));
    test('21000 → двадцать одна тысяча', () => expect(numToWordsSom(21000), 'Двадцать одна тысяча сом 00 тыйын'));
    test('22000 → двадцать две тысячи', () => expect(numToWordsSom(22000), 'Двадцать две тысячи сом 00 тыйын'));
    test('1001 → одна тысяча один', () => expect(numToWordsSom(1001), 'Одна тысяча один сом 00 тыйын'));
    test('1500 → одна тысяча пятьсот', () => expect(numToWordsSom(1500), 'Одна тысяча пятьсот сом 00 тыйын'));
  });

  group('numToWordsSom — миллионы', () {
    test('1000000 → один миллион', () => expect(numToWordsSom(1000000), 'Один миллион сом 00 тыйын'));
    test('2000000 → два миллиона', () => expect(numToWordsSom(2000000), 'Два миллиона сом 00 тыйын'));
    test('5000000 → пять миллионов', () => expect(numToWordsSom(5000000), 'Пять миллионов сом 00 тыйын'));
    test('11000000 → одиннадцать миллионов', () => expect(numToWordsSom(11000000), 'Одиннадцать миллионов сом 00 тыйын'));
    test('21000000 → двадцать один миллион', () => expect(numToWordsSom(21000000), 'Двадцать один миллион сом 00 тыйын'));
  });

  group('numToWordsSom — тыйын (копейки)', () {
    test('1.50 → 50 тыйын', () => expect(numToWordsSom(1.50), 'Один сом 50 тыйын'));
    test('0.99 → 99 тыйын', () => expect(numToWordsSom(0.99), 'Ноль сом 99 тыйын'));
    test('0.01 → 01 тыйын', () => expect(numToWordsSom(0.01), 'Ноль сом 01 тыйын'));
    test('100.05 → 05 тыйын', () => expect(numToWordsSom(100.05), 'Сто сом 05 тыйын'));
    test('1000.00 → 00 тыйын', () => expect(numToWordsSom(1000.00), 'Одна тысяча сом 00 тыйын'));
  });

  group('numToWordsSom — составные числа', () {
    test('1234567.89', () => expect(
      numToWordsSom(1234567.89),
      'Один миллион двести тридцать четыре тысячи пятьсот шестьдесят семь сом 89 тыйын',
    ));
    test('1011011.11', () => expect(
      numToWordsSom(1011011.11),
      'Один миллион одиннадцать тысяч одиннадцать сом 11 тыйын',
    ));
  });
}
