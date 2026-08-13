# 实时资产记账App

一套完整的 Flutter 跨平台记账应用，支持实时资产更新、自动交易捕获（Android通知监听）。

## 功能特性

- **实时资产看板**：净资产、今日收支一目了然
- **自动记账（Android）**：监听微信/支付宝/银行App通知，自动捕获交易
- **短信解析**：自动识别6大银行交易短信
- **多账户管理**：现金、银行卡、信用卡、电子钱包、投资账户
- **智能分类**：餐饮、交通、购物、居住等预设分类
- **离线优先**：所有数据本地存储，无需网络即可使用
- **端到端加密**：AES-256-GCM加密保护财务隐私

## 项目结构

```
ledger/
├── lib/
│   ├── main.dart                          # 应用入口
│   ├── models/
│   │   └── database.dart                  # Drift数据库定义
│   ├── services/
│   │   ├── notification_service.dart      # Android通知监听通信
│   │   ├── sms_parser.dart                # 银行短信解析
│   │   └── encryption_service.dart        # AES-256加密
│   ├── providers/
│   │   └── asset_providers.dart           # Riverpod状态管理
│   └── screens/
│       ├── dashboard_screen.dart          # 资产看板首页
│       ├── add_transaction_screen.dart    # 记账页面
│       ├── transaction_list_screen.dart   # 流水列表
│       └── account_manager_screen.dart    # 账户管理
├── android/                               # Android原生代码
└── pubspec.yaml
```

## 快速开始

### 环境准备
```bash
flutter doctor
```

### 生成数据库代码
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 运行
```bash
flutter run
```

## 自动记账原理

### Android 通知监听
利用 `NotificationListenerService` 系统级权限监听支付App通知：

| 支付平台 | 包名 | 捕获内容 |
|---------|------|---------|
| 微信支付 | `com.tencent.mm` | 付款金额、商户名 |
| 支付宝 | `com.eg.android.AlipayGphone` | 支出金额、商家 |

**注意**：首次使用需在系统设置中授予"通知使用权"。

### 短信解析
支持自动解析以下银行的交易短信：
- 工商银行 (95588)
- 建设银行 (95533)
- 农业银行 (95599)
- 中国银行 (95566)
- 招商银行 (95555)
- 交通银行 (95559)

## 技术栈

| 层级 | 技术 |
|------|------|
| 跨平台框架 | Flutter 3.x |
| 状态管理 | Riverpod 2.x |
| 本地数据库 | Drift (SQLite) |
| 图表 | fl_chart |
| 加密 | crypto + encrypt |

## GitHub Actions 自动编译

1. 在 GitHub 创建新仓库，上传本项目代码
2. 进入仓库 → Actions → Build Android APK → Run workflow
3. 等待约 5 分钟，在 Artifacts 中下载 `ledger-app-apk.zip`
4. 解压得到 `app-release.apk`，安装到手机
