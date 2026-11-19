import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:wake_me_there/app/app.dart';
import 'package:wake_me_there/features/destination/data/destination_repository.dart';
import 'package:wake_me_there/features/destination/domain/destination.dart';
import 'package:wake_me_there/features/home/providers/home_provider.dart';
import 'package:wake_me_there/features/journey/data/journey_repository.dart';
import 'package:wake_me_there/features/journey/domain/journey.dart';
import 'package:wake_me_there/features/journey/providers/journey_provider.dart';

class InMemoryDestinationRepository implements DestinationRepository {
  final List<Destination> _items = [
    const Destination(
      id: 1,
      name: 'London Waterloo',
      address: 'Main Terminal',
      stationCode: 'WAT',
      coordinates: LatLng(51.5031, -0.1132),
      distanceMeters: 4200,
      etaMinutes: 12,
      iconName: 'train',
    ),
    const Destination(
      id: 2,
      name: 'Heathrow T5',
      address: 'Departure concourse',
      stationCode: 'HW5',
      coordinates: LatLng(51.4700, -0.4543),
      distanceMeters: 24500,
      etaMinutes: 38,
      iconName: 'flight',
    ),
  ];

  @override
  Future<List<Destination>> getAll() async => List.unmodifiable(_items);

  @override
  Future<Destination> save(Destination destination) async {
    final newId = (_items.isEmpty ? 0 : _items.last.id ?? 0) + 1;
    final saved = destination.copyWith(id: newId);
    _items.add(saved);
    return saved;
  }

  @override
  Future<void> delete(int id) async {
    _items.removeWhere((d) => d.id == id);
  }

  @override
  Future<void> clearAll() async {
    _items.clear();
  }
}

class InMemoryJourneyRepository implements JourneyRepository {
  Journey? _active;
  final List<Journey> _history = [];

  @override
  Future<Journey?> getActiveJourney() async => _active;

  @override
  Future<Journey> save(Journey journey) async {
    _active = journey;
    return journey;
  }

  @override
  Future<void> updateState(String id, String state) async {}

  @override
  Future<List<Journey>> getHistory() async => List.unmodifiable(_history);

  @override
  Future<void> clearHistory() async {
    _history.clear();
  }
}

void main() {
  testWidgets('WakeMeThere opens home from minimal launch screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final inMemoryRepo = InMemoryDestinationRepository();
    final inMemoryJourneyRepo = InMemoryJourneyRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          destinationRepositoryProvider.overrideWithValue(inMemoryRepo),
          journeyRepositoryProvider.overrideWithValue(inMemoryJourneyRepo),
        ],
        child: const WakeMeThereApp(),
      ),
    );

    // Pump once to build widget tree
    await tester.pump();
    // Pump small duration for async initialization
    await tester.pump(const Duration(milliseconds: 300));

    // The app launches directly into the usable home screen.
    expect(find.text('WakeMeThere'), findsOneWidget);
    expect(find.text('100%'), findsNothing);

    // Home status describes when location is actually checked.
    expect(find.text('Location checked when journey starts'), findsOneWidget);
    expect(find.text('Where do you want to get off?'), findsOneWidget);

    // Verify destinations loaded from repository
    expect(find.text('London Waterloo'), findsOneWidget);
    expect(find.text('Heathrow T5'), findsOneWidget);

    // Verify navigation tabs
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Offline Maps'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
