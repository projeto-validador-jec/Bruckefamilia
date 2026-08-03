import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'telas/login.dart';
import 'telas/chat.dart';

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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ChatScreen(meuNome: nomeSalvo, meuTelefone: telefoneSalvo)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const IdentificacaoScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00C4FF))));
  }
}
