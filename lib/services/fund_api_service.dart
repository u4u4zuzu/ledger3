import 'dart:convert';
import 'package:http/http.dart' as http;

class FundApiService {
  /// 获取基金最新净值（兼容旧代码）
  static Future<double?> fetchFundNav(String fundCode) async {
    final info = await fetchFundInfo(fundCode);
    return info?['nav'] as double?;
  }

  /// 从基金概况页获取名称
  static Future<String?> fetchFundName(String fundCode) async {
    try {
      final url = 'https://fundf10.eastmoney.com/jbgk_$fundCode.html';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10)',
          'Accept': 'text/html',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // 从 title 提取：易方达蓝筹精选混合(005827)基金概况...
        final titleMatch = RegExp(r'<title>(.+?)\(').firstMatch(response.body);
        if (titleMatch != null) {
          final name = titleMatch.group(1)?.trim();
          if (name != null && name.isNotEmpty && !name.contains('404')) {
            return name;
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ 获取基金名称失败 [$fundCode]: $e');
      return null;
    }
  }

  /// 获取基金信息（名称 + 最新净值）
  static Future<Map<String, dynamic>?> fetchFundInfo(String fundCode) async {
    try {
      // 1. 先获取名称（从概况页）
      String fundName = await fetchFundName(fundCode) ?? fundCode;

      // 2. 获取净值（从历史净值接口）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = 'http://api.fund.eastmoney.com/f10/lsjz'
          '?fundCode=$fundCode'
          '&pageIndex=1'
          '&pageSize=1'
          '&startDate='
          '&endDate='
          '&_=$timestamp';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Referer': 'http://fundf10.eastmoney.com/',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        String jsonStr = response.body;
        final start = jsonStr.indexOf('{');
        final end = jsonStr.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          jsonStr = jsonStr.substring(start, end + 1);
        }

        final data = jsonDecode(jsonStr);
        final lsjzList = data['Data']?['LSJZList'] as List<dynamic>?;
        double? nav;
        if (lsjzList != null && lsjzList.isNotEmpty) {
          final latest = lsjzList.first as Map<String, dynamic>;
          final dwjz = latest['DWJZ']?.toString();
          if (dwjz != null) nav = double.tryParse(dwjz);
        }

        if (nav != null && nav > 0) {
          print('✅ 获取基金信息 [$fundCode] $fundName: ¥$nav');
          return {
            'code': fundCode,
            'name': fundName,
            'nav': nav,
          };
        }
      }
      return null;
    } catch (e) {
      print('❌ 获取基金信息失败 [$fundCode]: $e');
      return null;
    }
  }
}
