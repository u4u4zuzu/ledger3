import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../services/fund_api_service.dart';  // ← 新增，用于基金按金额加仓/减仓
import '../services/stock_api_service.dart';  // ← 新增，用于股票按金额加仓/减仓

part 'database.g.dart';


// ==================== 枚举定义 ====================
enum AccountType { cash, debit, credit, ewallet, investment, other }
enum TransactionType { expense, income, transfer }

// ==================== 账户表 ====================
class Accounts extends Table {
  TextColumn get id => text().clientDefault(() => DateTime.now().millisecondsSinceEpoch.toString() + '_' + (1000 + DateTime.now().microsecond).toString())();
  TextColumn get name => text()();
  TextColumn get type => text().map(const AccountTypeConverter())();
  RealColumn get initialBalance => real().withDefault(const Constant(0))();
  RealColumn get currentBalance => real().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class AccountTypeConverter extends TypeConverter<AccountType, String> {
  const AccountTypeConverter();
  @override
  AccountType fromSql(String fromDb) => AccountType.values.byName(fromDb);
  @override
  String toSql(AccountType value) => value.name;
}

// ==================== 交易流水表 ====================
class Transactions extends Table {
  TextColumn get id => text().clientDefault(() => DateTime.now().millisecondsSinceEpoch.toString() + '_' + (1000 + DateTime.now().microsecond).toString())();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get toAccountId => text().references(Accounts, #id).nullable()();
  RealColumn get amount => real()();
  TextColumn get type => text().map(const TransactionTypeConverter())();
  TextColumn get categoryId => text().nullable()();
  TextColumn get merchant => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  DateTimeColumn get transactionDate => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionTypeConverter extends TypeConverter<TransactionType, String> {
  const TransactionTypeConverter();
  @override
  TransactionType fromSql(String fromDb) => TransactionType.values.byName(fromDb);
  @override
  String toSql(TransactionType value) => value.name;
}

// ==================== 分类表 ====================
class Categories extends Table {
  TextColumn get id => text().clientDefault(() => DateTime.now().millisecondsSinceEpoch.toString())();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get type => text().map(const TransactionTypeConverter())();
  TextColumn get icon => text().nullable()();
  IntColumn get color => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== 基金持仓表（合并持仓） ====================
/// 每只基金只保留一条记录，加仓减仓更新此记录
class FundHoldings extends Table {
  TextColumn get id => text().clientDefault(() => DateTime.now().millisecondsSinceEpoch.toString() + '_' + (1000 + DateTime.now().microsecond).toString())();
  TextColumn get fundCode => text()();           // 基金代码，如 005827
  TextColumn get fundName => text()();           // 基金名称
  RealColumn get totalShares => real()();        // 总持有份额（加仓增加，减仓减少）
  RealColumn get totalCost => real()();          // 总成本金额（加仓增加，减仓按比例减少）
  RealColumn get lastNav => real().withDefault(const Constant(0))();  // 最新单位净值
  TextColumn get accountId => text().references(Accounts, #id)();   // 关联投资账户
  DateTimeColumn get lastUpdate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== 基金交易记录表（加仓/减仓流水） ====================
class FundTransactions extends Table {
  TextColumn get id => text().clientDefault(() => DateTime.now().millisecondsSinceEpoch.toString())();
  TextColumn get fundCode => text()();           // 基金代码
  TextColumn get fundName => text()();           // 基金名称
  TextColumn get operation => text()();          // buy(加仓) / sell(减仓)
  RealColumn get shares => real()();             // 份额
  RealColumn get amount => real()();             // 金额（加仓为正，减仓记录卖出金额）
  RealColumn get nav => real()();                // 交易时的净值
  DateTimeColumn get tradeDate => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== 股票持仓表（合并持仓） ====================
/// 每只股票只保留一条记录，加仓减仓更新此记录
class StockHoldings extends Table {
  TextColumn get id => text().clientDefault(() => DateTime.now().millisecondsSinceEpoch.toString() + '_' + (1000 + DateTime.now().microsecond).toString())();
  TextColumn get stockCode => text()();           // 股票代码，如 600519
  TextColumn get stockName => text()();           // 股票名称
  RealColumn get totalShares => real()();        // 总持有股数（加仓增加，减仓减少）
  RealColumn get totalCost => real()();          // 总成本金额（加仓增加，减仓按比例减少）
  RealColumn get lastPrice => real().withDefault(const Constant(0))();  // 最新价格
  TextColumn get accountId => text().references(Accounts, #id)();   // 关联投资账户
  DateTimeColumn get lastUpdate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== 股票交易记录表（加仓/减仓流水） ====================
class StockTransactions extends Table {
  TextColumn get id => text().clientDefault(() => DateTime.now().millisecondsSinceEpoch.toString())();
  TextColumn get stockCode => text()();           // 股票代码
  TextColumn get stockName => text()();           // 股票名称
  TextColumn get operation => text()();           // buy(加仓) / sell(减仓)
  RealColumn get shares => real()();              // 股数
  RealColumn get amount => real()();              // 金额（加仓为正，减仓记录卖出金额）
  RealColumn get price => real()();               // 交易时的价格
  DateTimeColumn get tradeDate => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== 数据库类 ====================
@DriftDatabase(tables: [Accounts, Transactions, Categories, FundHoldings, FundTransactions, StockHoldings, StockTransactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await batch((batch) {
        batch.insertAll(categories, [
          CategoriesCompanion.insert(id: Value('cat_food'), name: '餐饮', type: TransactionType.expense, icon: Value('🍔'), color: Value(0xFFFF6B6B)),
          CategoriesCompanion.insert(id: Value('cat_transport'), name: '交通', type: TransactionType.expense, icon: Value('🚗'), color: Value(0xFF4ECDC4)),
          CategoriesCompanion.insert(id: Value('cat_shopping'), name: '购物', type: TransactionType.expense, icon: Value('🛍️'), color: Value(0xFFFFE66D)),
          CategoriesCompanion.insert(id: Value('cat_entertainment'), name: '娱乐', type: TransactionType.expense, icon: Value('🎮'), color: Value(0xFF9B59B6)),
          CategoriesCompanion.insert(id: Value('cat_housing'), name: '居住', type: TransactionType.expense, icon: Value('🏠'), color: Value(0xFF3498DB)),
          CategoriesCompanion.insert(id: Value('cat_medical'), name: '医疗', type: TransactionType.expense, icon: Value('💊'), color: Value(0xFFE74C3C)),
          CategoriesCompanion.insert(id: Value('cat_education'), name: '教育', type: TransactionType.expense, icon: Value('📚'), color: Value(0xFF2ECC71)),
          CategoriesCompanion.insert(id: Value('cat_salary'), name: '工资', type: TransactionType.income, icon: Value('💰'), color: Value(0xFF27AE60)),
          CategoriesCompanion.insert(id: Value('cat_investment'), name: '理财收益', type: TransactionType.income, icon: Value('📈'), color: Value(0xFFF39C12)),
          CategoriesCompanion.insert(id: Value('cat_other_in'), name: '其他收入', type: TransactionType.income, icon: Value('💵'), color: Value(0xFF95A5A6)),
        ]);
        batch.insertAll(accounts, [
          AccountsCompanion.insert(id: Value('acc_cash'), name: '现金', type: AccountType.cash, currentBalance: Value(0)),
          AccountsCompanion.insert(id: Value('acc_alipay'), name: '支付宝', type: AccountType.ewallet, currentBalance: Value(0)),
          AccountsCompanion.insert(id: Value('acc_wechat'), name: '微信支付', type: AccountType.ewallet, currentBalance: Value(0)),
          AccountsCompanion.insert(id: Value('acc_bank'), name: '银行卡', type: AccountType.debit, currentBalance: Value(0)),
          AccountsCompanion.insert(id: Value('acc_credit'), name: '信用卡', type: AccountType.credit, currentBalance: Value(0)),
          AccountsCompanion.insert(id: Value('acc_invest'), name: '投资账户', type: AccountType.investment, currentBalance: Value(0)),
        ]);
      });
    },
    onUpgrade: (m, from, to) async {
      // 从旧版本升级：创建股票相关表
      if (from < 2) {
        await m.createTable(stockHoldings);
        await m.createTable(stockTransactions);
      }
    },
  );

  // ==================== 账户方法 ====================

  Future<List<Account>> getAllAccounts() => 
      (select(accounts)..where((a) => a.isArchived.equals(false))..orderBy([(a) => OrderingTerm(expression: a.sortOrder)])).get();

  Stream<List<Account>> watchAllAccounts() =>
      (select(accounts)..where((a) => a.isArchived.equals(false))..orderBy([(a) => OrderingTerm(expression: a.sortOrder)])).watch();
  
  Future<double> getTotalAssets() async {
    final result = await customSelect(
      'SELECT SUM(current_balance) as total FROM accounts WHERE is_archived = 0',
    ).getSingle();
    return result.read<double>('total') ?? 0.0;
  }

  Stream<double> watchTotalAssets() {
    return select(accounts).watch().map((list) => 
      list.where((a) => !a.isArchived).fold(0.0, (sum, a) => sum + a.currentBalance));
  }

  Stream<List<Transaction>> watchTodayTransactions() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    return (select(transactions)
      ..where((t) => t.transactionDate.isBetweenValues(start, end))
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)]))
      .watch();
  }

    /// 按月查询交易（用于本月统计）
  Stream<List<Transaction>> watchMonthlyTransactions(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    return (select(transactions)
      ..where((t) => t.transactionDate.isBetweenValues(start, end))
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)]))
      .watch();
  }

  Stream<List<Transaction>> watchRecentTransactions({int limit = 50}) {
    return (select(transactions)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)])
      ..limit(limit))
      .watch();
  }

  Future<Map<String, double>> getMonthlyStats(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    final expenseResult = await customSelect(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND transaction_date >= ? AND transaction_date < ? AND is_deleted = 0',
      variables: [Variable('expense'), Variable(start), Variable(end)],
    ).getSingle();

    final incomeResult = await customSelect(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND transaction_date >= ? AND transaction_date < ? AND is_deleted = 0',
      variables: [Variable('income'), Variable(start), Variable(end)],
    ).getSingle();

    return {
      'expense': (expenseResult.read<double>('total') ?? 0.0).abs(),
      'income': incomeResult.read<double>('total') ?? 0.0,
    };
  }

  Future<Transaction> addTransaction(TransactionsCompanion tx) async {
    return transaction(() async {
      final inserted = await into(transactions).insertReturning(tx);
      
      // 统一取绝对值，避免符号不一致
      final amount = (tx.amount.value ?? 0).abs();

      if (tx.type.value == TransactionType.transfer && tx.toAccountId.value != null) {
        await _updateBalance(tx.accountId.value, -amount);
        await _updateBalance(tx.toAccountId.value!, amount);
      } else if (tx.type.value == TransactionType.expense) {
        await _updateBalance(tx.accountId.value, -amount);  // 支出扣钱
      } else if (tx.type.value == TransactionType.income) {
        await _updateBalance(tx.accountId.value, amount);    // 收入加钱
      }

      return inserted;
    });
  }

  Future<void> _updateBalance(String accountId, double delta) async {
    final account = await (select(accounts)..where((a) => a.id.equals(accountId))).getSingle();
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(
        currentBalance: Value(account.currentBalance + delta),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
  
  Future<void> deleteTransaction(String id) async {
    final tx = await (select(transactions)..where((t) => t.id.equals(id))).getSingle();

    await transaction(() async {
      final amount = tx.amount.abs();

      if (tx.type == TransactionType.transfer && tx.toAccountId != null) {
        await _updateBalance(tx.accountId, amount);
        await _updateBalance(tx.toAccountId!, -amount);
      } else if (tx.type == TransactionType.expense) {
        await _updateBalance(tx.accountId, amount);       // 支出的钱加回来
      } else if (tx.type == TransactionType.income) {
        await _updateBalance(tx.accountId, -amount);      // 收入的钱扣回去
      }

      await (update(transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(isDeleted: const Value(true), updatedAt: Value(DateTime.now())),
      );
    });
  }

  Future<void> updateAccountBalance(String accountId, double newBalance) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(currentBalance: Value(newBalance), updatedAt: Value(DateTime.now())),
    );
  }

  // ==================== 基金方法 ====================

  /// 获取所有活跃基金持仓（按基金代码合并，每只基金一条记录）
  Future<List<FundHolding>> getActiveFundHoldings() =>
      (select(fundHoldings)..where((f) => f.isActive.equals(true))..orderBy([(f) => OrderingTerm(expression: f.fundCode)])).get();

  Stream<List<FundHolding>> watchActiveFundHoldings() =>
      (select(fundHoldings)..where((f) => f.isActive.equals(true))..orderBy([(f) => OrderingTerm(expression: f.fundCode)])).watch();

  /// 根据基金代码查找持仓（用于合并）
  Future<FundHolding?> findFundByCode(String fundCode) async {
    return await (select(fundHoldings)
      ..where((f) => f.fundCode.equals(fundCode))
      ..where((f) => f.isActive.equals(true)))
      .getSingleOrNull();
  }

  /// 加仓：合并到现有持仓或新建
  Future<void> addFundPosition(String fundCode, String fundName, double shares, double cost, String accountId, {double? nav}) async {
    await transaction(() async {
      final existing = await findFundByCode(fundCode);

      if (existing != null) {
        // 已存在，合并持仓
        final newShares = existing.totalShares + shares;
        final newCost = existing.totalCost + cost;

        await (update(fundHoldings)..where((f) => f.id.equals(existing.id))).write(
          FundHoldingsCompanion(
            totalShares: Value(newShares),
            totalCost: Value(newCost),
            lastNav: nav != null ? Value(nav) : const Value.absent(),
            lastUpdate: Value(DateTime.now()),
          ),
        );
      } else {
        // 新建持仓
        await into(fundHoldings).insert(FundHoldingsCompanion(
          fundCode: Value(fundCode),
          fundName: Value(fundName),
          totalShares: Value(shares),
          totalCost: Value(cost),
          lastNav: nav != null ? Value(nav) : const Value(0),
          accountId: Value(accountId),
          lastUpdate: Value(DateTime.now()),
        ));
      }

      // 记录交易流水
      await into(fundTransactions).insert(FundTransactionsCompanion(
        fundCode: Value(fundCode),
        fundName: Value(fundName),
        operation: const Value('buy'),
        shares: Value(shares),
        amount: Value(cost),
        nav: Value(nav ?? 0),
        tradeDate: Value(DateTime.now()),
      ));
    });
  }

  /// 减仓：减少份额和成本
  Future<bool> reduceFundPosition(String fundCode, double shares, double amount, {double? nav}) async {
    return await transaction(() async {
      final existing = await findFundByCode(fundCode);
      if (existing == null || existing.totalShares <= 0) return false;

      if (shares >= existing.totalShares) {
        // 全部清仓
        await (delete(fundHoldings)..where((f) => f.id.equals(existing.id))).go();
      } else {
        // 部分减仓，成本按比例减少
        final ratio = shares / existing.totalShares;
        final costToReduce = existing.totalCost * ratio;

        await (update(fundHoldings)..where((f) => f.id.equals(existing.id))).write(
          FundHoldingsCompanion(
            totalShares: Value(existing.totalShares - shares),
            totalCost: Value(existing.totalCost - costToReduce),
            lastUpdate: Value(DateTime.now()),
          ),
        );
      }

      // 记录交易流水
      await into(fundTransactions).insert(FundTransactionsCompanion(
        fundCode: Value(fundCode),
        fundName: Value(existing.fundName),
        operation: const Value('sell'),
        shares: Value(shares),
        amount: Value(amount),
        nav: Value(nav ?? existing.lastNav),
        tradeDate: Value(DateTime.now()),
      ));

      return true;
    });
  }

  /// 更新基金净值
  Future<void> updateFundNav(String fundCode, double nav) async {
    final existing = await findFundByCode(fundCode);
    if (existing == null) return;

    await (update(fundHoldings)..where((f) => f.fundCode.equals(fundCode))).write(
      FundHoldingsCompanion(
        lastNav: Value(nav),
        lastUpdate: Value(DateTime.now()),
      ),
    );
  }

  /// 获取基金交易流水
  Future<List<FundTransaction>> getFundTransactions(String fundCode) =>
      (select(fundTransactions)
        ..where((t) => t.fundCode.equals(fundCode))
        ..orderBy([(t) => OrderingTerm(expression: t.tradeDate, mode: OrderingMode.desc)]))
      .get();

 /// 删除基金持仓
  Future<void> deleteFundHolding(String id) async {
    await (delete(fundHoldings)..where((f) => f.id.equals(id))).go();
  }

  /// 加仓（只输入金额，系统自动获取净值计算份额）
  Future<void> addFundPositionByAmount(String fundCode, String fundName, double amount, String accountId) async {
    if (amount <= 0) throw Exception('金额必须大于0');
    
    double? nav = await FundApiService.fetchFundNav(fundCode);
    if (nav == null || nav <= 0) {
      throw Exception('无法获取基金 $fundCode 的最新净值，请检查网络');
    }
    
    final shares = amount / nav;
    await addFundPosition(fundCode, fundName, shares, amount, accountId, nav: nav);
  }

  /// 减仓（只输入金额，系统自动获取净值计算份额）
  Future<bool> reduceFundPositionByAmount(String fundCode, double amount) async {
    if (amount <= 0) throw Exception('金额必须大于0');
    
    final existing = await findFundByCode(fundCode);
    if (existing == null || existing.totalShares <= 0) return false;
    
    double? nav = await FundApiService.fetchFundNav(fundCode);
    if (nav == null || nav <= 0) throw Exception('无法获取基金 $fundCode 的最新净值');
    
    final maxAmount = existing.totalShares * nav;
    
    if (amount >= maxAmount * 0.999) {
      await transaction(() async {
        await (delete(fundHoldings)..where((f) => f.id.equals(existing.id))).go();
        await into(fundTransactions).insert(FundTransactionsCompanion(
          fundCode: Value(fundCode),
          fundName: Value(existing.fundName),
          operation: const Value('sell'),
          shares: Value(existing.totalShares),
          amount: Value(maxAmount),
          nav: Value(nav),
          tradeDate: Value(DateTime.now()),
        ));
      });
      return true;
    }
    
    final shares = amount / nav;
    if (shares > existing.totalShares) {
      throw Exception('减仓金额超过持仓市值，最多可减 ¥${maxAmount.toStringAsFixed(2)}');
    }
    
    final ratio = shares / existing.totalShares;
    final costToReduce = existing.totalCost * ratio;
    
    await transaction(() async {
      await (update(fundHoldings)..where((f) => f.id.equals(existing.id))).write(
        FundHoldingsCompanion(
          totalShares: Value(existing.totalShares - shares),
          totalCost: Value(existing.totalCost - costToReduce),
          lastUpdate: Value(DateTime.now()),
        ),
      );
      
      await into(fundTransactions).insert(FundTransactionsCompanion(
        fundCode: Value(fundCode),
        fundName: Value(existing.fundName),
        operation: const Value('sell'),
        shares: Value(shares),
        amount: Value(amount),
        nav: Value(nav),
        tradeDate: Value(DateTime.now()),
      ));
    });
    
    return true;
  }
  // ==================== 股票方法 ====================

  /// 获取所有活跃股票持仓（按股票代码合并，每只股票一条记录）
  Future<List<StockHolding>> getActiveStockHoldings() =>
      (select(stockHoldings)..where((f) => f.isActive.equals(true))..orderBy([(f) => OrderingTerm(expression: f.stockCode)])).get();

  Stream<List<StockHolding>> watchActiveStockHoldings() =>
      (select(stockHoldings)..where((f) => f.isActive.equals(true))..orderBy([(f) => OrderingTerm(expression: f.stockCode)])).watch();

  /// 根据股票代码查找持仓（用于合并）
  Future<StockHolding?> findStockByCode(String stockCode) async {
    return await (select(stockHoldings)
      ..where((f) => f.stockCode.equals(stockCode))
      ..where((f) => f.isActive.equals(true)))
      .getSingleOrNull();
  }

  /// 加仓：合并到现有持仓或新建
  Future<void> addStockPosition(String stockCode, String stockName, double shares, double cost, String accountId, {double? price}) async {
    await transaction(() async {
      final existing = await findStockByCode(stockCode);

      if (existing != null) {
        // 已存在，合并持仓
        final newShares = existing.totalShares + shares;
        final newCost = existing.totalCost + cost;

        await (update(stockHoldings)..where((f) => f.id.equals(existing.id))).write(
          StockHoldingsCompanion(
            totalShares: Value(newShares),
            totalCost: Value(newCost),
            lastPrice: price != null ? Value(price) : const Value.absent(),
            lastUpdate: Value(DateTime.now()),
          ),
        );
      } else {
        // 新建持仓
        await into(stockHoldings).insert(StockHoldingsCompanion(
          stockCode: Value(stockCode),
          stockName: Value(stockName),
          totalShares: Value(shares),
          totalCost: Value(cost),
          lastPrice: price != null ? Value(price) : const Value(0),
          accountId: Value(accountId),
          lastUpdate: Value(DateTime.now()),
        ));
      }

      // 记录交易流水
      await into(stockTransactions).insert(StockTransactionsCompanion(
        stockCode: Value(stockCode),
        stockName: Value(stockName),
        operation: const Value('buy'),
        shares: Value(shares),
        amount: Value(cost),
        price: Value(price ?? 0),
        tradeDate: Value(DateTime.now()),
      ));
    });
  }

  /// 减仓：减少股数和成本
  Future<bool> reduceStockPosition(String stockCode, double shares, double amount, {double? price}) async {
    return await transaction(() async {
      final existing = await findStockByCode(stockCode);
      if (existing == null || existing.totalShares <= 0) return false;

      if (shares >= existing.totalShares) {
        // 全部清仓
        await (delete(stockHoldings)..where((f) => f.id.equals(existing.id))).go();
      } else {
        // 部分减仓，成本按比例减少
        final ratio = shares / existing.totalShares;
        final costToReduce = existing.totalCost * ratio;

        await (update(stockHoldings)..where((f) => f.id.equals(existing.id))).write(
          StockHoldingsCompanion(
            totalShares: Value(existing.totalShares - shares),
            totalCost: Value(existing.totalCost - costToReduce),
            lastUpdate: Value(DateTime.now()),
          ),
        );
      }

      // 记录交易流水
      await into(stockTransactions).insert(StockTransactionsCompanion(
        stockCode: Value(stockCode),
        stockName: Value(existing.stockName),
        operation: const Value('sell'),
        shares: Value(shares),
        amount: Value(amount),
        price: Value(price ?? existing.lastPrice),
        tradeDate: Value(DateTime.now()),
      ));

      return true;
    });
  }

  /// 更新股票价格
  Future<void> updateStockPrice(String stockCode, double price) async {
    final existing = await findStockByCode(stockCode);
    if (existing == null) return;

    await (update(stockHoldings)..where((f) => f.stockCode.equals(stockCode))).write(
      StockHoldingsCompanion(
        lastPrice: Value(price),
        lastUpdate: Value(DateTime.now()),
      ),
    );
  }

  /// 获取股票交易流水
  Future<List<StockTransaction>> getStockTransactions(String stockCode) =>
      (select(stockTransactions)
        ..where((t) => t.stockCode.equals(stockCode))
        ..orderBy([(t) => OrderingTerm(expression: t.tradeDate, mode: OrderingMode.desc)]))
        .get();

  /// 删除股票持仓
  Future<void> deleteStockHolding(String id) async {
    await (delete(stockHoldings)..where((f) => f.id.equals(id))).go();
  }

  /// 加仓（只输入金额，系统自动获取价格计算股数）
  Future<void> addStockPositionByAmount(String stockCode, String stockName, double amount, String accountId) async {
    if (amount <= 0) throw Exception('金额必须大于0');

    double? price = await StockApiService.fetchStockPrice(stockCode);
    if (price == null || price <= 0) {
      throw Exception('无法获取股票 $stockCode 的最新价格，请检查网络');
    }

    final shares = amount / price;
    await addStockPosition(stockCode, stockName, shares, amount, accountId, price: price);
  }

  /// 减仓（只输入金额，系统自动获取价格计算股数）
  Future<bool> reduceStockPositionByAmount(String stockCode, double amount) async {
    if (amount <= 0) throw Exception('金额必须大于0');

    final existing = await findStockByCode(stockCode);
    if (existing == null || existing.totalShares <= 0) return false;

    double? price = await StockApiService.fetchStockPrice(stockCode);
    if (price == null || price <= 0) throw Exception('无法获取股票 $stockCode 的最新价格');

    final maxAmount = existing.totalShares * price;

    if (amount >= maxAmount * 0.999) {
      await transaction(() async {
        await (delete(stockHoldings)..where((f) => f.id.equals(existing.id))).go();
        await into(stockTransactions).insert(StockTransactionsCompanion(
          stockCode: Value(stockCode),
          stockName: Value(existing.stockName),
          operation: const Value('sell'),
          shares: Value(existing.totalShares),
          amount: Value(maxAmount),
          price: Value(price),
          tradeDate: Value(DateTime.now()),
        ));
      });
      return true;
    }

    final shares = amount / price;
    if (shares > existing.totalShares) {
      throw Exception('减仓金额超过持仓市值，最多可减 ¥${maxAmount.toStringAsFixed(2)}');
    }

    final ratio = shares / existing.totalShares;
    final costToReduce = existing.totalCost * ratio;

    await transaction(() async {
      await (update(stockHoldings)..where((f) => f.id.equals(existing.id))).write(
        StockHoldingsCompanion(
          totalShares: Value(existing.totalShares - shares),
          totalCost: Value(existing.totalCost - costToReduce),
          lastUpdate: Value(DateTime.now()),
        ),
      );

      await into(stockTransactions).insert(StockTransactionsCompanion(
        stockCode: Value(stockCode),
        stockName: Value(existing.stockName),
        operation: const Value('sell'),
        shares: Value(shares),
        amount: Value(amount),
        price: Value(price),
        tradeDate: Value(DateTime.now()),
      ));
    });

    return true;
  }

  /// 重算所有投资账户余额 = 基金市值 + 股票市值
  /// 保证基金刷新与股票刷新不会互相覆盖对方写入的市值
  Future<void> recalculateInvestmentAccountBalances() async {
    final accounts = await getAllAccounts();
    final fundHoldings = await getActiveFundHoldings();
    final stockHoldings = await getActiveStockHoldings();

    for (final acc in accounts) {
      if (acc.type != AccountType.investment) continue;

      final fundValue = fundHoldings
          .where((f) => f.accountId == acc.id)
          .fold(0.0, (sum, f) => sum + f.totalShares * f.lastNav);
      final stockValue = stockHoldings
          .where((s) => s.accountId == acc.id)
          .fold(0.0, (sum, s) => sum + s.totalShares * s.lastPrice);

      await updateAccountBalance(acc.id, fundValue + stockValue);
    }
  }

  /// 累计收支统计（全部时间，不含删除与转账） {income: 收入, expense: 支出}
  Future<Map<String, double>> getTotalStats() async {
    final expenseResult = await customSelect(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND is_deleted = 0',
      variables: [Variable('expense')],
    ).getSingle();

    final incomeResult = await customSelect(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND is_deleted = 0',
      variables: [Variable('income')],
    ).getSingle();

    return {
      'expense': (expenseResult.read<double>('total') ?? 0.0).abs(),
      'income': incomeResult.read<double>('total') ?? 0.0,
    };
  }
}  // ← AppDatabase 类的结束大括号！

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ledger.sqlite'));
    return NativeDatabase(file);
  });
}
