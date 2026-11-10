import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/store.dart';
import 'services/update_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.I.init();
  AppPalette.apply(Store.I.themeIndex);
  runApp(const MemimoApp());
}

class MemimoApp extends StatelessWidget {
  const MemimoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 监听主题变更，切换颜色后整个 App 立即重建
    return ValueListenableBuilder<int>(
      valueListenable: AppPalette.revision,
      builder: (context, _, __) {
        return MaterialApp(
          title: '四级背单词',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: AppPalette.scheme,
            fontFamily: 'Microsoft YaHei',
            scaffoldBackgroundColor: AppPalette.background,
          ),
          home: const _AppInitializer(),
        );
      },
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
