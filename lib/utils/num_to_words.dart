// Russian number-to-words for KGS currency (сом / тыйын)

const _ones = [
  '', 'один', 'два', 'три', 'четыре', 'пять', 'шесть', 'семь', 'восемь', 'девять',
  'десять', 'одиннадцать', 'двенадцать', 'тринадцать', 'четырнадцать', 'пятнадцать',
  'шестнадцать', 'семнадцать', 'восемнадцать', 'девятнадцать',
];

const _onesFem = [
  '', 'одна', 'две', 'три', 'четыре', 'пять', 'шесть', 'семь', 'восемь', 'девять',
  'десять', 'одиннадцать', 'двенадцать', 'тринадцать', 'четырнадцать', 'пятнадцать',
  'шестнадцать', 'семнадцать', 'восемнадцать', 'девятнадцать',
];

const _tens = [
  '', '', 'двадцать', 'тридцать', 'сорок', 'пятьдесят',
  'шестьдесят', 'семьдесят', 'восемьдесят', 'девяносто',
];

const _hundreds = [
  '', 'сто', 'двести', 'триста', 'четыреста', 'пятьсот',
  'шестьсот', 'семьсот', 'восемьсот', 'девятьсот',
];

/// Returns Russian plural form for [n] using the three forms [f1, f2, f5].
/// Example: _pluralize(1, 'тысяча', 'тысячи', 'тысяч') → 'тысяча'
String _pluralize(int n, String f1, String f2, String f5) {
  final mod100 = n % 100;
  final mod10 = n % 10;
  if (mod100 >= 11 && mod100 <= 19) return f5;
  if (mod10 == 1) return f1;
  if (mod10 >= 2 && mod10 <= 4) return f2;
  return f5;
}

/// Converts a three-digit group (0–999) to words.
/// [feminine] = true for thousands (одна тысяча, две тысячи).
String _groupToWords(int n, {bool feminine = false}) {
  if (n == 0) return '';
  final buf = StringBuffer();
  final h = n ~/ 100;
  final rem = n % 100;
  final t = rem >= 20 ? rem ~/ 10 : 0;
  final o = rem >= 20 ? rem % 10 : rem;

  if (h > 0) buf.write('${_hundreds[h]} ');
  if (t > 0) buf.write('${_tens[t]} ');
  if (o > 0) {
    buf.write(feminine ? '${_onesFem[o]} ' : '${_ones[o]} ');
  }
  return buf.toString();
}

/// Converts [amount] to Russian words for KGS.
/// Example: numToWordsSom(22000.0) → "Двадцать две тысячи сом 00 тыйын"
String numToWordsSom(double amount) {
  final intPart = amount.truncate();
  final fracPart = ((amount - intPart) * 100).round().clamp(0, 99);

  String result;
  if (intPart == 0) {
    result = 'ноль';
  } else {
    final buf = StringBuffer();
    final millions = intPart ~/ 1000000;
    final thousands = (intPart % 1000000) ~/ 1000;
    final remainder = intPart % 1000;

    if (millions > 0) {
      buf.write(_groupToWords(millions, feminine: false));
      buf.write('${_pluralize(millions, 'миллион', 'миллиона', 'миллионов')} ');
    }
    if (thousands > 0) {
      buf.write(_groupToWords(thousands, feminine: true));
      buf.write('${_pluralize(thousands, 'тысяча', 'тысячи', 'тысяч')} ');
    }
    if (remainder > 0) {
      buf.write(_groupToWords(remainder, feminine: false));
    }
    result = buf.toString().trim();
  }

  // Capitalise first letter
  result = result[0].toUpperCase() + result.substring(1);

  final kopeyki = fracPart.toString().padLeft(2, '0');
  return '$result сом $kopeyki тыйын';
}
