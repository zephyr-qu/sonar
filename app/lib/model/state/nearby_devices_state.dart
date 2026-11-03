import 'package:dart_mappable/dart_mappable.dart';
import 'package:sonar_isolates/model/device.dart';

part 'nearby_devices_state.mapper.dart';

@MappableClass()
class NearbyDevicesState with NearbyDevicesStateMappable {
  final bool runningFavoriteScan;
  final Set<String> runningIps; // list of local ips
  final Map<String, Device> devices; // fingerprint -> device

  /// Devices that are discovered via signaling server.
  /// The key is the fingerprint of the device.
  /// We do not trust the fingerprint, so we allow multiple devices with the same fingerprint.
  final Map<String, Set<Device>> signalingDevices;

  const NearbyDevicesState({
    required this.runningFavoriteScan,
    required this.runningIps,
    required this.devices,
    required this.signalingDevices,
  });

  Map<String, Device> get allDevices => mergeDevices(devices, signalingDevices);

  /// Merged view of [devices] and [signalingDevices].
  ///
  /// Exposed as a static method because this getter builds a new map on every
  /// call, so it can never compare equal inside a Refena `select`: callers that
  /// need the merged devices should select the source fields instead and merge
  /// them here.
  static Map<String, Device> mergeDevices(Map<String, Device> devices, Map<String, Set<Device>> signalingDevices) {
    final Map<String, Device> allDevices = {};
    allDevices.addAll(devices);
    for (final devices in signalingDevices.values) {
      for (final device in devices) {
        final currentDevice = allDevices[device.fingerprint];
        if (currentDevice != null && currentDevice.alias == device.alias) {
          allDevices[device.fingerprint] = currentDevice.merge(device);
        } else {
          allDevices[device.fingerprint] = device;
        }
      }
    }
    return allDevices;
  }
}

extension on Device {
  Device merge(Device other) {
    return Device(
      signalingId: signalingId ?? other.signalingId,
      ip: ip ?? other.ip,
      version: version,
      port: port,
      https: https,
      fingerprint: fingerprint,
      alias: alias,
      deviceModel: deviceModel,
      deviceType: deviceType,
      download: download,
      channels: [
        ...channels,
        for (final channel in other.channels)
          if (!channels.contains(channel)) channel,
      ],
    );
  }
}
