import 'package:drift/drift.dart';
import '../models/database.dart';
import 'stock_api_service.dart';

class StockSyncService {
  final AppDatabase db;
  StockSyncService(this.db);

  /// 刷新所有股票价格，并同步更新投资账户余额（基金+股票市值合并）
  Future<Map<String, double>> syncAllStockPrices() async {
    final holdings = await db.getActiveStockHoldings();
    if (holdings.isEmpty) return {};

    final Map<String, double> accountMarketValues = {};

    for (final holding in holdings) {
      // 复用 fetchStockInfo，同时获取名称和价格
      final info = await StockApiService.fetchStockInfo(holding.stockCode);
      if (info != null) {
        final price = info['price'] as double;
        final stockName = info['name'] as String;

        // 更新价格
        await db.updateStockPrice(holding.stockCode, price);

        // 若旧数据存的是代码（如 600519），自动更新为真实名称
        if (stockName != holding.stockName && stockName != holding.stockCode) {
          await (db.update(db.stockHoldings)
            ..where((f) => f.id.equals(holding.id)))
            .write(
              StockHoldingsCompanion(stockName: Value(stockName)),
            );
          print('📝 更新股票名称: ${holding.stockCode} → $stockName');
        }

        // 计算市值
        final marketValue = holding.totalShares * price;
        accountMarketValues[holding.accountId] =
            (accountMarketValues[holding.accountId] ?? 0) + marketValue;
      }
    }

    // 把基金+股票总市值写回投资账户余额（避免与基金刷新互相覆盖）
    await db.recalculateInvestmentAccountBalances();

    return accountMarketValues;
  }
}
