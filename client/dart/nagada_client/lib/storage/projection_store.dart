// Minimal in-memory projection store for examples
class ProjectionStore {
  final Map<String, dynamic> _store = {};

  T? get<T>(String key) => _store[key] as T?;

  void put(String key, Object value) => _store[key] = value;

  void clear() => _store.clear();
}
