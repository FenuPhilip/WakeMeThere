/// Base class for all WakeMeThere application errors.
abstract class AppError implements Exception {
  const AppError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class LocationPermissionError extends AppError {
  const LocationPermissionError([super.message = 'Location permission denied']);
}

class LocationUnavailableError extends AppError {
  const LocationUnavailableError([super.message = 'Location unavailable']);
}

class DatabaseError extends AppError {
  const DatabaseError(super.message);
}

class PlatformChannelError extends AppError {
  const PlatformChannelError(super.message);
}

class JourneyError extends AppError {
  const JourneyError(super.message);
}
