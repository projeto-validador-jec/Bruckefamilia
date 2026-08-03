import 'package:encrypt/encrypt.dart' as encrypt;

class CriptografiaService {
  static final _key = encrypt.Key.fromUtf8('BrUck3F4m1l14Ch4v3S3cr3t4!2026!!');
  static final _iv = encrypt.IV.fromUtf8('vetor16bytes2026');
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));

  static String criptografar(String texto) {
    if (texto.isEmpty) return '';
    final encrypted = _encrypter.encrypt(texto, iv: _iv);
    return encrypted.base64;
  }

  static String descriptografar(String textoCriptografado) {
    if (textoCriptografado.isEmpty) return '';
    try {
      return _encrypter.decrypt64(textoCriptografado, iv: _iv);
    } catch (e) {
      return textoCriptografado;
    }
  }
}
