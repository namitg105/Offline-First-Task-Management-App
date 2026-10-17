/// Thrown ONLY inside the data layer (data sources).
///
/// Rule of the architecture: exceptions never escape the data layer.
/// The repository catches them and converts them into a [Failure].
class ServerException implements Exception {
  final String message;
  const ServerException(this.message);

  @override
  String toString() => 'ServerException: $message';
}

/// Thrown when something goes wrong with local (on-device) storage.
class CacheException implements Exception {
  final String message;
  const CacheException(this.message);

  @override
  String toString() => 'CacheException: $message';
}
