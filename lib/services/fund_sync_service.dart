import 'package:drift/drift.dart';
import '../models/database.dart';
import 'fund_api_service.dart';

class FundSyncService {
  final AppDatabase db;
  FundSyncService(this.db);

  /// 刷新所有基金净值，并同步更新投资账户余额 + 基金名称
  Future<Map<String, double>> syncAllFundNavs() async {
    final holdings = await db.getActiveFundHoldings();
    if (holdings.isEmpty) return {};

    final Map<String, double> accountMarketValues = {};

    for (final holding in holdings) {
      // ✅ 改用 fetchFundInfo，同时获取名称和净值
      final info = await FundApiService.fetchFundInfo(holding.fundCode);
      if (info != null) {
        final nav = info['nav'] as double;
        final fundName = info['name'] as String;

        // 更新净值
        await db.updateFundNav(holding.fundCode, nav);

        // ✅ 如果旧数据存的是代码（如 005827），自动更新为真实名称
        if (fundName != holding.fundName && fundName != holding.fundCode) {
          await (db.update(db.fundHoldings)
            ..where((f) => f.id.equals(holding.id)))
            .write(
              FundHoldingsCompanion(fundName: Value(fundName)),
            );
          print('📝 更新基金名称: ${holding.fundCode} → $fundName');
        }

        // 计算市值
        final marketValue = holding.totalShares * nav;
        accountMarketValues[holding.accountId] =
            (accountMarketValues[holding.accountId] ?? 0) + marketValue;
      }
    }

    // 把基金+股票总市值写回投资账户余额（避免与股票刷新互相覆盖）
    await db.recalculateInvestmentAccountBalances();

    return accountMarketValues;
  }
}
