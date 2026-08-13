import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/asset_providers.dart';
import '../models/database.dart';

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(recentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易流水'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: transactions.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('暂无交易记录', style: TextStyle(color: Colors.grey)));
          }

          // 按日期分组
          final grouped = <String, List<Transaction>>{};
          for (final tx in list) {
            final key = DateFormat('yyyy-MM-dd').format(tx.transactionDate);
            grouped.putIfAbsent(key, () => []).add(tx);
          }

          return ListView.builder(
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final date = grouped.keys.elementAt(index);
              final txs = grouped[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          date,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        Text(
                          '支出 ¥${_calculateDayExpense(txs).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 13, color: Colors.red.shade400),
                        ),
                      ],
                    ),
                  ),
                  ...txs.map((tx) => _TransactionTile(transaction: tx)),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('加载失败')),
      ),
    );
  }

  double _calculateDayExpense(List<Transaction> txs) {
    return txs.where((t) => t.type == TransactionType.expense).fold(0.0, (sum, t) => sum + t.amount.abs());
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final isTransfer = transaction.type == TransactionType.transfer;

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        // 这里需要通过provider获取db来删除
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTransfer
              ? Colors.blue.withOpacity(0.15)
              : isExpense
                  ? Colors.red.withOpacity(0.15)
                  : Colors.green.withOpacity(0.15),
          child: Icon(
            isTransfer ? Icons.swap_horiz : isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            color: isTransfer ? Colors.blue : isExpense ? Colors.red : Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          transaction.merchant ?? transaction.description ?? '未命名交易',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${_getCategoryName(transaction.categoryId)} · ${DateFormat('HH:mm').format(transaction.transactionDate)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Text(
          '${isExpense || isTransfer ? '-' : '+'}¥${transaction.amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isTransfer ? Colors.blue : isExpense ? Colors.red : Colors.green,
          ),
        ),
      ),
    );
  }

  String _getCategoryName(String? categoryId) {
    final map = {
      'cat_food': '餐饮',
      'cat_transport': '交通',
      'cat_shopping': '购物',
      'cat_entertainment': '娱乐',
      'cat_housing': '居住',
      'cat_medical': '医疗',
      'cat_education': '教育',
      'cat_salary': '工资',
      'cat_investment': '理财',
      'cat_other_in': '其他',
    };
    return map[categoryId] ?? '未分类';
  }
}
