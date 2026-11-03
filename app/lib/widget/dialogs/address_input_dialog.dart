import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/theme.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/provider/device_info_provider.dart';
import 'package:sonar/provider/http_provider.dart';
import 'package:sonar/provider/last_devices.provider.dart';
import 'package:sonar/provider/local_ip_provider.dart';
import 'package:sonar/provider/settings_provider.dart';
import 'package:sonar/util/ip_address.dart';
import 'package:sonar/widget/dialogs/error_dialog.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';
import 'package:sonar_isolates/model/device.dart';
import 'package:sonar_isolates/rust/api/model.dart';
import 'package:sonar_isolates/util/rust.dart';

enum _InputMode {
  hashtag,
  ip
  ;

  String get label {
    return switch (this) {
      _InputMode.hashtag => t.dialogs.addressInput.hashtag,
      _InputMode.ip => t.dialogs.addressInput.ip,
    };
  }
}

/// A dialog to input an hash or address.
/// Pops the dialog with the device if found.
class AddressInputDialog extends StatefulWidget {
  const AddressInputDialog();

  @override
  State<AddressInputDialog> createState() => _AddressInputDialogState();
}

class _AddressInputDialogState extends State<AddressInputDialog> with Refena {
  final _selected = List.generate(_InputMode.values.length, (index) => index == 0);
  _InputMode _mode = _InputMode.hashtag;
  String _input = '';
  bool _fetching = false;
  String? _error;
  String? _inputError;

  Future<void> _submit(List<String> localIps, int port, [String? candidate]) async {
    final List<String> candidates;
    final String input = _input.trim();
    if (candidate == null) {
      final error = switch (_mode) {
        _InputMode.hashtag => isValidIpv4HostPart(input) ? null : t.dialogs.addressInput.invalidHashtag,
        _InputMode.ip => isValidIpAddress(input) ? null : t.dialogs.addressInput.invalidIp,
      };
      if (error != null) {
        setState(() => _inputError = error);
        return;
      }
    }
    if (candidate != null) {
      candidates = [candidate];
    } else if (_mode == _InputMode.ip) {
      candidates = [input];
    } else {
      candidates = localIps.map((ip) => '${ip.ipPrefix}.$input').toList();
    }

    setState(() {
      _fetching = true;
    });

    final https = ref.read(settingsProvider).https;

    final deviceCompleter = Completer<void>();
    Device? foundDevice;
    String? error;

    final payload = ref.read(deviceFullInfoProvider).toRegisterDto();

    final List<Future<void>> futures = [
      for (final ip in candidates)
        () async {
          try {
            final response = await ref
                .read(httpProvider)
                .discovery
                .register(
                  protocol: https ? ProtocolType.https : ProtocolType.http,
                  ip: ip,
                  port: port,
                  payload: payload,
                );

            foundDevice = response.body.toDevice(ip, port, https);
            deviceCompleter.complete();
          } catch (e) {
            error = e.toString();
            rethrow;
          }
        }(),
    ];

    // Wait until,
    // - a device is found
    // - all candidates are checked
    try {
      await Future.any([
        deviceCompleter.future,
        Future.wait(futures),
      ]);
    } catch (_) {}

    if (!mounted) {
      return;
    }

    if (foundDevice != null) {
      ref.redux(lastDevicesProvider).dispatch(AddLastDeviceAction(foundDevice!));
      context.pop(foundDevice);
    } else {
      setState(() {
        _fetching = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localIps = (ref.watch(localIpProvider.select((info) => info.localIps))).uniqueIpPrefix;
    final hostPart = _input.isEmpty ? 'x' : _input;
    final settings = ref.watch(settingsProvider);
    final lastDevices = ref.watch(lastDevicesProvider);

    return LsDialog(
      title: Text(t.dialogs.addressInput.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToggleButtons(
            isSelected: _selected,
            onPressed: (int index) {
              setState(() {
                for (int i = 0; i < _selected.length; i++) {
                  _selected[i] = i == index;
                }
                _mode = _InputMode.values[index];
                _input = '';
                _inputError = null;
              });
            },
            borderRadius: BorderRadius.circular(10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            children: _InputMode.values.map((mode) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text(mode.label),
              );
            }).toList(),
          ),
          const SizedBox(height: 15),
          TextFormField(
            key: ValueKey('input-$_mode'),
            autofocus: true,
            enabled: !_fetching,
            keyboardType: _mode == _InputMode.hashtag ? TextInputType.number : TextInputType.text,
            inputFormatters: _mode == _InputMode.hashtag ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)] : null,
            decoration: InputDecoration(
              prefixText: _mode == _InputMode.hashtag ? '# ' : 'IP: ',
              errorText: _inputError,
            ),
            onChanged: (s) {
              setState(() {
                _input = s;
                _inputError = null;
              });
            },
            onFieldSubmitted: (s) async => _submit(localIps, settings.port),
          ),
          const SizedBox(height: 10),
          if (_mode == _InputMode.hashtag) ...[
            Text(
              t.dialogs.addressInput.hashtagHint,
              style: const TextStyle(color: Colors.grey),
            ),
            if (localIps.length <= 1)
              Text(
                '${t.dialogs.addressInput.ip}: ${localIps.firstOrNull?.ipPrefix ?? '192.168.2'}.$hostPart',
                style: const TextStyle(color: Colors.grey),
              )
            else ...[
              Text(
                '${t.dialogs.addressInput.ip}:',
                style: const TextStyle(color: Colors.grey),
              ),
              for (final ip in localIps)
                Text(
                  '- ${ip.ipPrefix}.$hostPart',
                  style: const TextStyle(color: Colors.grey),
                ),
            ],
          ] else ...[
            if (lastDevices.isEmpty)
              Text(
                '${t.general.example}: ${localIps.firstOrNull?.ipPrefix ?? '192.168.2'}.123',
                style: const TextStyle(color: Colors.grey),
              )
            else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: t.dialogs.addressInput.recentlyUsed),
                    ...lastDevices
                        .mapIndexed((index, device) {
                          return [
                            if (index != 0) const TextSpan(text: ', '),
                            TextSpan(
                              text: device.ip,
                              style: TextStyle(color: Theme.of(context).colorScheme.primary),
                              recognizer: TapGestureRecognizer()..onTap = () async => _submit(localIps, settings.port, device.ip),
                            ),
                          ];
                        })
                        .expand((e) => e),
                  ],
                ),
              ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Text(t.general.error, style: TextStyle(color: Theme.of(context).colorScheme.warning)),
                  if (_error != null) ...[
                    const SizedBox(width: 5),
                    InkWell(
                      onTap: () async {
                        await showDialog(
                          context: context,
                          builder: (_) => ErrorDialog(error: _error!),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Icon(LucideIcons.info, color: Theme.of(context).colorScheme.warning, size: 20),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
      actions: [
        LsButton(
          label: t.general.cancel,
          variant: LsButtonVariant.ghost,
          onPressed: () => context.pop(),
        ),
        LsButton(
          label: t.general.confirm,
          onPressed: _fetching ? null : () async => _submit(localIps, settings.port),
        ),
      ],
    );
  }
}

extension on String {
  String get ipPrefix {
    return split('.').take(3).join('.');
  }
}

extension on List<String> {
  List<String> get uniqueIpPrefix {
    final seen = <String>{};
    return where((s) => seen.add(s.ipPrefix)).toList();
  }
}
