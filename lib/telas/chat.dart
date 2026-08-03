import 'dart:io';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // NOVO IMPORT PARA O WHATSAPP

import '../servicos/criptografia.dart';
import '../componentes/interacao.dart';
import 'login.dart';
import 'chamada.dart';

class ChatScreen extends StatefulWidget {
  final String meuNome; final String meuTelefone;
  const ChatScreen({super.key, required this.meuNome, required this.meuTelefone});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _idiomaAtual = 'pt'; final ScrollController _scrollController = ScrollController(); final DatabaseReference _database = FirebaseDatabase.instance.ref().child('mensagens'); final DatabaseReference _statusRef = FirebaseDatabase.instance.ref().child('status_digitando');
  String _quemEstaDigitando = ''; bool _enviandoMidia = false;

  @override void initState() { super.initState(); _escutarStatusDigitando(); }
  void _escutarStatusDigitando() { _statusRef.onValue.listen((event) { final data = event.snapshot.value as Map<dynamic, dynamic>?; if (data == null) { if (mounted) setState(() => _quemEstaDigitando = ''); return; } String digitandoTemp = ''; data.forEach((nome, estaDigitando) { if (estaDigitando == true && nome != widget.meuNome) { digitandoTemp = nome; } }); if (mounted) setState(() => _quemEstaDigitando = digitandoTemp); }); }
  void _atualizarDigitando(bool digitando) { _statusRef.child(widget.meuNome).set(digitando); }
  String _getBandeira() { switch (_idiomaAtual) { case 'de': return '🇩🇪'; case 'en': return '🇺🇸'; case 'pt': default: return '🇧🇷'; } }
  void _enviarMensagem(String texto) { if (texto.trim().isEmpty) return; _atualizarDigitando(false); String textoSeguro = CriptografiaService.criptografar(texto); _database.push().set({'texto': textoSeguro, 'remetenteNome': widget.meuNome, 'timestamp': ServerValue.timestamp}); }
  Future<void> _enviarFoto() async { final picker = ImagePicker(); final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70); if (image == null) return; setState(() => _enviandoMidia = true); try { File file = File(image.path); String nomeArquivo = 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg'; Reference ref = FirebaseStorage.instance.ref().child('imagens_chat').child(nomeArquivo); await ref.putFile(file); String urlDaImagem = await ref.getDownloadURL(); _database.push().set({'texto': '', 'imageUrl': urlDaImagem, 'remetenteNome': widget.meuNome, 'timestamp': ServerValue.timestamp}); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'))); } finally { if (mounted) setState(() => _enviandoMidia = false); } }
  Future<void> _enviarAudioParaFirebase(String caminhoLocal) async { setState(() => _enviandoMidia = true); try { File file = File(caminhoLocal); String nomeArquivo = 'AUDIO_${DateTime.now().millisecondsSinceEpoch}.m4a'; Reference ref = FirebaseStorage.instance.ref().child('audios_chat').child(nomeArquivo); await ref.putFile(file); String urlDoAudio = await ref.getDownloadURL(); _database.push().set({'texto': '', 'audioUrl': urlDoAudio, 'remetenteNome': widget.meuNome, 'timestamp': ServerValue.timestamp}); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'))); } finally { if (mounted) setState(() => _enviandoMidia = false); } }
  Future<void> _apagarMensagem(String chaveFirebase, String? imageUrl, String? audioUrl) async { bool? confirmar = await showDialog<bool>(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF162436), title: const Text('Apagar mensagem?', style: TextStyle(color: Colors.white)), content: const Text('Excluir para todos?', style: TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR', style: TextStyle(color: Color(0xFF00C4FF)))), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('APAGAR', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))],)); if (confirmar == true) { try { await _database.child(chaveFirebase).remove(); if (imageUrl != null && imageUrl.isNotEmpty) await FirebaseStorage.instance.refFromURL(imageUrl).delete(); if (audioUrl != null && audioUrl.isNotEmpty) await FirebaseStorage.instance.refFromURL(audioUrl).delete(); } catch (e) { debugPrint('Erro ao apagar: $e'); } } }
  void _rolarParaOFinal() { if (_scrollController.hasClients) { _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); } }
  Future<void> _sairDoChat() async { _atualizarDigitando(false); await FirebaseAuth.instance.signOut(); final prefs = await SharedPreferences.getInstance(); await prefs.remove('nomeUsuario'); await prefs.remove('telefoneUsuario'); if (!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const IdentificacaoScreen())); }
  String _gerarIDDaSala(String numeroDestino) { List<String> numeros = [widget.meuTelefone, numeroDestino]; numeros.sort(); return "chamada_${numeros[0]}_${numeros[1]}"; }

  // LOGICA NOVA DE CONTATOS MISTOS
  Future<List<Map<String, dynamic>>> _carregarTodosOsContatos() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref().child('usuarios').get();
      Map<dynamic, dynamic> usuariosFirebase = snapshot.exists ? (snapshot.value as Map<dynamic, dynamic>) : {};
      
      if (!await Permission.contacts.request().isGranted) return [];
      List<Contact> contatosLocais = await FastContacts.getAllContacts();
      
      List<Map<String, dynamic>> listaFinal = [];
      
      for (var contatoLocal in contatosLocais) {
        if (contatoLocal.phones.isEmpty) continue;
        
        String nomeNaAgenda = contatoLocal.displayName.isNotEmpty ? contatoLocal.displayName : 'Sem Nome';
        String telLocal = contatoLocal.phones.first.number.replaceAll(RegExp(r'[^0-9]'), '');
        
        if (telLocal.startsWith('55') && telLocal.length > 11) {
          telLocal = telLocal.substring(2);
        }
        
        // Esconde o próprio número do usuário da lista
        if (telLocal.length >= 8 && widget.meuTelefone.length >= 8) {
          if (telLocal.substring(telLocal.length - 8) == widget.meuTelefone.substring(widget.meuTelefone.length - 8)) {
            continue;
          }
        }

        bool temApp = false;
        String telParaSalvar = telLocal;
        
        for (var user in usuariosFirebase.values) {
          String telFirebase = user['telefone'].toString();
          if (telLocal.length >= 8 && telFirebase.length >= 8) {
            if (telLocal.substring(telLocal.length - 8) == telFirebase.substring(telFirebase.length - 8)) {
              temApp = true;
              telParaSalvar = telFirebase;
              break;
            }
          }
        }
        
        listaFinal.add({'nome': nomeNaAgenda, 'telefone': telParaSalvar, 'temApp': temApp});
      }
      
      listaFinal.sort((a, b) => a['nome'].toString().compareTo(b['nome'].toString()));
      return listaFinal;
    } catch (e) {
      debugPrint("Erro agenda: $e");
      return [];
    }
  }

  // FUNCAO PARA CONVIDAR VIA WHATSAPP
  Future<void> _convidarWhatsApp(String telefone) async {
    String ddi = telefone.length <= 11 ? "55" : ""; // Adiciona DDI Brasil se não houver
    String msg = "Olá! Baixe o BrückeFamília para a gente fazer chamadas de vídeo em segurança! O app é privado para nossa família.";
    final uri = Uri.parse("https://wa.me/$ddi$telefone?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _mostrarAgendaContatos(BuildContext context) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: const Color(0xFF162436), 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
      builder: (context) => Column(children: [
        const Padding(padding: EdgeInsets.all(16.0), child: Text('Contatos da Agenda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))), 
        const Divider(color: Colors.white24, height: 1), 
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _carregarTodosOsContatos(), 
            builder: (context, snapshot) { 
              if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Color(0xFF00C4FF)), SizedBox(height: 16), Text("Lendo agenda...", style: TextStyle(color: Colors.white54))])); } 
              final lista = snapshot.data ?? []; 
              if (lista.isEmpty) { return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text("Nenhum contato encontrado.", style: TextStyle(color: Colors.white54, fontSize: 16), textAlign: TextAlign.center))); } 
              
              return ListView.builder(
                itemCount: lista.length, 
                itemBuilder: (context, index) { 
                  final contato = lista[index]; 
                  bool temApp = contato['temApp'];

                  return ListTile(
                    leading: CircleAvatar(backgroundColor: temApp ? const Color(0xFF00C4FF) : Colors.grey[800], child: Text(contato['nome'][0].toUpperCase(), style: TextStyle(color: temApp ? Colors.black87 : Colors.white54, fontWeight: FontWeight.bold))), 
                    title: Text(contato['nome'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                    subtitle: Text(contato['telefone'] + (temApp ? " • Usa o App" : ""), style: TextStyle(color: temApp ? const Color(0xFF00C4FF) : Colors.white38, fontSize: 12)), 
                    trailing: temApp 
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.phone, color: Colors.green), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => TelaChamada(callID: _gerarIDDaSala(contato['telefone']), userID: widget.meuTelefone, userName: widget.meuNome, isVideo: false))); }), 
                          IconButton(icon: const Icon(Icons.videocam, color: Colors.blue), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => TelaChamada(callID: _gerarIDDaSala(contato['telefone']), userID: widget.meuTelefone, userName: widget.meuNome, isVideo: true))); })
                        ])
                      : TextButton.icon(
                          icon: const Icon(Icons.share, size: 16, color: Colors.greenAccent),
                          label: const Text("Convidar", style: TextStyle(color: Colors.greenAccent)),
                          onPressed: () => _convidarWhatsApp(contato['telefone']),
                        ),
                  ); 
                }
              ); 
            }
          )
        ), 
      ])
    ); 
  }

  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(backgroundColor: const Color(0xFF09121C), elevation: 0, toolbarHeight: 90, title: Column(children: [const Text('BRÜCKE FAMÍLIA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3.0, color: Colors.white, fontSize: 22)), const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF006B8F))), child: const Text('CRIPTOGRAFIA', style: TextStyle(fontSize: 10, color: Color(0xFF00C4FF), fontWeight: FontWeight.bold, letterSpacing: 1.5)))],), centerTitle: true, actions: [IconButton(icon: const Icon(Icons.contact_phone, color: Color(0xFF00C4FF), size: 28), tooltip: 'Contatos', onPressed: () => _mostrarAgendaContatos(context)), PopupMenuButton<String>(icon: Text(_getBandeira(), style: const TextStyle(fontSize: 24)), color: const Color(0xFF162436), onSelected: (String novoIdioma) => setState(() => _idiomaAtual = novoIdioma), itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[const PopupMenuItem(value: 'pt', child: Text('🇧🇷 Português', style: TextStyle(color: Colors.white))), const PopupMenuItem(value: 'de', child: Text('🇩🇪 Alemão', style: TextStyle(color: Colors.white))), const PopupMenuItem(value: 'en', child: Text('🇺🇸 Inglês', style: TextStyle(color: Colors.white)))]), IconButton(icon: const Icon(Icons.logout, color: Colors.white54), tooltip: 'Sair', onPressed: _sairDoChat)]), body: Container(decoration: const BoxDecoration(color: Color(0xFF09121C), image: DecorationImage(image: NetworkImage('https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png'), fit: BoxFit.cover, opacity: 0.15)), child: SafeArea(child: Column(children: [const Divider(color: Color(0xFF162436), height: 1), if (_enviandoMidia) const LinearProgressIndicator(color: Color(0xFF00C4FF)), Expanded(child: StreamBuilder(stream: _database.orderByChild('timestamp').onValue, builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF00C4FF))); if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text("Nenhuma mensagem...", style: TextStyle(color: Colors.white54))); Map<dynamic, dynamic> mapaMensagens = snapshot.data!.snapshot.value as Map<dynamic, dynamic>; List<Map<dynamic, dynamic>> listaMensagens = []; mapaMensagens.forEach((chave, valor) { var mensagemComChave = Map<dynamic, dynamic>.from(valor); mensagemComChave['firebaseKey'] = chave; if (mensagemComChave['texto'] != null && mensagemComChave['texto'].toString().isNotEmpty) { mensagemComChave['texto'] = CriptografiaService.descriptografar(mensagemComChave['texto']); } listaMensagens.add(mensagemComChave); }); listaMensagens.sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0)); WidgetsBinding.instance.addPostFrameCallback((_) { _rolarParaOFinal(); }); return ListView.builder(controller: _scrollController, padding: const EdgeInsets.all(16.0), itemCount: listaMensagens.length, itemBuilder: (context, index) { final msg = listaMensagens[index]; bool fuiEu = msg['remetenteNome'] == widget.meuNome; int timestamp = msg['timestamp'] != null ? (msg['timestamp'] as num).toInt() : 0; return ChatMessage(firebaseKey: msg['firebaseKey'], text: msg['texto'] ?? '', imageUrl: msg['imageUrl'], audioUrl: msg['audioUrl'], senderName: msg['remetenteNome'] ?? 'Desconhecido', isMe: fuiEu, timestamp: timestamp, idiomaDestino: _idiomaAtual, onApagar: _apagarMensagem); }); })), if (_quemEstaDigitando.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0), child: Align(alignment: Alignment.centerLeft, child: Text('$_quemEstaDigitando está digitando...', style: const TextStyle(color: Color(0xFF00C4FF), fontStyle: FontStyle.italic, fontSize: 12)))), ChatInputArea(onEnviar: _enviarMensagem, onDigitando: _atualizarDigitando, onAnexarFoto: _enviarFoto, onAudioGravado: _enviarAudioParaFirebase), const SizedBox(height: 8)])))); }
}
