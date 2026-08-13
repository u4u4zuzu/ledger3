import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'models/database.dart';
import 'providers/asset_providers.dart';
import 'screens/dashboard_screen.dart';
import 'screens/account_manager_screen.dart';
import 'screens/fund_manager_screen.dart';
import 'screens/stock_manager_screen.dart';
import 'screens/transaction_list_screen.dart';
import 'services/notification_service.dart' as ns;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  final db = AppDatabase();
  
  const platform = MethodChannel('com.example.ledger/notification');
  platform.setMethodCallHandler((call) async {
    if (call.method == 'onPaymentNotification') {
      final data = jsonDecode(call.arguments as String);
      final notification = ns.PaymentNotification(
        source: data['source'] as String,
        type: data['type'] as String,
        amount: (data['amount'] as num).toDouble(),
        merchant: data['merchant'] as String,
        timestamp: data['time'] as int,
      );
      await ns.NotificationService.handlePaymentNotification(notification, db);
    }
    return null;
  });
  
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) => db),
      ],
      child: const LedgerApp(),
    ),
  );
}

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '实时资产记账',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C3E50),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C3E50),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final _screens = [
    const DashboardScreen(),
    const TransactionListScreen(),
    const FundManagerScreen(),
    const StockManagerScreen(),
    const AccountManagerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '资产'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: '流水'),
          NavigationDestination(icon: Icon(Icons.trending_up_outlined), selectedIcon: Icon(Icons.trending_up), label: '基金'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: '股票'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: '账户'),
        ],
      ),
    );
  }
}
