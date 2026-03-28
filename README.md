# finapp

A Flutter-based business financial management app for small and medium businesses. Covers the full ERP cycle: accounting, invoicing, payroll, inventory, contracts, and task management. Targets Android and Windows. UI is in Russian.

## Features

- **Multi-company** — switch between companies with per-company currency (KGS, RUB, USD, EUR, KZT, UZS)
- **Accounts & Transactions** — track balances, income/expense, recurring transactions with auto-processing on startup
- **Invoices** — line items, payments, salesperson commissions, PDF export
- **Budgets** — set category budgets and track spend
- **Employees & Payroll** — employee records and payroll history
- **Inventory** — products, stock movements, reorder threshold alerts
- **Contracts** — contract management with signed date tracking
- **Tasks** — task management with priorities and statuses
- **Reports** — P&L, cash flow, charts via fl_chart
- **Export** — PDF reports, CSV export, Google Sheets sync
- **Telegram notifications** — send reports via bot
- **Backup / Restore** — local file backup and restore
- **Dark / light theme**

## Tech Stack

| | |
|---|---|
| Framework | Flutter (SDK ^3.6.2) |
| State management | Riverpod 2.6 + riverpod_generator |
| Database | Drift (SQLite), schema v11 |
| Charts | fl_chart |
| PDF | pdf + printing |
| Google integration | googleapis + googleapis_auth |

## Project Structure

```
lib/
├── app.dart              # Root widget, drawer navigation, company switcher
├── main.dart             # Entry point
├── db/
│   ├── database.dart     # AppDatabase, schema migrations
│   └── tables/           # 14 Drift table definitions
├── providers/            # Riverpod providers
├── screens/              # 11 feature screens
├── services/             # PDF, CSV, Sheets, Telegram, Backup
├── widgets/              # Shared UI components
└── utils/
```

## Getting Started

### Prerequisites

- Flutter SDK ^3.6.2
- Dart SDK ^3.6.2

### Run

```bash
flutter pub get
flutter run
```

### Code generation (after modifying DB tables or providers)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Build

```bash
# Android
flutter build apk

# Windows
flutter build windows
```

### Tests

```bash
# All tests
flutter test

# By suite
flutter test test/unit/num_to_words_test.dart   # 39 unit tests — Russian number-to-words
flutter test test/unit/database_test.dart        # 25 unit tests — DB logic (balances, invoices, payroll…)
flutter test test/widget/widgets_test.dart       # 25 widget tests — SummaryCard, StatusBadge, PriorityBadge
flutter test test/widget/screens_test.dart       # 15 widget tests — AppBar, Drawer, navigation, Dashboard
```

| Suite | Tests | Scope |
| --- | --- | --- |
| `unit/num_to_words_test` | 39 | `numToWordsSom` — Russian number→words conversion incl. feminine thousands |
| `unit/database_test` | 25 | In-memory Drift DB: balance updates, invoice lifecycle, budgets, P&L, payroll |
| `widget/widgets_test` | 25 | Pure widget rendering: SummaryCard, StatusBadge, PriorityBadge |
| `widget/screens_test` | 15 | Full app with mocked providers: AppBar, Drawer, navigation, DashboardScreen |
  