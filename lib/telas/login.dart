import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat.dart';

class IdentificacaoScreen extends StatefulWidget {
  const IdentificacaoScreen({super.key});
  @override
  State<IdentificacaoScreen> createState() => _IdentificacaoScreenState();
}

class _IdentificacaoScreenState extends State<IdentificacaoScreen> {
  int _etapaAtual = 1;
  String _verificationId = "";
  bool _carregando = false;
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();

  Future<void> _solicitarPermissoes() async {
    await [Permission.camera, Permission.microphone, Permission.contacts].request();
  }

  Future<void> _enviarCodigoSMS() async {
    String telefone = _telefoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (telefone.length < 10) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite um telefone válido'))); return; }
    setState(() => _carregando = true);
    String telefoneComDDI = "+55$telefone";
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: telefoneComDDI,
        verificationCompleted: (PhoneAuthCredential credential) async { await FirebaseAuth.instance.signInWithCredential(credential); if (mounted) setState(() { _carregando = false; _etapaAtual = 3; }); },
        verificationFailed: (FirebaseAuthException e) { setState(() => _carregando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha: ${e.message}'))); },
        codeSent: (String verificationId, int? resendToken) { setState(() { _verificationId = verificationId; _carregando = false; _etapaAtual = 2; }); },
        codeAutoRetrievalTimeout: (String verificationId) { _verificationId = verificationId; },
      );
    } catch (e) { setState(() => _carregando = false); debugPrint("Erro SMS: $e"); }
  }

  Future<void> _verificarCodigoSms() async {
    String smsCode = _smsController.text.trim();
    if (smsCode.length < 6) return;
    setState(() => _carregando = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: smsCode);
      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() { _carregando = false; _etapaAtual = 3; });
    } catch (e) {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código SMS inválido!')));
    }
  }

  Future<void> _finalizarCadastro() async {
    await _solicitarPermissoes();
    final nome = _nomeController.text.trim();
    final telefone = _telefoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (nome.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um nome'))); return; }
    setState(() => _carregando = true);
    try {
      await FirebaseDatabase.instance.ref().child('usuarios').child(telefone).set({'nome': nome, 'telefone': telefone});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nomeUsuario', nome);
      await prefs.setString('telefoneUsuario', telefone);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ChatScreen(meuNome: nome, meuTelefone: telefone)));
    } catch (e) { setState(() => _carregando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Color(0xFF00C4FF)),
              const SizedBox(height: 24),
              const Text('BrückeFamília', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
              const SizedBox(height: 32),
              if (_etapaAtual == 1) ...[
                const Text('Digite seu celular para receber o código SMS', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center), const SizedBox(height: 24),
                TextField(controller: _telefoneController, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(hintText: 'Celular com DDD', filled: true, fillColor: const Color(0xFF101A26), prefixIcon: const Icon(Icons.phone, color: Colors.white54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))), const SizedBox(height: 32),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C4FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _carregando ? null : _enviarCodigoSMS, child: _carregando ? const CircularProgressIndicator(color: Colors.black) : const Text('ENVIAR SMS', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 1.5)))),
              ],
              if (_etapaAtual == 2) ...[
                const Text('Enviamos um código SMS', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center), const SizedBox(height: 24),
                TextField(controller: _smsController, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 6, style: const TextStyle(fontSize: 24, letterSpacing: 10.0, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: '000000', filled: true, fillColor: const Color(0xFF101A26), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))), const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _carregando ? null : _verificarCodigoSms, child: _carregando ? const CircularProgressIndicator(color: Colors.black) : const Text('CONFIRMAR', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 1.5)))),
                TextButton(onPressed: () => setState(() { _etapaAtual = 1; _carregando = false; }), child: const Text("Corrigir número", style: TextStyle(color: Color(0xFF00C4FF)))),
              ],
              if (_etapaAtual == 3) ...[
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 48), const SizedBox(height: 16),
                const Text('Verificado!', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)), const SizedBox(height: 24),
                TextField(controller: _nomeController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: 'Seu Nome (Ex: Paulo)', filled: true, fillColor: const Color(0xFF101A26), prefixIcon: const Icon(Icons.person, color: Colors.white54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))), const SizedBox(height: 32),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C4FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _carregando ? null : _finalizarCadastro, child: _carregando ? const CircularProgressIndicator(color: Colors.black) : const Text('ENTRAR NO APP', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 1.5)))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

