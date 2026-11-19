/// Persists map-related user data (e.g. recent searches, saved places).
/// Implementation deferred to Phase 2.
abstract class MapRepository {
  Future<List<String>> getRecentSearches();
  Future<void> saveSearch(String query);
}
