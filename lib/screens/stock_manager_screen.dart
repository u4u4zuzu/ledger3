import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../models/database.dart';
import '../providers/asset_providers.dart';
import '../services/stock_api_service.dart';
import '../services/stock_sync_service.dart';

/// 股票持仓扩展数据（计算后的市值、收益、收益率）
class StockPositionData {
  final StockHolding holding;
  final double marketValue;   // 当前市值 = 股数 × 价格
  final double profit;        // 收益金额 = 市值 - 成本
  final double profitRate;    // 收益率 = 收益 / 成本 × 100%

  StockPositionData({
    required this.holding,
    required this.marketValue,
    required this.profit,
    required this.profitRate,
  });
}

class StockManagerScreen extends ConsumerStatefulWidget {
  const StockManagerScreen({super.key});

  @override
  ConsumerState<StockManagerScreen> createState() => _StockManagerScreenState();
}

class _StockManagerScreenState extends ConsumerState<StockManagerScreen> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final stocks = db.watchActiveStockHoldings();

    return Scaffold(
      appBar: AppBar(
        title: const Text('股票持仓'),
        actions: [
          IconButton(
            icon: _isRefreshing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sync),
            onPressed: _isRefreshing ? null : _refreshAllPrices,
          ),
        ],
      ),
      body: StreamBuilder<List<StockHolding>>(
        stream: stocks,
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
                  Icon(Icons.show_chart, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无股票持仓', style: TextStyle(color: Colors.grey)),
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
              _buildSummaryCard(totalCost, totalMarket, totalProfit, (totalProfitRate as num).toDouble()),

              // 股票列表
              Expanded(
                child: ListView.builder(
                  itemCount: positions.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    return _StockPositionCard(
                      data: positions[index],
                      onAdd: () => _showAddPositionDialog(positions[index].holding),
                      onReduce: () => _showReducePositionDialog(positions[index].holding),
                      onDelete: () => _deleteStock(positions[index].holding),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewStockDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 计算持仓数据
  StockPositionData _calculatePosition(StockHolding holding) {
    final marketValue = holding.totalShares * holding.lastPrice;
    final profit = marketValue - holding.totalCost;
    final profitRate = holding.totalCost > 0 ? (profit / holding.totalCost) * 100 : 0;

    return StockPositionData(
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
          const Text('股票总资产', style: TextStyle(color: Colors.white70, fontSize: 14)),
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

  /// 刷新所有股票价格
  Future<void> _refreshAllPrices() async {
    setState(() => _isRefreshing = true);

    final db = ref.read(databaseProvider);
    final syncService = StockSyncService(db);
    await syncService.syncAllStockPrices();

    setState(() => _isRefreshing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('价格已刷新，投资账户已同步')),
      );
    }
  }

  /// 新建股票持仓（只输入金额，自动获取名称和价格）
  void _showNewStockDialog() {
    final codeController = TextEditingController();
    final costController = TextEditingController();
    String? selectedAccountId;
    String? fetchedStockName;  // ← 自动获取的股票名称

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加股票持仓'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: '股票代码', hintText: '如: 600519'),
                onChanged: (value) async {
                  // 输入6位代码后自动获取名称
                  final code = value.trim();
                  if (code.length >= 6) {
                    final info = await StockApiService.fetchStockInfo(code);
                    if (info != null && mounted) {
                      setState(() {
                        fetchedStockName = info['name'] as String;
                      });
                    }
                  }
                },
              ),
              // 显示自动获取的股票名称
              if (fetchedStockName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    fetchedStockName!,
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
                String stockName = fetchedStockName ?? code;
                if (stockName == code) {
                  final info = await StockApiService.fetchStockInfo(code);
                  stockName = info?['name'] as String? ?? code;
                }

                await db.addStockPositionByAmount(
                  code,
                  stockName,  // ✅ 传入真实股票名称
                  cost,
                  selectedAccountId!,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('添加成功: $stockName')),
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

  /// 加仓（只输入金额，股数自动计算）
  void _showAddPositionDialog(StockHolding holding) {
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('加仓 - ${holding.stockName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前持仓: ${holding.totalShares.toStringAsFixed(2)} 股'),
            Text('当前成本: ¥${holding.totalCost.toStringAsFixed(2)}'),
            Text('最新价格: ${holding.lastPrice.toStringAsFixed(2)}'),
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
                await db.addStockPositionByAmount(
                  holding.stockCode,
                  holding.stockName,
                  cost,
                  holding.accountId,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('加仓成功，股数已自动计算')),
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

  /// 减仓（只输入金额，股数自动计算）
  void _showReducePositionDialog(StockHolding holding) {
    final amountController = TextEditingController();
    final maxAmount = holding.totalShares * holding.lastPrice;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('减仓 - ${holding.stockName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前持仓: ${holding.totalShares.toStringAsFixed(2)} 股'),
            Text('当前价格: ${holding.lastPrice.toStringAsFixed(2)}'),
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
                await db.reduceStockPositionByAmount(
                  holding.stockCode,
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
  void _deleteStock(StockHolding holding) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除持仓'),
        content: Text('确定删除 ${holding.stockName} 的持仓记录吗？\n此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.deleteStockHolding(holding.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 股票持仓卡片
class _StockPositionCard extends StatelessWidget {
  final StockPositionData data;
  final VoidCallback onAdd;
  final VoidCallback onReduce;
  final VoidCallback onDelete;

  const _StockPositionCard({
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
                        h.stockName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        h.stockCode,
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
                _buildDataItem('持有股数', '${h.totalShares.toStringAsFixed(2)}'),
                _buildDataItem('当前价格', h.lastPrice.toStringAsFixed(2)),
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
