import 'package:drift/drift.dart';
import '../models/database.dart';

class PaymentNotification {
  final String source;
  final String type;
  final double amount;
  final String merchant;
  final int timestamp;

  PaymentNotification({
    required this.source,
    required this.type,
    required this.amount,
    required this.merchant,
    required this.timestamp,
  });
}

class NotificationService {
  /// 处理支付通知，自动去重并添加交易
  static Future<Transaction?> handlePaymentNotification(
    PaymentNotification notification,
    AppDatabase db,
  ) async {
    final isExpense = notification.type == 'expense' || notification.type == 'transfer_out';
    final amount = notification.amount.abs();

    // 去重检查（5分钟内相同金额）
    final isDup = await _isDuplicateTransaction(db, amount);
    if (isDup) {
      print('⏭️ 跳过重复交易: ${notification.merchant} ¥$amount');
      return null;
    }

    final accountId = _getDefaultAccountId(notification.source);

    final tx = await db.addTransaction(TransactionsCompanion(
      accountId: Value(accountId),
      amount: Value(isExpense ? -amount : amount),
      type: Value(isExpense ? TransactionType.expense : TransactionType.income),
      categoryId: Value(isExpense ? 'cat_shopping' : 'cat_other_in'),
      merchant: Value(notification.merchant),
      description: Value('${notification.source}自动记账'),
      source: Value('auto_${notification.source}'),
      transactionDate: Value(DateTime.now()),
      createdAt: Value(DateTime.now()),
    ));

    print('✅ 自动记账成功 [${notification.source}] ¥$amount');
    return tx;
  }

  static Future<bool> _isDuplicateTransaction(AppDatabase db, double amount, {int minutes = 5}) async {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    final normalizedAmount = (amount * 100).round() / 100;
    
    final recent = await (db.select(db.transactions)
      ..where((t) => t.amount.equals(normalizedAmount))
      ..where((t) => t.createdAt.isBiggerThanValue(cutoff))
      ..where((t) => t.isDeleted.equals(false))
      ..limit(1))
      .getSingleOrNull();
      
    return recent != null;
  }

  static String _getDefaultAccountId(String source) {
    switch (source) {
      case 'wechat': return 'acc_wechat';
      case 'alipay': return 'acc_alipay';
      case 'cmb': return 'acc_cmb';
      case 'icbc': return 'acc_icbc';
      case 'ccb': return 'acc_ccb';
      case 'abc': return 'acc_abc';
      case 'boc': return 'acc_boc';
      case 'comm': return 'acc_comm';
      default: return 'acc_cash';
    }
  }
}
