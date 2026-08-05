import 'dart:io';

import 'package:fast_contacts/fast_contacts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import 'firebase_options.dart';
import 'servicos/criptografia.dart'; // <-- SUA CRIPTOGRAFIA REAL AQUI!

// ============================================================================
// 1. INICIALIZAÇÃO DO APP
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BruckeFamiliaApp());
}

class BruckeFamiliaApp extends StatelessWidget {
  const BruckeFamiliaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BrückeFamília',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09121C),
        primaryColor: const Color(0xFF00C4FF),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================================
// 2. SPLASH SCREEN E VERIFICAÇÃO DE LOGIN
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarLogin();
  }

  Future<void> _verificarLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final nomeSalvo = prefs.getString('nomeUsuario');
    final telefoneSalvo = prefs.getString('telefoneUsuario');
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (currentUser != null && nomeSalvo != null && telefoneSalvo != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ChatScreen(meuNome: nomeSalvo, meuTelefone: telefoneSalvo),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const IdentificacaoScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFF00C4FF))),
    );
  }
}

// ============================================================================
// 3. TELA DE IDENTIFICAÇÃO (LOGIN)
// ============================================================================
class IdentificacaoScreen extends StatefulWidget {
  const IdentificacaoScreen({super.key});
  @override
  State<IdentificacaoScreen> createState() => _IdentificacaoScreenState();
}

class _IdentificacaoScreenState extends State<IdentificacaoScreen> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  bool _carregando = false;

  Future<void> _entrar() async {
    if (_nomeController.text.trim().isEmpty ||
        _telefoneController.text.trim().isEmpty)
      return;
    setState(() => _carregando = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nomeUsuario', _nomeController.text.trim());
      await prefs.setString('telefoneUsuario', _telefoneController.text.trim());

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            meuNome: _nomeController.text.trim(),
            meuTelefone: _telefoneController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'BrückeFamília',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00C4FF),
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: 'Seu Nome',
                  filled: true,
                  fillColor: const Color(0xFF162436),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _telefoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Seu Telefone (com DDD)',
                  filled: true,
                  fillColor: const Color(0xFF162436),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _carregando
                  ? const CircularProgressIndicator(color: Color(0xFF00C4FF))
                  : ElevatedButton(
                      onPressed: _entrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C4FF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                      child: const Text(
                        'ENTRAR',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. TELA DE CHAMADA (ÁUDIO E VÍDEO ZEGOCLOUD)
// ============================================================================
class TelaChamada extends StatelessWidget {
  final String callID;
  final String userID;
  final String userName;
  final bool isVideo;

  const TelaChamada({
    super.key,
    required this.callID,
    required this.userID,
    required this.userName,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ZegoUIKitPrebuiltCall(
        appID: 1607164961, // Seu AppID real
        appSign:
            "52762dec2c3841f4201e46ef0fd89ed778d765830914e8a08e1d0175489f60a7", // Seu AppSign real
        userID: userID,
        userName: userName,
        callID: callID,
        config: isVideo
            ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
            : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
      ),
    );
  }
}

// ============================================================================
// 5. BARRA DE DIGITAÇÃO E BOTÕES INFERIORES
// ============================================================================
class ChatInputArea extends StatefulWidget {
  final Function(String) onEnviar;
  final Function(bool) onDigitando;
  final VoidCallback onAnexarFoto;
  final VoidCallback onGravarVideo;
  final Function(String) onAudioGravado;

  const ChatInputArea({
    super.key,
    required this.onEnviar,
    required this.onDigitando,
    required this.onAnexarFoto,
    required this.onGravarVideo,
    required this.onAudioGravado,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final TextEditingController _controller = TextEditingController();
  bool _gravando = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Color(0xFF00C4FF)),
            onPressed: widget.onAnexarFoto,
            tooltip: "Tirar Foto",
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Color(0xFF00C4FF)),
            onPressed: widget.onGravarVideo,
            tooltip: "Gravar Filmagem",
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) => widget.onDigitando(val.trim().isNotEmpty),
              decoration: InputDecoration(
                hintText: _gravando ? 'Gravando Áudio...' : 'Mensagem...',
                hintStyle: TextStyle(
                  color: _gravando ? Colors.redAccent : Colors.white54,
                ),
                filled: true,
                fillColor: const Color(0xFF101A26),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onLongPress: () {
              setState(() => _gravando = true);
            },
            onLongPressUp: () {
              setState(() => _gravando = false);
            },
            child: CircleAvatar(
              backgroundColor: _gravando
                  ? Colors.redAccent
                  : const Color(0xFF00C4FF),
              child: IconButton(
                icon: Icon(
                  _controller.text.isNotEmpty
                      ? Icons.send
                      : (_gravando ? Icons.mic_none : Icons.mic),
                  color: Colors.black87,
                ),
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    widget.onEnviar(_controller.text);
                    _controller.clear();
                    widget.onDigitando(false);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. BALÃO DE MENSAGEM (CHAT MESSAGE)
// ============================================================================
class ChatMessage extends StatelessWidget {
  final String firebaseKey;
  final String text;
  final String? imageUrl;
  final String? audioUrl;
  final String? videoUrl;
  final String senderName;
  final bool isMe;
  final int timestamp;
  final String idiomaDestino;
  final Function(String, String?, String?) onApagar;

  const ChatMessage({
    super.key,
    required this.firebaseKey,
    required this.text,
    this.imageUrl,
    this.audioUrl,
    this.videoUrl,
    required this.senderName,
    required this.isMe,
    required this.timestamp,
    required this.idiomaDestino,
    required this.onApagar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => onApagar(firebaseKey, imageUrl, audioUrl),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF006B8F) : const Color(0xFF162436),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderName,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : const Color(0xFF00C4FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              if (text.isNotEmpty)
                Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              if (imageUrl != null)
                Image.network(imageUrl!, height: 150, fit: BoxFit.cover),
              if (videoUrl != null)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      "Vídeo Recebido",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              if (audioUrl != null)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      "Áudio Recebido",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 7. TELA PRINCIPAL DO CHAT (COMPLETA)
// ============================================================================
class ChatScreen extends StatefulWidget {
  final String meuNome;
  final String meuTelefone;

  const ChatScreen({
    super.key,
    required this.meuNome,
    required this.meuTelefone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _idiomaAtual = 'pt';
  final ScrollController _scrollController = ScrollController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'mensagens',
  );
  final DatabaseReference _statusRef = FirebaseDatabase.instance.ref().child(
    'status_digitando',
  );

  String _quemEstaDigitando = '';
  bool _enviandoMidia = false;

  @override
  void initState() {
    super.initState();
    _escutarStatusDigitando();
  }

  void _escutarStatusDigitando() {
    _statusRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        if (mounted) setState(() => _quemEstaDigitando = '');
        return;
      }
      String digitandoTemp = '';
      data.forEach((nome, estaDigitando) {
        if (estaDigitando == true && nome != widget.meuNome) {
          digitandoTemp = nome;
        }
      });
      if (mounted) setState(() => _quemEstaDigitando = digitandoTemp);
    });
  }

  void _atualizarDigitando(bool digitando) {
    _statusRef.child(widget.meuNome).set(digitando);
  }

  String _getBandeira() {
    switch (_idiomaAtual) {
      case 'de':
        return '🇩🇪';
      case 'en':
        return '🇺🇸';
      case 'pt':
      default:
        return '🇧🇷';
    }
  }

  void _enviarMensagem(String texto) {
    if (texto.trim().isEmpty) return;
    _atualizarDigitando(false);
    String textoSeguro = CriptografiaService.criptografar(texto);
    _database.push().set({
      'texto': textoSeguro,
      'remetenteNome': widget.meuNome,
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> _enviarFoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (image == null) return;
    setState(() => _enviandoMidia = true);
    try {
      File file = File(image.path);
      String nomeArquivo = 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('imagens_chat')
          .child(nomeArquivo);
      await ref.putFile(file);
      String urlDaImagem = await ref.getDownloadURL();
      _database.push().set({
        'texto': '',
        'imageUrl': urlDaImagem,
        'remetenteNome': widget.meuNome,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _enviandoMidia = false);
    }
  }

  Future<void> _enviarVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 5),
    );
    if (video == null) return;
    setState(() => _enviandoMidia = true);
    try {
      File file = File(video.path);
      String nomeArquivo = 'VID_${DateTime.now().millisecondsSinceEpoch}.mp4';
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('videos_chat')
          .child(nomeArquivo);
      await ref.putFile(file);
      String urlDoVideo = await ref.getDownloadURL();
      _database.push().set({
        'texto': '',
        'videoUrl': urlDoVideo,
        'remetenteNome': widget.meuNome,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _enviandoMidia = false);
    }
  }

  Future<void> _enviarAudioParaFirebase(String caminhoLocal) async {
    setState(() => _enviandoMidia = true);
    try {
      File file = File(caminhoLocal);
      String nomeArquivo = 'AUDIO_${DateTime.now().millisecondsSinceEpoch}.m4a';
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('audios_chat')
          .child(nomeArquivo);
      await ref.putFile(file);
      String urlDoAudio = await ref.getDownloadURL();
      _database.push().set({
        'texto': '',
        'audioUrl': urlDoAudio,
        'remetenteNome': widget.meuNome,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _enviandoMidia = false);
    }
  }

  Future<void> _apagarMensagem(
    String chaveFirebase,
    String? imageUrl,
    String? audioUrl,
  ) async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162436),
        title: const Text(
          'Apagar mensagem?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Excluir para todos?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: Color(0xFF00C4FF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'APAGAR',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await _database.child(chaveFirebase).remove();
        if (imageUrl != null && imageUrl.isNotEmpty)
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        if (audioUrl != null && audioUrl.isNotEmpty)
          await FirebaseStorage.instance.refFromURL(audioUrl).delete();
      } catch (e) {
        debugPrint('Erro ao apagar: $e');
      }
    }
  }

  void _rolarParaOFinal() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sairDoChat() async {
    _atualizarDigitando(false);
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nomeUsuario');
    await prefs.remove('telefoneUsuario');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const IdentificacaoScreen()),
    );
  }

  String _gerarIDDaSala(String numeroDestino) {
    List<String> numeros = [widget.meuTelefone, numeroDestino];
    numeros.sort();
    return "chamada_${numeros[0]}_${numeros[1]}";
  }

  Future<List<Map<String, dynamic>>> _carregarTodosOsContatos() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('usuarios')
          .get();
      Map<dynamic, dynamic> usuariosFirebase = snapshot.exists
          ? (snapshot.value as Map<dynamic, dynamic>)
          : {};
      if (!await Permission.contacts.request().isGranted) return [];
      List<Contact> contatosLocais = await FastContacts.getAllContacts();
      List<Map<String, dynamic>> listaFinal = [];
      for (var contatoLocal in contatosLocais) {
        if (contatoLocal.phones.isEmpty) continue;
        String nomeNaAgenda = contatoLocal.displayName.isNotEmpty
            ? contatoLocal.displayName
            : 'Sem Nome';
        String telLocal = contatoLocal.phones.first.number.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        if (telLocal.startsWith('55') && telLocal.length > 11)
          telLocal = telLocal.substring(2);
        if (telLocal.length >= 8 && widget.meuTelefone.length >= 8) {
          if (telLocal.substring(telLocal.length - 8) ==
              widget.meuTelefone.substring(widget.meuTelefone.length - 8))
            continue;
        }
        bool temApp = false;
        String telParaSalvar = telLocal;
        for (var user in usuariosFirebase.values) {
          String telFirebase = user['telefone'].toString();
          if (telLocal.length >= 8 && telFirebase.length >= 8) {
            if (telLocal.substring(telLocal.length - 8) ==
                telFirebase.substring(telFirebase.length - 8)) {
              temApp = true;
              telParaSalvar = telFirebase;
              break;
            }
          }
        }
        listaFinal.add({
          'nome': nomeNaAgenda,
          'telefone': telParaSalvar,
          'temApp': temApp,
        });
      }
      listaFinal.sort(
        (a, b) => a['nome'].toString().compareTo(b['nome'].toString()),
      );
      return listaFinal;
    } catch (e) {
      return [];
    }
  }

  Future<void> _convidarWhatsApp(String telefone) async {
    String ddi = telefone.length <= 11 ? "55" : "";
    String msg =
        "Olá! Baixe o BrückeFamília para a gente fazer chamadas de vídeo em segurança! O app é privado para nossa família.";
    final uri = Uri.parse(
      "https://wa.me/$ddi$telefone?text=${Uri.encodeComponent(msg)}",
    );
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _mostrarAgendaContatos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF162436),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Contatos da Agenda',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _carregarTodosOsContatos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00C4FF)),
                  );
                final lista = snapshot.data ?? [];
                if (lista.isEmpty)
                  return const Center(
                    child: Text(
                      "Nenhum contato encontrado.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                return ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (context, index) {
                    final contato = lista[index];
                    bool temApp = contato['temApp'];
                    return ListTile(
                      onTap: () {
                        if (temApp) {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TelaChamada(
                                callID: _gerarIDDaSala(contato['telefone']),
                                userID: widget.meuTelefone,
                                userName: widget.meuNome,
                                isVideo: false,
                              ),
                            ),
                          );
                        } else {
                          _convidarWhatsApp(contato['telefone']);
                        }
                      },
                      leading: CircleAvatar(
                        backgroundColor: temApp
                            ? const Color(0xFF00C4FF)
                            : Colors.grey[800],
                        child: Text(
                          contato['nome'][0].toUpperCase(),
                          style: TextStyle(
                            color: temApp ? Colors.black87 : Colors.white54,
                          ),
                        ),
                      ),
                      title: Text(
                        contato['nome'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        contato['telefone'] + (temApp ? " • Usa o App" : ""),
                        style: TextStyle(
                          color: temApp
                              ? const Color(0xFF00C4FF)
                              : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      trailing: temApp
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.phone,
                                    color: Colors.green,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TelaChamada(
                                          callID: _gerarIDDaSala(
                                            contato['telefone'],
                                          ),
                                          userID: widget.meuTelefone,
                                          userName: widget.meuNome,
                                          isVideo: false,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.videocam,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TelaChamada(
                                          callID: _gerarIDDaSala(
                                            contato['telefone'],
                                          ),
                                          userID: widget.meuTelefone,
                                          userName: widget.meuNome,
                                          isVideo: true,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            )
                          : TextButton.icon(
                              icon: const Icon(
                                Icons.share,
                                size: 16,
                                color: Colors.greenAccent,
                              ),
                              label: const Text(
                                "Convidar",
                                style: TextStyle(color: Colors.greenAccent),
                              ),
                              onPressed: () =>
                                  _convidarWhatsApp(contato['telefone']),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF09121C),
        elevation: 0,
        toolbarHeight: 90,
        title: Column(
          children: [
            const Text(
              'BRÜCKE FAMÍLIA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 3.0,
                color: Colors.white,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF006B8F)),
              ),
              child: const Text(
                'CRIPTOGRAFIA',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF00C4FF),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.greenAccent, size: 28),
            tooltip: 'Ligar Áudio',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaChamada(
                    callID: "sala_familia",
                    userID: widget.meuTelefone,
                    userName: widget.meuNome,
                    isVideo: false,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.videocam,
              color: Color(0xFF00C4FF),
              size: 30,
            ),
            tooltip: 'Chamada de Vídeo',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaChamada(
                    callID: "sala_familia",
                    userID: widget.meuTelefone,
                    userName: widget.meuNome,
                    isVideo: true,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.contact_phone,
              color: Colors.white70,
              size: 26,
            ),
            tooltip: 'Contatos',
            onPressed: () => _mostrarAgendaContatos(context),
          ),
          PopupMenuButton<String>(
            icon: Text(_getBandeira(), style: const TextStyle(fontSize: 24)),
            color: const Color(0xFF162436),
            onSelected: (String novoIdioma) =>
                setState(() => _idiomaAtual = novoIdioma),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem(
                value: 'pt',
                child: Text(
                  '🇧🇷 Português',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'de',
                child: Text(
                  '🇩🇪 Alemão',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'en',
                child: Text(
                  '🇺🇸 Inglês',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Sair',
            onPressed: _sairDoChat,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF09121C),
          image: DecorationImage(
            image: NetworkImage(
              'https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png',
            ),
            fit: BoxFit.cover,
            opacity: 0.15,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Divider(color: Color(0xFF162436), height: 1),
              if (_enviandoMidia)
                const LinearProgressIndicator(color: Color(0xFF00C4FF)),
              Expanded(
                child: StreamBuilder(
                  stream: _database.orderByChild('timestamp').onValue,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00C4FF),
                        ),
                      );
                    if (!snapshot.hasData ||
                        snapshot.data!.snapshot.value == null)
                      return const Center(
                        child: Text(
                          "Nenhuma mensagem...",
                          style: TextStyle(color: Colors.white54),
                        ),
                      );

                    Map<dynamic, dynamic> mapaMensagens =
                        snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                    List<Map<dynamic, dynamic>> listaMensagens = [];
                    mapaMensagens.forEach((chave, valor) {
                      var mensagemComChave = Map<dynamic, dynamic>.from(valor);
                      mensagemComChave['firebaseKey'] = chave;
                      if (mensagemComChave['texto'] != null &&
                          mensagemComChave['texto'].toString().isNotEmpty) {
                        mensagemComChave['texto'] =
                            CriptografiaService.descriptografar(
                              mensagemComChave['texto'],
                            );
                      }
                      listaMensagens.add(mensagemComChave);
                    });
                    listaMensagens.sort(
                      (a, b) =>
                          (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0),
                    );
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _rolarParaOFinal();
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: listaMensagens.length,
                      itemBuilder: (context, index) {
                        final msg = listaMensagens[index];
                        bool fuiEu = msg['remetenteNome'] == widget.meuNome;
                        int timestamp = msg['timestamp'] != null
                            ? (msg['timestamp'] as num).toInt()
                            : 0;
                        return ChatMessage(
                          firebaseKey: msg['firebaseKey'],
                          text: msg['texto'] ?? '',
                          imageUrl: msg['imageUrl'],
                          videoUrl: msg['videoUrl'],
                          audioUrl: msg['audioUrl'],
                          senderName: msg['remetenteNome'] ?? 'Desconhecido',
                          isMe: fuiEu,
                          timestamp: timestamp,
                          idiomaDestino: _idiomaAtual,
                          onApagar: _apagarMensagem,
                        );
                      },
                    );
                  },
                ),
              ),
              if (_quemEstaDigitando.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 4.0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$_quemEstaDigitando está digitando...',
                      style: const TextStyle(
                        color: Color(0xFF00C4FF),
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ChatInputArea(
                onEnviar: _enviarMensagem,
                onDigitando: _atualizarDigitando,
                onAnexarFoto: _enviarFoto,
                onGravarVideo: _enviarVideo,
                onAudioGravado: _enviarAudioParaFirebase,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
