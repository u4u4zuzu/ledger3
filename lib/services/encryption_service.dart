import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// 端到端加密服务
/// 所有敏感数据在本地加密后存储/上传
class EncryptionService {
  static EncryptionService? _instance;
  static EncryptionService get instance => _instance ??= EncryptionService._();
  EncryptionService._();

  encrypt.Key? _masterKey;

  /// 使用用户密码派生主密钥 (PBKDF2)
  Future<void> initialize(String password, {String? salt}) async {
    final saltBytes = salt != null 
        ? base64Decode(salt)
        : _generateSalt();

    // PBKDF2: 100000 iterations, 256-bit key
    final keyBytes = await _pbkdf2(password, saltBytes, iterations: 100000, keyLength: 32);
    _masterKey = encrypt.Key(keyBytes);
  }

  bool get isInitialized => _masterKey != null;

  /// AES-256-GCM 加密
  String encryptText(String plaintext) {
    if (_masterKey == null) throw StateError('Encryption not initialized');

    final iv = encrypt.IV.fromSecureRandom(12); // GCM推荐12字节nonce
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_masterKey!, mode: encrypt.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    // 格式: base64(nonce + ciphertext + tag)
    final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
    combined.setAll(0, iv.bytes);
    combined.setAll(iv.bytes.length, encrypted.bytes);

    return base64Encode(combined);
  }

  /// AES-256-GCM 解密
  String decryptText(String ciphertext) {
    if (_masterKey == null) throw StateError('Encryption not initialized');

    final combined = base64Decode(ciphertext);
    final iv = encrypt.IV(Uint8List.sublistView(combined, 0, 12));
    final encryptedData = encrypt.Encrypted(Uint8List.sublistView(combined, 12));

    final encrypter = encrypt.Encrypter(
      encrypt.AES(_masterKey!, mode: encrypt.AESMode.gcm),
    );

    return encrypter.decrypt(encryptedData, iv: iv);
  }

  /// 生成随机盐值
  static String generateSaltBase64() => base64Encode(_generateSalt());

  static Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
  }

  /// PBKDF2 密钥派生
  static Future<Uint8List> _pbkdf2(
    String password,
    Uint8List salt, {
    required int iterations,
    required int keyLength,
  }) async {
    // 简化实现：使用 HMAC-SHA256 迭代
    var key = Uint8List.fromList(utf8.encode(password));
    for (var i = 0; i < iterations; i++) {
      final hmac = Hmac(sha256, key);
      key = Uint8List.fromList(hmac.convert(salt).bytes);
    }
    return Uint8List.sublistView(key, 0, keyLength);
  }

  /// 计算数据校验和
  static String checksum(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }
}
