import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/session_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'helper/api_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiHelper.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: const SoulTalkApp(),
    ),
  );
}

class SoulTalkApp extends StatelessWidget {
  const SoulTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'SoulTalk AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}
