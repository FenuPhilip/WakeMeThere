import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../destination/data/destination_repository.dart';
import '../../destination/domain/destination.dart';

final destinationRepositoryProvider = Provider<DestinationRepository>(
  (ref) => const SqfliteDestinationRepository(),
);

final savedDestinationsProvider = FutureProvider<List<Destination>>((
  ref,
) async {
  final repo = ref.watch(destinationRepositoryProvider);
  return repo.getAll();
});

/// Selected alarm wake buffer on Home Dashboard (1.0 km, 2.0 km, 5.0 km). Default 2.0 km.
final wakeBufferDistanceProvider = StateProvider<double>((ref) => 2.0);

final distanceUnitProvider = StateProvider<String>((ref) => 'km');
