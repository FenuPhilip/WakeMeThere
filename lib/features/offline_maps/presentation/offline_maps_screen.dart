import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../map/domain/map_tile_provider.dart';

class OfflineMapsScreen extends ConsumerWidget {
  const OfflineMapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapProvider = ref.watch(mapTileProvider);

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.navigation, color: kPrimary, size: 22),
            const SizedBox(width: 10),
            Text('WakeMeThere', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: kMargin),
            child: Text(
              'Offline Maps',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(kMargin, 12, kMargin, 24),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Offline Maps',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Prepare for travel without an internet connection.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: const BoxDecoration(
                      color: kSurfaceLow,
                      borderRadius: BorderRadius.all(
                        Radius.circular(kRadiusLg),
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: kPrimary,
                              child: Icon(
                                Icons.satellite_alt,
                                color: kOnPrimary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'On-device tracking, with conditions',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                            const Icon(Icons.verified, color: kPrimary),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'GPS tracking and proximity alerts run on your device after a journey starts. The current app build does not download offline map packages, so viewing detailed maps and searching for places still need an internet connection.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Expanded(
                              child: _FeatureLabel(
                                icon: Icons.battery_saver_outlined,
                                text: 'GPS based monitoring',
                              ),
                            ),
                            Expanded(
                              child: _FeatureLabel(
                                icon: Icons.notifications_active_outlined,
                                text: 'On-device alerts',
                                emphasized: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    icon: Icons.download_for_offline_outlined,
                    title: 'Map downloads',
                    trailing: const _StatusPill(
                      icon: Icons.info_outline,
                      text: 'Not available yet',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: kLayer1Decoration,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Map downloads are not available yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'WakeMeThere does not currently download map regions. Map viewing and place search need an internet connection. Choose and confirm your destination while online; after tracking starts, GPS monitoring and on-device alerts may continue without mobile data, subject to GPS reception, permissions, and Android service availability.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Map data: ${mapProvider.attribution}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: kSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    icon: Icons.checklist_outlined,
                    title: 'Before travelling without data',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: kLayer1Decoration,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _PreparationItem(
                          icon: Icons.place_outlined,
                          text:
                              'Choose and confirm your destination while online.',
                        ),
                        const SizedBox(height: 14),
                        _PreparationItem(
                          icon: Icons.gps_fixed,
                          text:
                              'Once tracking starts, location monitoring and alerts run on device.',
                        ),
                        const SizedBox(height: 14),
                        _PreparationItem(
                          icon: Icons.signal_cellular_alt,
                          text:
                              'GPS quality can vary indoors, underground, and between buildings. Distance is approximate straight-line proximity.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.go('/map'),
                    icon: const Icon(Icons.place_outlined),
                    label: const Text('Choose a destination'),
                  ),
                ],
              ),
            ),
            const AppBottomNav(currentIndex: 1),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: kPrimary, size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
      if (trailing != null) trailing!,
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: const BoxDecoration(
      color: kSurfaceLow,
      borderRadius: BorderRadius.all(Radius.circular(kRadiusFull)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: kPrimary),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: kPrimary),
        ),
      ],
    ),
  );
}

class _FeatureLabel extends StatelessWidget {
  const _FeatureLabel({
    required this.icon,
    required this.text,
    this.emphasized = false,
  });
  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: emphasized ? kPrimary : kSecondary, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: emphasized ? kPrimary : kSecondary,
          ),
        ),
      ),
    ],
  );
}

class _PreparationItem extends StatelessWidget {
  const _PreparationItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: kPrimary, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
}
