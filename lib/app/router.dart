import 'package:go_router/go_router.dart';
import '../features/destination/domain/destination.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/journey/presentation/journey_setup_screen.dart';
import '../features/journey/presentation/active_journey_screen.dart';
import '../features/journey/presentation/alarm_screen.dart';
import '../features/offline_maps/presentation/offline_maps_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
    GoRoute(
      path: '/journey-setup',
      redirect: (context, state) => state.extra is Destination ? null : '/map',
      builder: (context, state) {
        final dest = state.extra as Destination;
        return JourneySetupScreen(destination: dest);
      },
    ),
    GoRoute(
      path: '/active-journey',
      builder: (context, state) => const ActiveJourneyScreen(),
    ),
    GoRoute(path: '/alarm', builder: (context, state) => const AlarmScreen()),
    GoRoute(
      path: '/offline-maps',
      builder: (context, state) => const OfflineMapsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
