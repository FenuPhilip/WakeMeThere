import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';

class WakeMeThereApp extends ConsumerWidget {
  const WakeMeThereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'WakeMeThere',
      debugShowCheckedModeBanner: false,
      theme: NocturneTransitTheme.light(),
      routerConfig: appRouter,
    );
  }
}
