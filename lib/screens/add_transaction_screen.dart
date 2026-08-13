import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/database.dart';
import '../providers/asset_providers.dart';
import 'package:drift/drift.dart' show Value;

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  TransactionType _type = TransactionType.expense;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String? _toAccountId; // 转账目标账户
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔'),
        actions: [
          TextButton(
            onPressed: _saveTransaction,
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型切换
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(value: TransactionType.expense, label: Text('支出')),
                ButtonSegment(value: TransactionType.income, label: Text('收入')),
                ButtonSegment(value: TransactionType.transfer, label: Text('转账')),
              ],
              selected: {_type},
              onSelectionChanged: (set) => setState(() => _type = set.first),
            ),
            const SizedBox(height: 24),

            // 金额输入
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '¥ ',
                prefixStyle: TextStyle(fontSize: 32, color: _type == TransactionType.expense ? Colors.red : Colors.green),
                border: InputBorder.none,
                hintText: '0.00',
                hintStyle: TextStyle(fontSize: 32, color: Colors.grey.shade400),
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),

            // 账户选择
            accounts.when(
              data: (list) => Column(
                children: [
                  _buildDropdown(
                    label: _type == TransactionType.transfer ? '转出账户' : '账户',
                    value: _selectedAccountId,
                    items: list.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                  ),
                  if (_type == TransactionType.transfer)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildDropdown(
                        label: '转入账户',
                        value: _toAccountId,
                        items: list.where((a) => a.id != _selectedAccountId).map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                        onChanged: (v) => setState(() => _toAccountId = v),
                      ),
                    ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('加载失败'),
            ),
            const SizedBox(height: 16),

            // 分类选择（非转账）
            if (_type != TransactionType.transfer)
              _buildCategorySelector(),

            // 商户
            TextField(
              controller: _merchantController,
              decoration: const InputDecoration(
                labelText: '商户/对方',
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 12),

            // 备注
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // 日期选择
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('日期'),
              trailing: Text(DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          hint: Text('选择$label'),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      {'id': 'cat_food', 'name': '餐饮', 'icon': '🍔'},
      {'id': 'cat_transport', 'name': '交通', 'icon': '🚗'},
      {'id': 'cat_shopping', 'name': '购物', 'icon': '🛍️'},
      {'id': 'cat_entertainment', 'name': '娱乐', 'icon': '🎮'},
      {'id': 'cat_housing', 'name': '居住', 'icon': '🏠'},
      {'id': 'cat_medical', 'name': '医疗', 'icon': '💊'},
      {'id': 'cat_education', 'name': '教育', 'icon': '📚'},
      {'id': 'cat_salary', 'name': '工资', 'icon': '💰'},
      {'id': 'cat_investment', 'name': '理财', 'icon': '📈'},
      {'id': 'cat_other_in', 'name': '其他', 'icon': '💵'},
    ].where((c) {
      if (_type == TransactionType.expense) {
        return !['cat_salary', 'cat_investment', 'cat_other_in'].contains(c['id']);
      } else {
        return ['cat_salary', 'cat_investment', 'cat_other_in'].contains(c['id']);
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('分类', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final isSelected = _selectedCategoryId == cat['id'];
            return ChoiceChip(
              label: Text('${cat['icon']} ${cat['name']}'),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategoryId = cat['id']),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择账户')));
      return;
    }
    if (_type == TransactionType.transfer && _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择转入账户')));
      return;
    }

    final db = ref.read(databaseProvider);

    final tx = TransactionsCompanion(
      accountId: Value(_selectedAccountId!),
      toAccountId: Value(_toAccountId),
      amount: Value(_type == TransactionType.expense ? -amount : amount),
      type: Value(_type),
      categoryId: Value(_selectedCategoryId),
      merchant: Value(_merchantController.text.isEmpty ? null : _merchantController.text),
      description: Value(_descController.text.isEmpty ? null : _descController.text),
      transactionDate: Value(_selectedDate),
      source: const Value('manual'),
    );

    await db.addTransaction(tx);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('记账成功'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
