import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';

import 'call_page.dart'; // Import da tela de chamadas!
import 'firebase_options.dart';

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

// ==========================================
// TELA DE SPLASH
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarNome();
  }

  Future<void> _verificarNome() async {
    final prefs = await SharedPreferences.getInstance();
    final nomeSalvo = prefs.getString('nomeUsuario');

    if (!mounted) return;

    if (nomeSalvo != null && nomeSalvo.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(meuNome: nomeSalvo)),
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

// ==========================================
// TELA DE IDENTIFICAÇÃO
// ==========================================
class IdentificacaoScreen extends StatefulWidget {
  const IdentificacaoScreen({super.key});

  @override
  State<IdentificacaoScreen> createState() => _IdentificacaoScreenState();
}

class _IdentificacaoScreenState extends State<IdentificacaoScreen> {
  final TextEditingController _nomeController = TextEditingController();

  Future<void> _salvarNome() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nomeUsuario', nome);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(meuNome: nome)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.family_restroom,
                size: 80,
                color: Color(0xFF00C4FF),
              ),
              const SizedBox(height: 24),
              const Text(
                'Bem-vindo ao BrückeFamília!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Como você quer ser chamado(a) aqui?',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nomeController,
                decoration: InputDecoration(
                  hintText: 'Ex: Paulo, Mãe, Tio João...',
                  filled: true,
                  fillColor: const Color(0xFF101A26),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C4FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _salvarNome,
                  child: const Text(
                    'ENTRAR',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
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

// ==========================================
// TELA DO CHAT
// ==========================================
class ChatScreen extends StatefulWidget {
  final String meuNome;
  const ChatScreen({super.key, required this.meuNome});

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
  final AudioPlayer _playerNotificacao = AudioPlayer(); 

  String _quemEstaDigitando = '';
  bool _enviandoMidia = false;
  int _quantidadeMensagensAnterior = 0; 

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

      if (mounted) {
        setState(() => _quemEstaDigitando = digitandoTemp);
      }
    });
  }

  void _atualizarDigitando(bool digitando) {
    _statusRef.child(widget.meuNome).set(digitando);
  }

  String _getBandeira() {
    switch (_idiomaAtual) {
      case 'de':
        return '????';
      case 'en':
        return '????';
      case 'pt':
      default:
        return '????';
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
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() => _enviandoMidia = true);

    try {
      File file = File(image.path);
      String nomeArquivo = 'IMG_.jpg';
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao enviar imagem: ')));
      }
    } finally {
      if (mounted) setState(() => _enviandoMidia = false);
    }
  }

  Future<void> _enviarAudioParaFirebase(String caminhoLocal) async {
    setState(() => _enviandoMidia = true);

    try {
      File file = File(caminhoLocal);
      String nomeArquivo = 'AUDIO_.m4a';
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao enviar áudio: ')));
      }
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
          'Essa mensagem será excluída para toda a família.',
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
        if (imageUrl != null && imageUrl.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        }
        if (audioUrl != null && audioUrl.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(audioUrl).delete();
        }
      } catch (e) {
        debugPrint('Erro ao apagar arquivo: ');
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nomeUsuario');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const IdentificacaoScreen()),
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
                'CRIPTOGRAFIA DE PONTA A PONTA',
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
          // ?? NOVO BOTÃO DE VÍDEO
          IconButton(
            icon: const Icon(Icons.video_call, color: Color(0xFF00C4FF)),
            tooltip: 'Sala de Vídeo',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallPage(
                    callID: "sala_familia_oficial", // ID Fixo para a família se encontrar
                    userID: widget.meuNome.replaceAll(' ', '_') + DateTime.now().millisecondsSinceEpoch.toString(), // ID unico por login
                    userName: widget.meuNome,
                  ),
                ),
              );
            },
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
                  '???? Português',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'de',
                child: Text(
                  '???? Alemão',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'en',
                child: Text(
                  '???? Inglês',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00C4FF),
                        ),
                      );
                    }
                    if (!snapshot.hasData ||
                        snapshot.data!.snapshot.value == null) {
                      return const Center(
                        child: Text(
                          "Nenhuma mensagem...",
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }

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
                      if (_quantidadeMensagensAnterior > 0 &&
                          listaMensagens.length >
                              _quantidadeMensagensAnterior) {
                        final ultimaMsg = listaMensagens.last;
                        if (ultimaMsg['remetenteNome'] != widget.meuNome) {
                          // _playerNotificacao.play(AssetSource('som_notificacao.mp3'));
                        }
                      }
                      _quantidadeMensagensAnterior = listaMensagens.length;
                      _rolarParaOFinal();
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: listaMensagens.length,
                      itemBuilder: (context, index) {
                        final msg = listaMensagens[index];
                        bool fuiEu = msg['remetenteNome'] == widget.meuNome;

                        int timestamp = 0;
                        if (msg['timestamp'] != null) {
                          timestamp = (msg['timestamp'] as num).toInt();
                        }

                        return ChatMessage(
                          firebaseKey: msg['firebaseKey'],
                          text: msg['texto'] ?? '',
                          imageUrl: msg['imageUrl'],
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

// ==========================================
// COMPONENTES DO CHAT
// ==========================================
class ChatMessage extends StatefulWidget {
  final String firebaseKey;
  final String text;
  final String? imageUrl;
  final String? audioUrl;
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
    required this.senderName,
    required this.isMe,
    required this.timestamp,
    required this.idiomaDestino,
    required this.onApagar,
  });

  @override
  State<ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  String _textoAtual = '';
  bool _traduzindo = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _estaReproduzindo = false;

  @override
  void initState() {
    super.initState();
    _textoAtual = widget.text;
    _realizarTraducao();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _estaReproduzindo = state == PlayerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _reproduzirAudio() async {
    if (widget.audioUrl == null) return;
    try {
      if (_estaReproduzindo) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl!));
      }
    } catch (e) {
      debugPrint("Erro no áudio: $e");
    }
  }

  @override
  void didUpdateWidget(covariant ChatMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idiomaDestino != widget.idiomaDestino ||
        oldWidget.text != widget.text) {
      _realizarTraducao();
    }
  }

  Future<void> _realizarTraducao() async {
    if (widget.text.trim().isEmpty) return;

    setState(() => _traduzindo = true);
    try {
      final translation = await GoogleTranslator().translate(
        widget.text,
        to: widget.idiomaDestino,
      );
      if (mounted) {
        setState(() {
          _textoAtual = translation.text;
          _traduzindo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _textoAtual = widget.text;
          _traduzindo = false;
        });
      }
    }
  }

  String _formatarHora(int timestamp) {
    if (timestamp == 0) return '';
    final data = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return ':';
  }

  Color _gerarCor(String nome) {
    final cores = [
      Colors.greenAccent,
      Colors.pinkAccent,
      Colors.orangeAccent,
      Colors.amberAccent,
      Colors.tealAccent,
    ];
    return cores[nome.hashCode % cores.length];
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: widget.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!widget.isMe) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                widget.senderName,
                style: TextStyle(
                  color: _gerarCor(widget.senderName),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          GestureDetector(
            onLongPress: () {
              if (widget.isMe) {
                widget.onApagar(
                  widget.firebaseKey,
                  widget.imageUrl,
                  widget.audioUrl,
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? const Color(0xFF00C4FF)
                    : const Color(0xDD162436),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(widget.isMe ? 16 : 0),
                  bottomRight: Radius.circular(widget.isMe ? 0 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: widget.isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  TelaFotoAmpliadas(imageUrl: widget.imageUrl!),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: Image.network(
                            widget.imageUrl!,
                            width: 250,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: 250,
                                height: 200,
                                color: Colors.black26,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                  if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _estaReproduzindo
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: widget.isMe
                                ? Colors.black87
                                : const Color(0xFF00C4FF),
                            size: 38,
                          ),
                          onPressed: _reproduzirAudio,
                        ),
                        Text(
                          "Mensagem de Voz",
                          style: TextStyle(
                            color: widget.isMe ? Colors.black87 : Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),

                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      if (_textoAtual.isNotEmpty || _traduzindo)
                        Text(
                          _traduzindo ? '...' : _textoAtual,
                          style: TextStyle(
                            color: widget.isMe ? Colors.black87 : Colors.white,
                            fontSize: 15,
                            fontStyle: _traduzindo
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontWeight: widget.isMe
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      SizedBox(width: _textoAtual.isNotEmpty ? 8 : 0),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _formatarHora(widget.timestamp),
                          style: TextStyle(
                            color: widget.isMe
                                ? Colors.black54
                                : Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatInputArea extends StatefulWidget {
  final Function(String) onEnviar;
  final Function(bool) onDigitando;
  final VoidCallback onAnexarFoto;
  final Function(String) onAudioGravado;

  const ChatInputArea({
    super.key,
    required this.onEnviar,
    required this.onDigitando,
    required this.onAnexarFoto,
    required this.onAudioGravado,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final TextEditingController _controller = TextEditingController();

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _gravando = false;

  void _aoMudarTexto(String valor) {
    widget.onDigitando(valor.trim().isNotEmpty);
  }

  void _enviar() {
    widget.onEnviar(_controller.text);
    _controller.clear();
    widget.onDigitando(false);
  }

  Future<void> _alternarGravacao() async {
    try {
      if (_gravando) {
        final caminhoLocal = await _audioRecorder.stop();
        setState(() => _gravando = false);

        if (caminhoLocal != null) {
          widget.onAudioGravado(caminhoLocal);
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          String caminho =
              '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

          await _audioRecorder.start(const RecordConfig(), path: caminho);
          setState(() => _gravando = true);
        }
      }
    } catch (e) {
      setState(() => _gravando = false);
      debugPrint('Erro ao gravar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          if (!_gravando)
            IconButton(
              icon: const Icon(Icons.image, color: Color(0xFF00C4FF), size: 28),
              onPressed: widget.onAnexarFoto,
            ),

          IconButton(
            icon: Icon(
              _gravando ? Icons.stop_circle : Icons.mic,
              color: _gravando ? Colors.redAccent : const Color(0xFF00C4FF),
              size: _gravando ? 36 : 28,
            ),
            onPressed: _alternarGravacao,
          ),

          const SizedBox(width: 4),

          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              onChanged: _aoMudarTexto,
              enabled: !_gravando,
              decoration: InputDecoration(
                hintText: _gravando
                    ? 'Gravando áudio...'
                    : 'Digite uma mensagem...',
                hintStyle: TextStyle(
                  color: _gravando ? Colors.redAccent : Colors.white54,
                ),
                filled: true,
                fillColor: const Color(0xFF101A26),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF006B8F)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF00C4FF),
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (value) => _enviar(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00C4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black87),
              onPressed: _enviar,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TELA FOTO AMPLIADA
// ==========================================
class TelaFotoAmpliadas extends StatelessWidget {
  final String imageUrl;
  const TelaFotoAmpliadas({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}

// ==========================================
// SERVIÇO DE CRIPTOGRAFIA AES-256
// ==========================================
class CriptografiaService {
  static final _key = encrypt.Key.fromUtf8('BrUck3F4m1l14Ch4v3S3cr3t4!2026!!');
  static final _iv = encrypt.IV.fromLength(16);
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

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
