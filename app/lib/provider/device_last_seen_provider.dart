import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/provider/persistence_provider.dart';

/// How many fingerprints are kept; old entries are dropped first.
const _maxEntries = 50;

/// Remembers when a device fingerprint was last confirmed on the network.
///
/// The discovery store only lives in RAM, so without this, a favorite that
/// goes offline has no "last seen" at all after a restart.
final deviceLastSeenProvider = ReduxProvider<DeviceLastSeenService, Map<String, DateTime>>((ref) {
  return DeviceLastSeenService(ref.read(persistenceProvider));
});

class DeviceLastSeenService extends ReduxNotifier<Map<String, DateTime>> {
  final PersistenceService _persistence;

  DeviceLastSeenService(this._persistence);

  @override
  Map<String, DateTime> init() => _persistence.getDeviceLastSeen();
}

/// Records that [fingerprint] was just confirmed.
class UpdateDeviceLastSeenAction extends AsyncReduxAction<DeviceLastSeenService, Map<String, DateTime>> {
  final String fingerprint;
  final DateTime time;

  UpdateDeviceLastSeenAction({required this.fingerprint, required this.time});

  @override
  Future<Map<String, DateTime>> reduce() async {
    final updated = {...state, fingerprint: time};
    final pruned = updated.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final result = Map.fromEntries(pruned.take(_maxEntries));
    await notifier._persistence.setDeviceLastSeen(result);
    return result;
  }
}
