import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:translator/translator.dart';

class TelaFotoAmpliadas extends StatelessWidget {
  final String imageUrl;
  const TelaFotoAmpliadas({super.key, required this.imageUrl});
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), elevation: 0), body: Center(child: InteractiveViewer(panEnabled: true, minScale: 0.5, maxScale: 4.0, child: Image.network(imageUrl))));
  }
}

class ChatMessage extends StatefulWidget {
  final String firebaseKey; final String text; final String? imageUrl; final String? audioUrl; final String senderName; final bool isMe; final int timestamp; final String idiomaDestino; final Function(String, String?, String?) onApagar;
  const ChatMessage({super.key, required this.firebaseKey, required this.text, this.imageUrl, this.audioUrl, required this.senderName, required this.isMe, required this.timestamp, required this.idiomaDestino, required this.onApagar});
  @override State<ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  String _textoAtual = ''; bool _traduzindo = false; final AudioPlayer _audioPlayer = AudioPlayer(); bool _estaReproduzindo = false;
  @override void initState() { super.initState(); _textoAtual = widget.text; _realizarTraducao(); _audioPlayer.onPlayerStateChanged.listen((state) { if (mounted) setState(() => _estaReproduzindo = state == PlayerState.playing); }); }
  @override void dispose() { _audioPlayer.dispose(); super.dispose(); }
  Future<void> _reproduzirAudio() async { if (widget.audioUrl == null) return; try { if (_estaReproduzindo) { await _audioPlayer.pause(); } else { await _audioPlayer.play(UrlSource(widget.audioUrl!)); } } catch (e) { debugPrint("Erro no áudio: $e"); } }
  @override void didUpdateWidget(covariant ChatMessage oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.idiomaDestino != widget.idiomaDestino || oldWidget.text != widget.text) { _realizarTraducao(); } }
  Future<void> _realizarTraducao() async { if (widget.text.trim().isEmpty) return; setState(() => _traduzindo = true); try { final translation = await GoogleTranslator().translate(widget.text, to: widget.idiomaDestino); if (mounted) setState(() { _textoAtual = translation.text; _traduzindo = false; }); } catch (e) { if (mounted) setState(() { _textoAtual = widget.text; _traduzindo = false; }); } }
  String _formatarHora(int timestamp) { if (timestamp == 0) return ''; final data = DateTime.fromMillisecondsSinceEpoch(timestamp); return '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}'; }
  Color _gerarCor(String nome) { final cores = [Colors.greenAccent, Colors.pinkAccent, Colors.orangeAccent, Colors.amberAccent, Colors.tealAccent]; return cores[nome.hashCode % cores.length]; }
  @override Widget build(BuildContext context) {
    return Align(alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft, child: Column(crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [if (!widget.isMe) ...[ Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: Text(widget.senderName, style: TextStyle(color: _gerarCor(widget.senderName), fontSize: 12, fontWeight: FontWeight.bold))), ], GestureDetector(onLongPress: () { if (widget.isMe) widget.onApagar(widget.firebaseKey, widget.imageUrl, widget.audioUrl); }, child: Container(margin: const EdgeInsets.only(bottom: 12.0), padding: const EdgeInsets.all(10.0), decoration: BoxDecoration(color: widget.isMe ? const Color(0xFF00C4FF) : const Color(0xDD162436), borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(widget.isMe ? 16 : 0), bottomRight: Radius.circular(widget.isMe ? 0 : 16))), child: Column(crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8.0), child: GestureDetector(onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => TelaFotoAmpliadas(imageUrl: widget.imageUrl!))); }, child: ClipRRect(borderRadius: BorderRadius.circular(12.0), child: Image.network(widget.imageUrl!, width: 250, fit: BoxFit.cover)))), if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(_estaReproduzindo ? Icons.pause_circle_filled : Icons.play_circle_fill, color: widget.isMe ? Colors.black87 : const Color(0xFF00C4FF), size: 38), onPressed: _reproduzirAudio), Text("Mensagem de Voz", style: TextStyle(color: widget.isMe ? Colors.black87 : Colors.white, fontWeight: FontWeight.w500)), const SizedBox(width: 8)]), Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.end, children: [if (_textoAtual.isNotEmpty || _traduzindo) Text(_traduzindo ? '...' : _textoAtual, style: TextStyle(color: widget.isMe ? Colors.black87 : Colors.white, fontSize: 15, fontStyle: _traduzindo ? FontStyle.italic : FontStyle.normal, fontWeight: widget.isMe ? FontWeight.w500 : FontWeight.normal)), SizedBox(width: _textoAtual.isNotEmpty ? 8 : 0), Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(_formatarHora(widget.timestamp), style: TextStyle(color: widget.isMe ? Colors.black54 : Colors.white54, fontSize: 10))), ]), ], ), ), ), ]));
  }
}

class ChatInputArea extends StatefulWidget {
  final Function(String) onEnviar; final Function(bool) onDigitando; final VoidCallback onAnexarFoto; final Function(String) onAudioGravado;
  const ChatInputArea({super.key, required this.onEnviar, required this.onDigitando, required this.onAnexarFoto, required this.onAudioGravado});
  @override State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final TextEditingController _controller = TextEditingController(); final AudioRecorder _audioRecorder = AudioRecorder(); bool _gravando = false;
  void _aoMudarTexto(String valor) { widget.onDigitando(valor.trim().isNotEmpty); }
  void _enviar() { widget.onEnviar(_controller.text); _controller.clear(); widget.onDigitando(false); }
  Future<void> _alternarGravacao() async { try { if (_gravando) { final caminhoLocal = await _audioRecorder.stop(); setState(() => _gravando = false); if (caminhoLocal != null) widget.onAudioGravado(caminhoLocal); } else { if (await _audioRecorder.hasPermission()) { final dir = await getApplicationDocumentsDirectory(); String caminho = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a'; await _audioRecorder.start(const RecordConfig(), path: caminho); setState(() => _gravando = true); } } } catch (e) { setState(() => _gravando = false); debugPrint('Erro ao gravar: $e'); } }
  @override Widget build(BuildContext context) { return Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [if (!_gravando) IconButton(icon: const Icon(Icons.image, color: Color(0xFF00C4FF), size: 28), onPressed: widget.onAnexarFoto), IconButton(icon: Icon(_gravando ? Icons.stop_circle : Icons.mic, color: _gravando ? Colors.redAccent : const Color(0xFF00C4FF), size: _gravando ? 36 : 28), onPressed: _alternarGravacao), const SizedBox(width: 4), Expanded(child: TextField(controller: _controller, style: const TextStyle(color: Colors.white), onChanged: _aoMudarTexto, enabled: !_gravando, decoration: InputDecoration(hintText: _gravando ? 'Gravando áudio...' : 'Digite uma mensagem...', hintStyle: TextStyle(color: _gravando ? Colors.redAccent : Colors.white54), filled: true, fillColor: const Color(0xFF101A26), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF006B8F))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00C4FF), width: 2))), onSubmitted: (value) => _enviar())), const SizedBox(width: 12), Container(decoration: BoxDecoration(color: const Color(0xFF00C4FF), borderRadius: BorderRadius.circular(12)), child: IconButton(icon: const Icon(Icons.send, color: Colors.black87), onPressed: _enviar)), ])); }
}
