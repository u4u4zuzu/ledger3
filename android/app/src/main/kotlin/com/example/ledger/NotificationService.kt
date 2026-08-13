package com.example.ledger

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.regex.Pattern

// ==================== 支付通知数据类 ====================
data class PaymentNotification(
    val source: String,
    val type: String, // expense, income, transfer
    val amount: Double,
    val merchant: String,
    val time: Long
)

// ==================== 通知监听服务 ====================
class NotificationService : NotificationListenerService() {
    companion object {
        private const val TAG = "LEDGER_NOTIFY"
        private const val CHANNEL = "com.example.ledger/notification"
        
        private val PAYMENT_PACKAGES = mapOf(
            "com.tencent.mm" to "wechat",
            "com.eg.android.AlipayGphone" to "alipay"
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        Log.d(TAG, "收到通知: $packageName")
        
        if (!PAYMENT_PACKAGES.containsKey(packageName)) return
        
        val title = sbn.notification.extras.getString(Notification.EXTRA_TITLE) ?: ""
        val content = sbn.notification.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        
        Log.d(TAG, "标题: $title | 内容: $content")
        
        val notification = when (PAYMENT_PACKAGES[packageName]) {
            "wechat" -> parseWechatNotification(title, content)
            "alipay" -> parseAlipayNotification(title, content)
            else -> null
        }
        
        notification?.let {
            Log.d(TAG, "解析成功: ${it.source} ${it.type} ¥${it.amount}")
            sendToFlutter(it)
        }
    }

    // ==================== 微信解析 ====================
    private fun parseWechatNotification(title: String, content: String): PaymentNotification? {
        // 匹配：已支付¥0.02 / 微信支付¥35.00 / 转账¥100.00 / 收到转账¥50.00
        val pattern = Pattern.compile("(已支付|微信支付|转账|收款|收到转账|红包).*?([¥￥])([0-9]+\\.?[0-9]*)")
        val matcher = pattern.matcher(content)
        
        if (matcher.find()) {
            val keyword = matcher.group(1) ?: ""
            val amountStr = matcher.group(3) ?: "0"
            val amount = amountStr.toDoubleOrNull() ?: 0.0
            
            val type = when {
                keyword == "已支付" || keyword == "微信支付" -> "expense"
                keyword == "收款" || keyword == "收到转账" -> "income"
                keyword == "转账" -> if (content.contains("收入") || content.contains("收到")) "income" else "expense"
                keyword == "红包" -> if (content.contains("收到") || content.contains("收入")) "income" else "expense"
                else -> "expense"
            }
            
            return PaymentNotification(
                source = "wechat",
                type = type,
                amount = amount,
                merchant = title,
                time = System.currentTimeMillis()
            )
        }
        return null
    }

    // ==================== 支付宝解析 ====================
    private fun parseAlipayNotification(title: String, content: String): PaymentNotification? {
        val pattern = Pattern.compile("(付款|收款|转账|红包).*?([¥￥])([0-9]+\\.?[0-9]*)")
        val matcher = pattern.matcher(content)
        
        if (matcher.find()) {
            val keyword = matcher.group(1) ?: ""
            val amountStr = matcher.group(3) ?: "0"
            val amount = amountStr.toDoubleOrNull() ?: 0.0
            
            val type = when {
                keyword == "付款" -> "expense"
                keyword == "收款" -> "income"
                keyword == "转账" -> if (content.contains("收入") || content.contains("收到")) "income" else "expense"
                else -> "expense"
            }
            
            return PaymentNotification(
                source = "alipay",
                type = type,
                amount = amount,
                merchant = title,
                time = System.currentTimeMillis()
            )
        }
        return null
    }

    // ==================== 发送到 Flutter ====================
    private fun sendToFlutter(notification: PaymentNotification) {
        try {
            val engine = FlutterEngineCache.getInstance().get("ledger_engine")
            if (engine == null) {
                Log.w(TAG, "Flutter engine 未缓存，通知无法发送")
                return
            }
            
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            val json = JSONObject().apply {
                put("source", notification.source)
                put("type", notification.type)
                put("amount", notification.amount)
                put("merchant", notification.merchant)
                put("time", notification.time)
            }
            
            channel.invokeMethod("onPaymentNotification", json.toString())
            Log.d(TAG, "已发送到Flutter")
        } catch (e: Exception) {
            Log.e(TAG, "发送失败: ${e.message}")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {}
}
