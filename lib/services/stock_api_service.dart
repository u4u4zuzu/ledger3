import 'dart:convert';
import 'package:http/http.dart' as http;

/// 股票行情服务（与基金模块风格一致，复用东方财富行情接口）
class StockApiService {
  /// 获取股票最新价格（兼容旧代码）
  static Future<double?> fetchStockPrice(String stockCode) async {
    final info = await fetchStockInfo(stockCode);
    return info?['price'] as double?;
  }

  /// 获取股票名称
  static Future<String?> fetchStockName(String stockCode) async {
    final info = await fetchStockInfo(stockCode);
    return info?['name'] as String?;
  }

  /// 获取股票信息（名称 + 最新价格）
  /// 数据源：东方财富 push2 行情接口（UTF-8，价格以小数返回）
  static Future<Map<String, dynamic>?> fetchStockInfo(String stockCode) async {
    try {
      final secid = _toSecid(stockCode);
      final url = 'https://push2.eastmoney.com/api/qt/stock/get'
          '?secid=$secid'
          '&fields=f43,f57,f58,f60';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Referer': 'https://quote.eastmoney.com/',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = data['data'];
        if (d == null) return null;

        final price = (d['f43'] as num?)?.toDouble();
        final name = d['f58'] as String?;
        final code = (d['f57'] as String?) ?? stockCode;

        // 安全兜底：若接口返回的是价格×1000（部分行情源会缩放），还原为小数
        var safePrice = price;
        if (safePrice != null && safePrice > 100000) {
          safePrice = safePrice / 1000;
        }

        if (safePrice != null && safePrice > 0 && name != null && name.isNotEmpty) {
          print('✅ 获取股票信息 [$stockCode] $name: ¥$safePrice');
          return {
            'code': code,
            'name': name,
            'price': safePrice,
          };
        }
      }
      return null;
    } catch (e) {
      print('❌ 获取股票信息失败 [$stockCode]: $e');
      return null;
    }
  }

  /// 根据股票代码推断 secid（上交所 6 开头 -> 1，其余 -> 0）
  static String _toSecid(String code) {
    final c = code.trim();
    if (c.startsWith('6')) return '1.$c'; // 上海
    return '0.$c';                        // 深圳 / 北京
  }
}
