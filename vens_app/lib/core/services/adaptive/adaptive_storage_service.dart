/// Manages adaptive KC state persistence using get_storage.
/// Stores per-topic mastery data locally so it survives app restarts.
/// Cross-device sync requires a server-side persistence layer (future).
library adaptive_storage;

import 'package:get_storage/get_storage.dart';

class AdaptiveStorageService {
  static const String _storageKey = 'adaptive_kc_states';
  final GetStorage _box;

  AdaptiveStorageService({GetStorage? box}) : _box = box ?? GetStorage();

  /// Get all stored KC states: Map<topic_name, stateData>
  Map<String, Map<String, dynamic>> getKcStates() {
    final raw = _box.read(_storageKey);
    if (raw == null) return {};
    if (raw is Map) {
      return raw.map((k, v) =>
          MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)));
    }
    return {};
  }

  /// Get a single KC state by topic name.
  Map<String, dynamic>? getKcState(String topicName) {
    return getKcStates()[topicName];
  }

  /// Upsert a single KC state (topic → mastery data).
  void updateKcState(String topicName, Map<String, dynamic> state) {
    final states = getKcStates();
    states[topicName] = Map<String, dynamic>.from(state);
    _box.write(_storageKey, states);
  }

  /// Replace all KC states at once.
  void setKcStates(Map<String, Map<String, dynamic>> states) {
    _box.write(_storageKey, states);
  }

  /// Clear all adaptive state (call on sign out).
  void clearStates() {
    _box.remove(_storageKey);
  }
}
