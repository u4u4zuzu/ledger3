import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/asset_providers.dart';
import '../models/database.dart';
import 'package:drift/drift.dart' show Value;

class AccountManagerScreen extends ConsumerWidget {
  const AccountManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final totalAssets = ref.watch(totalAssetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAccountDialog(context, ref),
          ),
        ],
      ),
      body: accounts.when(
        data: (list) {
          final total = list.fold(0.0, (sum, a) => sum + a.currentBalance);

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('总资产', style: TextStyle(fontSize: 16)),
                    Text(
                      '¥${NumberFormat('#,##0.00').format(total)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final acc = list[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: _buildAccountIcon(acc.type),
                        title: Text(acc.name),
                        subtitle: Text(acc.type.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '¥${NumberFormat('#,##0.00').format(acc.currentBalance)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showEditBalanceDialog(context, ref, acc),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('加载失败')),
      ),
    );
  }

  Widget _buildAccountIcon(AccountType type) {
    final icons = {
      AccountType.cash: (Icons.money, Colors.green),
      AccountType.debit: (Icons.credit_card, Colors.blue),
      AccountType.credit: (Icons.credit_score, Colors.orange),
      AccountType.ewallet: (Icons.account_balance_wallet, Colors.purple),
      AccountType.investment: (Icons.trending_up, Colors.red),
      AccountType.other: (Icons.account_balance, Colors.grey),
    };
    final (icon, color) = icons[type]!;
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.15),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    AccountType selectedType = AccountType.debit;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加账户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '账户名称'),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) => DropdownButton<AccountType>(
                value: selectedType,
                isExpanded: true,
                items: AccountType.values.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.name),
                )).toList(),
                onChanged: (v) => setState(() => selectedType = v!),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final db = ref.read(databaseProvider);
                await db.into(db.accounts).insert(AccountsCompanion(
                  name: Value(nameController.text),
                  type: Value(selectedType),
                  currentBalance: const Value(0),
                ));
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditBalanceDialog(BuildContext context, WidgetRef ref, Account account) {
    final controller = TextEditingController(text: account.currentBalance.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('调整余额 - ${account.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '¥ ', labelText: '当前余额'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final newBalance = double.tryParse(controller.text);
              if (newBalance != null) {
                final db = ref.read(databaseProvider);
                await db.updateAccountBalance(account.id, newBalance);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
