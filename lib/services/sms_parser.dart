import 'dart:convert';

/// 银行短信解析器
class SmsParser {
  /// 银行短信模板库
  static final Map<String, BankSmsPattern> _patterns = {
    'ICBC': BankSmsPattern(
      bankName: '工商银行',
      expenseRegExp: RegExp(r'您尾号(\d+)卡(\d+月\d+日)\d+:\d+支出\(([^)]+)\)([\d,]+\.\d{2})元，余额([\d,]+\.\d{2})元'),
      incomeRegExp: RegExp(r'您尾号(\d+)卡(\d+月\d+日)\d+:\d+收入\(([^)]+)\)([\d,]+\.\d{2})元，余额([\d,]+\.\d{2})元'),
      groupMapping: {'cardTail': 1, 'date': 2, 'merchant': 3, 'amount': 4, 'balance': 5},
    ),
    'CCB': BankSmsPattern(
      bankName: '建设银行',
      expenseRegExp: RegExp(r'您尾号(\d+)的储蓄卡账户(\d+月\d+日)\d+:\d+消费支出人民币([\d,]+\.\d{2})元,活期余额([\d,]+\.\d{2})元'),
      groupMapping: {'cardTail': 1, 'date': 2, 'amount': 3, 'balance': 4},
    ),
    'ABC': BankSmsPattern(
      bankName: '农业银行',
      expenseRegExp: RegExp(r'您尾号(\d+)账户(\d+月\d+日)\d+:\d+完成一笔([\d,]+\.\d{2})元支付交易，余额([\d,]+\.\d{2})元'),
      groupMapping: {'cardTail': 1, 'date': 2, 'amount': 3, 'balance': 4},
    ),
    'BOC': BankSmsPattern(
      bankName: '中国银行',
      expenseRegExp: RegExp(r'您账户(\d+)于(\d+月\d+日)支出人民币([\d,]+\.\d{2})元，交易后余额([\d,]+\.\d{2})元'),
      groupMapping: {'cardTail': 1, 'date': 2, 'amount': 3, 'balance': 4},
    ),
    'CMB': BankSmsPattern(
      bankName: '招商银行',
      expenseRegExp: RegExp(r'您账户(\d+)于\d+年\d+月\d+日\d+:\d+支出([\d,]+\.\d{2})元.*?余额([\d,]+\.\d{2})元'),
      groupMapping: {'cardTail': 1, 'amount': 2, 'balance': 3},
    ),
    'COMM': BankSmsPattern(
      bankName: '交通银行',
      expenseRegExp: RegExp(r'您尾号(\d+)的卡(\d+月\d+日)\d+:\d+支出([\d,]+\.\d{2})元，可用余额([\d,]+\.\d{2})元'),
      groupMapping: {'cardTail': 1, 'date': 2, 'amount': 3, 'balance': 4},
    ),
  };

  /// 识别银行代码
  static String? identifyBank(String sender) {
    final upper = sender.toUpperCase();
    if (upper.contains('95588') || upper.contains('ICBC')) return 'ICBC';
    if (upper.contains('95533') || upper.contains('CCB')) return 'CCB';
    if (upper.contains('95599') || upper.contains('ABC')) return 'ABC';
    if (upper.contains('95566') || upper.contains('BOC')) return 'BOC';
    if (upper.contains('95555') || upper.contains('CMB')) return 'CMB';
    if (upper.contains('95559') || upper.contains('COMM')) return 'COMM';
    return null;
  }

  /// 解析短信
  static SmsTransaction? parse(String sender, String body) {
    final bankCode = identifyBank(sender);
    if (bankCode == null) return null;

    final pattern = _patterns[bankCode];
    if (pattern == null) return null;

    // 先尝试匹配支出
    var match = pattern.expenseRegExp?.firstMatch(body);
    bool isExpense = true;

    if (match == null && pattern.incomeRegExp != null) {
      match = pattern.incomeRegExp!.firstMatch(body);
      isExpense = false;
    }

    if (match == null) return null;

    final map = pattern.groupMapping;

    return SmsTransaction(
      bankCode: bankCode,
      bankName: pattern.bankName,
      cardTail: match.group(map['cardTail'] ?? 1) ?? '',
      amount: double.parse((match.group(map['amount'] ?? 3) ?? '0').replaceAll(',', '')),
      balanceAfter: double.parse((match.group(map['balance'] ?? 4) ?? '0').replaceAll(',', '')),
      merchant: map.containsKey('merchant') ? match.group(map['merchant']) : null,
      isExpense: isExpense,
      rawText: body,
      timestamp: DateTime.now(),
    );
  }
}

class BankSmsPattern {
  final String bankName;
  final RegExp? expenseRegExp;
  final RegExp? incomeRegExp;
  final Map<String, int> groupMapping;

  BankSmsPattern({
    required this.bankName,
    this.expenseRegExp,
    this.incomeRegExp,
    required this.groupMapping,
  });
}

class SmsTransaction {
  final String bankCode;
  final String bankName;
  final String cardTail;
  final double amount;
  final double balanceAfter;
  final String? merchant;
  final bool isExpense;
  final String rawText;
  final DateTime timestamp;

  SmsTransaction({
    required this.bankCode,
    required this.bankName,
    required this.cardTail,
    required this.amount,
    required this.balanceAfter,
    this.merchant,
    required this.isExpense,
    required this.rawText,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'bankCode': bankCode,
    'bankName': bankName,
    'cardTail': cardTail,
    'amount': amount,
    'balanceAfter': balanceAfter,
    'merchant': merchant,
    'isExpense': isExpense,
    'rawText': rawText,
    'timestamp': timestamp.toIso8601String(),
  };
}
