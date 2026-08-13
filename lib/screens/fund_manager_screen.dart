import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../models/database.dart';
import '../providers/asset_providers.dart';
import '../services/fund_api_service.dart';
import '../services/fund_sync_service.dart';

/// 基金持仓扩展数据（计算后的市值、收益、收益率）
class FundPositionData {
  final FundHolding holding;
  final double marketValue;   // 当前市值 = 份额 × 净值
  final double profit;        // 收益金额 = 市值 - 成本
  final double profitRate;    // 收益率 = 收益 / 成本 × 100%

  FundPositionData({
    required this.holding,
    required this.marketValue,
    required this.profit,
    required this.profitRate,
  });
}

class FundManagerScreen extends ConsumerStatefulWidget {
  const FundManagerScreen({super.key});

  @override
  ConsumerState<FundManagerScreen> createState() => _FundManagerScreenState();
}

class _FundManagerScreenState extends ConsumerState<FundManagerScreen> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final funds = db.watchActiveFundHoldings();

    return Scaffold(
      appBar: AppBar(
        title: const Text('基金持仓'),
        actions: [
          IconButton(
            icon: _isRefreshing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sync),
            onPressed: _isRefreshing ? null : _refreshAllNavs,
          ),
        ],
      ),
      body: StreamBuilder<List<FundHolding>>(
        stream: funds,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data!;
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无基金持仓', style: TextStyle(color: Colors.grey)),
                  Text('点击右下角添加', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          // 计算汇总数据
          final positions = list.map((h) => _calculatePosition(h)).toList();
          final totalCost = positions.fold(0.0, (sum, p) => sum + p.holding.totalCost);
          final totalMarket = positions.fold(0.0, (sum, p) => sum + p.marketValue);
          final totalProfit = totalMarket - totalCost;
          final totalProfitRate = totalCost > 0 ? (totalProfit / totalCost) * 100 : 0;

          return Column(
            children: [
              // 汇总卡片
              _buildSummaryCard(totalCost,totalMarket,totalProfit,(totalProfitRate as num).toDouble()),

              // 基金列表
              Expanded(
                child: ListView.builder(
                  itemCount: positions.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    return _FundPositionCard(
                      data: positions[index],
                      onAdd: () => _showAddPositionDialog(positions[index].holding),
                      onReduce: () => _showReducePositionDialog(positions[index].holding),
                      onDelete: () => _deleteFund(positions[index].holding),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewFundDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 计算持仓数据
  FundPositionData _calculatePosition(FundHolding holding) {
    final marketValue = holding.totalShares * holding.lastNav;
    final profit = marketValue - holding.totalCost;
    final profitRate = holding.totalCost > 0 ? (profit / holding.totalCost) * 100 : 0;

    return FundPositionData(
      holding: holding,
      marketValue: marketValue,
      profit: profit,
      profitRate: (profitRate as num).toDouble(),
    );
  }

  Widget _buildSummaryCard(double cost, double market, double profit, double rate) {
    final isProfit = profit >= 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit 
            ? [const Color(0xFF2C3E50), const Color(0xFF27AE60)]
            : [const Color(0xFF2C3E50), const Color(0xFFE74C3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('基金总资产', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '¥${market.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('总成本', '¥${cost.toStringAsFixed(2)}', Colors.white70),
              ),
              Expanded(
                child: _buildSummaryItem(
                  '累计收益',
                  '${isProfit ? "+" : ""}¥${profit.toStringAsFixed(2)}',
                  isProfit ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  '收益率',
                  '${isProfit ? "+" : ""}${rate.toStringAsFixed(2)}%',
                  isProfit ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// 刷新所有基金净值
  Future<void> _refreshAllNavs() async {
    setState(() => _isRefreshing = true);

    final db = ref.read(databaseProvider);
    final syncService = FundSyncService(db);
    await syncService.syncAllFundNavs();

    setState(() => _isRefreshing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('净值已刷新，投资账户已同步')),
      );
    }
  }

  /// 新建基金持仓（只输入金额，自动获取名称和净值）
  void _showNewFundDialog() {
    final codeController = TextEditingController();
    final costController = TextEditingController();
    String? selectedAccountId;
    String? fetchedFundName;  // ← 自动获取的基金名称

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加基金持仓'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: '基金代码', hintText: '如: 005827'),
                onChanged: (value) async {
                  // 输入6位代码后自动获取名称
                  final code = value.trim();
                  if (code.length >= 6) {
                    final info = await FundApiService.fetchFundInfo(code);
                    if (info != null && mounted) {
                      setState(() {
                        fetchedFundName = info['name'] as String;
                      });
                    }
                  }
                },
              ),
              // 显示自动获取的基金名称
              if (fetchedFundName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    fetchedFundName!,
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '投入金额(元)'),
              ),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, _) {
                  final accounts = ref.watch(accountsProvider);
                  return accounts.when(
                    data: (list) => DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: '关联投资账户'),
                      items: list
                          .where((a) => a.type == AccountType.investment)
                          .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                          .toList(),
                      onChanged: (v) => selectedAccountId = v,
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('加载失败'),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final code = codeController.text.trim();
              final cost = double.tryParse(costController.text);

              if (code.isEmpty || cost == null || cost <= 0 || selectedAccountId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写完整信息'))
                );
                return;
              }

              final db = ref.read(databaseProvider);
              try {
                // 如果没自动获取到名称，再查一次
                String fundName = fetchedFundName ?? code;
                if (fundName == code) {
                  final info = await FundApiService.fetchFundInfo(code);
                  fundName = info?['name'] as String? ?? code;
                }

                await db.addFundPositionByAmount(
                  code,
                  fundName,  // ✅ 传入真实基金名称
                  cost,
                  selectedAccountId!,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('添加成功: $fundName')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('添加失败: $e')),
                  );
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  /// 加仓（只输入金额，份额自动计算）
  void _showAddPositionDialog(FundHolding holding) {
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('加仓 - ${holding.fundName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前持仓: ${holding.totalShares.toStringAsFixed(2)} 份'),
            Text('当前成本: ¥${holding.totalCost.toStringAsFixed(2)}'),
            Text('最新净值: ${holding.lastNav.toStringAsFixed(4)}'),
            const SizedBox(height: 16),
            // ✅ 只保留金额输入
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '加仓金额(元)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final cost = double.tryParse(costController.text);
              if (cost == null || cost <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效金额')),
                );
                return;
              }

              final db = ref.read(databaseProvider);
              try {
                // ✅ 改用按金额加仓
                await db.addFundPositionByAmount(
                  holding.fundCode,
                  holding.fundName,
                  cost,
                  holding.accountId,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('加仓成功，份额已自动计算')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('加仓失败: $e')),
                  );
                }
              }
            },
            child: const Text('确认加仓'),
          ),
        ],
      ),
    );
  }

  /// 减仓（只输入金额，份额自动计算）
  void _showReducePositionDialog(FundHolding holding) {
    final amountController = TextEditingController();
    final maxAmount = holding.totalShares * holding.lastNav;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('减仓 - ${holding.fundName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前持仓: ${holding.totalShares.toStringAsFixed(2)} 份'),
            Text('当前净值: ${holding.lastNav.toStringAsFixed(4)}'),
            Text('可卖市值: ¥${maxAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            // ✅ 只保留金额输入
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '卖出金额(元)',
                hintText: '最多 ¥${maxAmount.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效金额')),
                );
                return;
              }

              final db = ref.read(databaseProvider);
              try {
                // ✅ 改用按金额减仓
                await db.reduceFundPositionByAmount(
                  holding.fundCode,
                  amount,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('减仓成功')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('减仓失败: $e')),
                  );
                }
              }
            },
            child: const Text('确认减仓'),
          ),
        ],
      ),
    );
  }

  /// 删除持仓
  void _deleteFund(FundHolding holding) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除持仓'),
        content: Text('确定删除 ${holding.fundName} 的持仓记录吗？\n此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.deleteFundHolding(holding.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 基金持仓卡片
class _FundPositionCard extends StatelessWidget {
  final FundPositionData data;
  final VoidCallback onAdd;
  final VoidCallback onReduce;
  final VoidCallback onDelete;

  const _FundPositionCard({
    required this.data,
    required this.onAdd,
    required this.onReduce,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final h = data.holding;
    final isProfit = data.profit >= 0;
    final profitColor = isProfit ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.fundName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        h.fundCode,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: profitColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${isProfit ? "+" : ""}${data.profitRate.toStringAsFixed(2)}%',
                    style: TextStyle(color: profitColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // 数据行
            Row(
              children: [
                _buildDataItem('持有份额', '${h.totalShares.toStringAsFixed(2)}'),
                _buildDataItem('当前净值', h.lastNav.toStringAsFixed(4)),
                _buildDataItem('当前市值', '¥${data.marketValue.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDataItem('总成本', '¥${h.totalCost.toStringAsFixed(2)}'),
                _buildDataItem('收益金额', '${isProfit ? "+" : ""}¥${data.profit.toStringAsFixed(2)}', color: profitColor),
              ],
            ),
            const SizedBox(height: 12),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('加仓'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReduce,
                    icon: const Icon(Icons.remove, size: 16),
                    label: const Text('减仓'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataItem(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
