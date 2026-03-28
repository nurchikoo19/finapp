import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../db/database.dart';
import '../../providers/database_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _InfoPage(
                    icon: Icons.account_balance_wallet,
                    color: Colors.blue,
                    title: 'Финансы под контролем',
                    body:
                        'Ведите счета, транзакции, инвойсы и договоры в одном приложении.',
                  ),
                  _InfoPage(
                    icon: Icons.people,
                    color: Colors.green,
                    title: 'Управление командой',
                    body:
                        'Назначайте задачи сотрудникам, отслеживайте дедлайны и начисляйте зарплату.',
                  ),
                  _InfoPage(
                    icon: Icons.bar_chart,
                    color: Colors.purple,
                    title: 'Аналитика и отчёты',
                    body:
                        'P&L, EBITDA, точка безубыточности и прогноз денежного потока.',
                  ),
                  _CreateCompanyPage(),
                ],
              ),
            ),

            // Dots + buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  Row(
                    children: List.generate(4, (i) => _Dot(active: _page == i)),
                  ),
                  const Spacer(),
                  if (_page < 3)
                    FilledButton(
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text('Далее'),
                    )
                  else
                    const SizedBox(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 6),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: active
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade300,
      ),
    );
  }
}

class _InfoPage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _InfoPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 52, color: color),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CreateCompanyPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateCompanyPage> createState() =>
      _CreateCompanyPageState();
}

class _CreateCompanyPageState extends ConsumerState<_CreateCompanyPage> {
  final _nameCtrl = TextEditingController();
  String _currency = 'KGS';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    await db.insertCompany(CompaniesCompanion.insert(
      name: _nameCtrl.text.trim(),
      currency: Value(_currency),
    ));
    // companiesProvider will emit new data → _HomeRouter switches to TabysApp
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Создайте компанию',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Вы сможете добавить ещё компании позже',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Название компании *',
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: const InputDecoration(
              labelText: 'Валюта',
              prefixIcon: Icon(Icons.monetization_on),
            ),
            items: const [
              DropdownMenuItem(value: 'KGS', child: Text('с Кыргызский сом')),
              DropdownMenuItem(value: 'RUB', child: Text('₽ Рубль')),
              DropdownMenuItem(value: 'USD', child: Text('\$ Доллар')),
              DropdownMenuItem(value: 'EUR', child: Text('€ Евро')),
              DropdownMenuItem(value: 'KZT', child: Text('₸ Тенге')),
              DropdownMenuItem(value: 'UZS', child: Text('сўм Узбекский сум')),
            ],
            onChanged: (v) => setState(() => _currency = v!),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.rocket_launch),
            label: const Text('Начать работу'),
            onPressed: _saving ? null : _create,
          ),
        ],
      ),
    );
  }
}
