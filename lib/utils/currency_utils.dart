const _currencySymbols = {
  'KGS': 'с',
  'RUB': '₽',
  'USD': '\$',
  'EUR': '€',
  'KZT': '₸',
  'UZS': 'сўм',
};

/// Returns the display symbol for a given ISO currency code.
String currencySymbol(String code) => _currencySymbols[code] ?? code;
