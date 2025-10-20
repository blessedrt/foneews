import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class CryptoService {
  static String decryptAesEcbBase64(String base64Cipher, String keyUtf8) {
    final key = KeyParameter(Uint8List.fromList(utf8.encode(keyUtf8)));
    final cipher = PaddedBlockCipher('AES/ECB/PKCS7')..init(false, key);
    final bytes = base64Decode(base64Cipher);
    final plain = cipher.process(bytes);
    return utf8.decode(plain);
  }
}
