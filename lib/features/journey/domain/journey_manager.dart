import 'journey.dart';
import '../data/journey_repository.dart';

/// Orchestrates journey lifecycle, delegates persistence to repository.
class JourneyManager {
  JourneyManager(this._repository);

  final JourneyRepository _repository;

  Future<Journey?> getActiveJourney() => _repository.getActiveJourney();

  Future<Journey> startJourney(Journey journey) => _repository.save(journey);

  Future<void> completeJourney(String id) =>
      _repository.updateState(id, 'completed');

  Future<void> cancelJourney(String id) =>
      _repository.updateState(id, 'cancelled');
}
