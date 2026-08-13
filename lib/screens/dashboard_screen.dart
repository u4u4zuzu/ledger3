import '../models/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/asset_providers.dart';
import 'add_transaction_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// 分类 ID -> 名称（用于饼图图例）
  static const Map<String, String> _categoryNames = {
    'cat_food': '餐饮',
    'cat_transport': '交通',
    'cat_shopping': '购物',
    'cat_entertainment': '娱乐',
    'cat_housing': '居住',
    'cat_medical': '医疗',
    'cat_education': '教育',
    'cat_salary': '工资',
    'cat_investment': '理财收益',
    'cat_other_in': '其他收入',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAssets = ref.watch(totalAssetsProvider);
    final todayStats = ref.watch(todayStatsProvider);
    final totalStats = ref.watch(totalStatsProvider);
    final monthlyCategoryStats = ref.watch(monthlyCategoryStatsProvider(TransactionType.expense));
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
        slivers: [
          // 顶部资产卡片
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C3E50), Color(0xFF4A6741)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '净资产',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  totalAssets.when(
                    data: (value) => Text(
                      '¥${NumberFormat('#,##0.00').format(value)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    loading: () => const CircularProgressIndicator(color: Colors.white),
                    error: (_, __) => const Text('Error', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 20),
                  // 今日收支（直接使用 todayStats，不再套 Consumer）
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          '今日支出',
                          todayStats.when(
                            data: (s) => '¥${NumberFormat('#,##0.00').format(s['expense'] ?? 0)}',
                            loading: () => '--',
                            error: (_, __) => '--',
                          ),
                          Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          '今日收入',
                          todayStats.when(
                            data: (s) => '¥${NumberFormat('#,##0.00').format(s['income'] ?? 0)}',
                            loading: () => '--',
                            error: (_, __) => '--',
                          ),
                          Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 累计收支（全部时间）
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      '累计收入',
                      totalStats.when(
                        data: (s) => '¥${NumberFormat('#,##0.00').format(s['income'] ?? 0)}',
                        loading: () => '--',
                        error: (_, __) => '--',
                      ),
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      '累计支出',
                      totalStats.when(
                        data: (s) => '¥${NumberFormat('#,##0.00').format(s['expense'] ?? 0)}',
                        loading: () => '--',
                        error: (_, __) => '--',
                      ),
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 账户列表
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('我的账户', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {},
                    child: const Text('管理'),
                  ),
                ],
              ),
            ),
          ),
          accounts.when(
            data: (list) => SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final acc = list[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getAccountColor(acc.type).withOpacity(0.15),
                      child: Icon(_getAccountIcon(acc.type), color: _getAccountColor(acc.type)),
                    ),
                    title: Text(acc.name),
                    trailing: Text(
                      '¥${NumberFormat('#,##0.00').format(acc.currentBalance)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  );
                },
                childCount: list.length,
              ),
            ),
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
          ),

          // 本月支出构成饼图
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('本月支出构成', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: monthlyCategoryStats.when(
                      data: (stats) {
                        if (stats.isEmpty) return const Center(child: Text('暂无数据'));

                        final pieColors = [
                          Colors.redAccent,
                          Colors.orangeAccent,
                          Colors.blueAccent,
                          Colors.greenAccent,
                          Colors.purpleAccent,
                          Colors.tealAccent,
                        ];

                        final total = stats.values.fold(0.0, (s, v) => s + v);

                        return PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: stats.entries.toList().asMap().entries.map((indexed) {
                              final index = indexed.key;
                              final entry = indexed.value;
                              final amount = entry.value;
                              return PieChartSectionData(
                                color: pieColors[index % pieColors.length],
                                value: amount,
                                title: total > 0 ? '${(amount / total * 100).toStringAsFixed(0)}%' : '',
                                radius: 60,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              );
                            }).toList(),
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Center(child: Text('加载失败')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 饼图说明标签（图例）：分类名 + 金额 + 占比
                  monthlyCategoryStats.when(
                    data: (stats) {
                      if (stats.isEmpty) return const SizedBox.shrink();
                      final pieColors = [
                        Colors.redAccent,
                        Colors.orangeAccent,
                        Colors.blueAccent,
                        Colors.greenAccent,
                        Colors.purpleAccent,
                        Colors.tealAccent,
                      ];
                      final total = stats.values.fold(0.0, (s, v) => s + v);
                      return Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: stats.entries.toList().asMap().entries.map((indexed) {
                          final index = indexed.key;
                          final entry = indexed.value;
                          final name = _categoryNames[entry.key] ?? '未分类';
                          final percent = total > 0 ? (entry.value / total * 100) : 0.0;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: pieColors[index % pieColors.length],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$name  ¥${entry.value.toStringAsFixed(0)} (${percent.toStringAsFixed(1)}%)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, [Color? color]) {
    final displayColor = color ?? Colors.blue;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: displayColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: displayColor)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: displayColor)),
        ],
      ),
    );
  }

  IconData _getAccountIcon(AccountType type) {
    switch (type) {
      case AccountType.cash: return Icons.money;
      case AccountType.debit: return Icons.credit_card;
      case AccountType.credit: return Icons.credit_score;
      case AccountType.ewallet: return Icons.account_balance_wallet;
      case AccountType.investment: return Icons.trending_up;
      default: return Icons.account_balance;
    }
  }

  Color _getAccountColor(AccountType type) {
    switch (type) {
      case AccountType.cash: return Colors.green;
      case AccountType.debit: return Colors.blue;
      case AccountType.credit: return Colors.orange;
      case AccountType.ewallet: return Colors.purple;
      case AccountType.investment: return Colors.red;
      default: return Colors.grey;
    }
  }
}
