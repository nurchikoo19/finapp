import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabys/widgets/summary_card.dart';
import 'package:tabys/widgets/status_badge.dart';
import 'package:tabys/widgets/priority_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // ─── SummaryCard ──────────────────────────────────────────────────────────

  group('SummaryCard', () {
    testWidgets('показывает заголовок', (tester) async {
      await tester.pumpWidget(_wrap(
        const SummaryCard(
          title: 'Общий баланс',
          amount: 0,
          icon: Icons.account_balance_wallet,
          color: Colors.blue,
        ),
      ));
      expect(find.text('Общий баланс'), findsOneWidget);
    });

    testWidgets('показывает иконку', (tester) async {
      await tester.pumpWidget(_wrap(
        const SummaryCard(
          title: 'Тест',
          amount: 0,
          icon: Icons.attach_money,
          color: Colors.green,
        ),
      ));
      expect(find.byIcon(Icons.attach_money), findsOneWidget);
    });

    testWidgets('рендерится без ошибок при нулевой сумме', (tester) async {
      await tester.pumpWidget(_wrap(
        const SummaryCard(
          title: 'Доход',
          amount: 0,
          icon: Icons.arrow_upward,
          color: Colors.green,
        ),
      ));
      expect(find.text('Доход'), findsOneWidget);
    });

    testWidgets('рендерится с отрицательной суммой', (tester) async {
      await tester.pumpWidget(_wrap(
        const SummaryCard(
          title: 'Расход',
          amount: -5000,
          icon: Icons.arrow_downward,
          color: Colors.red,
        ),
      ));
      expect(find.text('Расход'), findsOneWidget);
    });

    for (final currency in ['KGS', 'RUB', 'USD', 'EUR', 'KZT', 'UZS', 'GBP']) {
      testWidgets('рендерится с валютой $currency', (tester) async {
        await tester.pumpWidget(_wrap(
          SummaryCard(
            title: 'Баланс',
            amount: 1000,
            icon: Icons.wallet,
            color: Colors.blue,
            currency: currency,
          ),
        ));
        expect(find.text('Баланс'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('содержит виджет Card', (tester) async {
      await tester.pumpWidget(_wrap(
        const SummaryCard(
          title: 'X',
          amount: 0,
          icon: Icons.info,
          color: Colors.grey,
        ),
      ));
      expect(find.byType(Card), findsOneWidget);
    });
  });

  // ─── StatusBadge ──────────────────────────────────────────────────────────

  group('StatusBadge', () {
    const knownStatuses = {
      'new': 'Новая',
      'in_progress': 'В работе',
      'done': 'Выполнена',
      'cancelled': 'Отменена',
    };

    for (final entry in knownStatuses.entries) {
      testWidgets('${entry.key} → показывает "${entry.value}"', (tester) async {
        await tester.pumpWidget(_wrap(StatusBadge(status: entry.key)));
        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('неизвестный статус показывает raw значение', (tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge(status: 'custom_status')));
      expect(find.text('custom_status'), findsOneWidget);
    });

    testWidgets('пустой статус рендерится без ошибок', (tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge(status: '')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('содержит виджет Container', (tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge(status: 'done')));
      expect(find.byType(Container), findsWidgets);
    });
  });

  // ─── PriorityBadge ────────────────────────────────────────────────────────

  group('PriorityBadge', () {
    const knownPriorities = {
      'low': 'Низкий',
      'medium': 'Средний',
      'high': 'Высокий',
    };

    for (final entry in knownPriorities.entries) {
      testWidgets('${entry.key} → показывает "${entry.value}"', (tester) async {
        await tester.pumpWidget(_wrap(PriorityBadge(priority: entry.key)));
        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('неизвестный приоритет показывает raw значение', (tester) async {
      await tester.pumpWidget(_wrap(const PriorityBadge(priority: 'urgent')));
      expect(find.text('urgent'), findsOneWidget);
    });

    testWidgets('пустой приоритет рендерится без ошибок', (tester) async {
      await tester.pumpWidget(_wrap(const PriorityBadge(priority: '')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('содержит виджет Container', (tester) async {
      await tester.pumpWidget(_wrap(const PriorityBadge(priority: 'high')));
      expect(find.byType(Container), findsWidgets);
    });
  });
}
