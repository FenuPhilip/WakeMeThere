import 'destination.dart';
import '../data/destination_repository.dart';

/// Orchestrates destination lifecycle.
class DestinationManager {
  DestinationManager(this._repository);

  final DestinationRepository _repository;

  Future<List<Destination>> getAll() => _repository.getAll();

  Future<Destination> save(Destination destination) =>
      _repository.save(destination);

  Future<void> delete(int id) => _repository.delete(id);
}
