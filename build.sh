#!/bin/bash
set -e

echo "=========================================="
echo "  实时资产记账App - 一键构建脚本"
echo "=========================================="

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ 未检测到 Flutter，请先安装: https://docs.flutter.dev/get-started/install"
    exit 1
fi

# 检查 Java
if ! command -v java &> /dev/null; then
    echo "❌ 未检测到 Java，请先安装 JDK 17+"
    exit 1
fi

echo "✅ 环境检查通过"
echo ""

# 获取依赖
echo "📦 正在获取依赖..."
flutter pub get

# 生成数据库代码
echo "🗄️  正在生成数据库代码..."
flutter pub run build_runner build --delete-conflicting-outputs

# 构建 Release APK
echo "🔨 正在编译 APK..."
flutter build apk --release

echo ""
echo "=========================================="
echo "✅ 编译成功！"
echo ""
echo "APK 路径:"
echo "  build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "安装到手机:"
echo "  adb install build/app/outputs/flutter-apk/app-release.apk"
echo "=========================================="
