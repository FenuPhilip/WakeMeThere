import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';

/// Short, brand-led entry screen. Permission explanations are shown at the
/// point a journey is started, where the user can understand why they matter.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(kMargin),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(
                  color: kSurfaceLow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.navigation, color: kPrimary, size: 48),
              ),
              const SizedBox(height: 24),
              Text('WakeMeThere', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text('Never miss your stop.', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: kSecondary)),
              const SizedBox(height: 36),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 18, color: kPrimary),
                  SizedBox(width: 8),
                  Flexible(child: Text('Journey monitoring and alerts run on your device.')),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Plan a journey'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
