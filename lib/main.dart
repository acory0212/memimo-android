import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/store.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.I.init();
  runApp(const MemimoApp());
}

class MemimoApp extends StatelessWidget {
  const MemimoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4A7C59);
    return MaterialApp(
      title: '四级背单词',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        fontFamily: 'Microsoft YaHei',
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
      ),
      home: const _AppInitializer(),
    );
  }
}

class _AppInitializer extends StatefulWidget {
  const _AppInitializer();

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  @override
  void initState() {
    super.initState();
    // 等首帧渲染完再弹窗，避免 Navigator 还没就绪
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.autoCheck(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}