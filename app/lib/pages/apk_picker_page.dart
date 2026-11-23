import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/provider/apk_provider.dart';
import 'package:sonar/provider/selection/selected_sending_files_provider.dart';
import 'package:sonar/util/native/cross_file_converters.dart';
import 'package:sonar/util/ui/nav_bar_padding.dart';
import 'package:sonar/widget/file_thumbnail.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_header.dart';
import 'package:sonar/widget/ls/ls_menu.dart';
import 'package:sonar/widget/ls/ls_search_field.dart';
import 'package:sonar_isolates/model/file_type.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';

class ApkPickerPage extends StatefulWidget {
  const ApkPickerPage({super.key});

  @override
  State<ApkPickerPage> createState() => _ApkPickerPageState();
}

class _ApkPickerPageState extends State<ApkPickerPage> with Refena {
  final _textController = TextEditingController();
  final List<Application> _selectedApps = [];

  Future<void> _pickApp(Application app) async {
    await ref
        .redux(selectedSendingFilesProvider)
        .dispatchAsync(
          AddFilesAction(
            files: [app],
            converter: CrossFileConverters.convertApplication,
          ),
        );

    if (mounted) {
      context.pop();
    }
  }

  Future<void> _pickApps(List<Application> apps) async {
    // ignore: discarded_futures

    for (Application app in apps) {
      await ref
          .redux(selectedSendingFilesProvider)
          .dispatchAsync(
            AddFilesAction(
              files: [app],
              converter: CrossFileConverters.convertApplication,
            ),
          );
    }

    if (mounted) {
      context.pop();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    ref.dispose(apkSearchParamProvider);
    super.dispose();
  }

  void _appSelection(Application app) {
    setState(() {
      if (_selectedApps.contains(app)) {
        _selectedApps.remove(app);
      } else {
        _selectedApps.add(app);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final apkParams = ref.watch(apkSearchParamProvider);
    final apkAsync = ref.watch(apkProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LsSubHeader(
              title: t.apkPickerPage.title,
              onBack: () => context.pop(),
              actions: [
                LsMenuButton<_AppFilter>(
                  icon: LucideIcons.listChecks,
                  checkbox: true,
                  dense: true,
                  active: !apkParams.includeSystemApps || apkParams.onlyAppsWithLaunchIntent,
                  items: [
                    LsMenuItem(
                      value: _AppFilter.systemApps,
                      label: t.apkPickerPage.excludeSystemApps,
                      checked: !apkParams.includeSystemApps,
                    ),
                    LsMenuItem(
                      value: _AppFilter.launchIntent,
                      label: t.apkPickerPage.excludeAppsWithoutLaunchIntent,
                      checked: apkParams.onlyAppsWithLaunchIntent,
                    ),
                  ],
                  onSelected: (filter) {
                    switch (filter) {
                      case _AppFilter.systemApps:
                        ref.notifier(apkSearchParamProvider).setState((old) => old.copyWith(includeSystemApps: !old.includeSystemApps));
                      case _AppFilter.launchIntent:
                        ref.notifier(apkSearchParamProvider).setState((old) => old.copyWith(onlyAppsWithLaunchIntent: !old.onlyAppsWithLaunchIntent));
                    }
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: LsSearchField(
                controller: _textController,
                hint: t.apkPickerPage.title,
                onChanged: (s) {
                  ref.notifier(apkSearchParamProvider).setState((old) => old.copyWith(query: s));
                  setState(() {});
                },
                trailing: apkParams.query.isEmpty
                    ? null
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          ref.notifier(apkSearchParamProvider).setState((old) => old.copyWith(query: ''));
                          _textController.clear();
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(LucideIcons.x, size: 14, color: colors.muted),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(t.apkPickerPage.apps(n: apkAsync.data?.length ?? 0).toUpperCase(), style: tokens.eyebrow),
                  const Spacer(),
                  LsChip.text(
                    apkParams.selectMultipleApps ? t.nearbyTab.multiActive : t.nearbyTab.multi,
                    accent: apkParams.selectMultipleApps,
                    onTap: () {
                      final multi = !apkParams.selectMultipleApps;
                      ref.notifier(apkSearchParamProvider).setState((old) => old.copyWith(selectMultipleApps: multi));
                      if (!multi) {
                        setState(_selectedApps.clear);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: CustomScrollView(
                    slivers: [
                      apkAsync.when(
                        data: (appList) {
                          if (appList.isEmpty) {
                            return SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(child: Text(t.transferTab.noResults, style: tokens.bodySm)),
                            );
                          }
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              childCount: appList.length,
                              (context, index) {
                                final app = appList[index];
                                final thumbnail = (app as ApplicationWithIcon).icon;
                                final selected = _selectedApps.contains(app);

                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: LsCard(
                                    padding: const EdgeInsets.all(10),
                                    onTap: () async => (apkParams.selectMultipleApps) ? _appSelection(app) : _pickApp(app),
                                    borderColor: selected ? colors.accent : null,
                                    child: Row(
                                      children: [
                                        MemoryThumbnail(
                                          bytes: thumbnail,
                                          size: 42,
                                          fileType: FileType.apk,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                app.appName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: tokens.bodyStrong,
                                              ),
                                              const SizedBox(height: 2),
                                              Consumer(
                                                builder: (context, ref) {
                                                  final appSize = ref.watch(apkSizeProvider(app.apkFilePath));
                                                  final appSizeString = appSize.maybeWhen(
                                                    data: (size) => '${size.asReadableFileSize}  ',
                                                    orElse: () => '',
                                                  );
                                                  return Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '$appSizeString${app.versionName != null ? 'v${app.versionName}' : ''}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: tokens.mono,
                                                      ),
                                                      Text(
                                                        app.packageName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: tokens.mono.copyWith(color: colors.faint),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (apkParams.selectMultipleApps)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: Icon(
                                              selected ? LucideIcons.checkCircle : LucideIcons.circle,
                                              size: 18,
                                              color: selected ? colors.accent : colors.faint,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        error: (e, _) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                              child: Column(
                                children: [
                                  Text(t.general.error, style: tokens.bodyStrong),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$e',
                                    textAlign: TextAlign.center,
                                    style: tokens.mono.copyWith(color: colors.danger),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: CircularProgressIndicator(color: colors.accent),
                              ),
                            ),
                          );
                        },
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: 16 + getNavBarPadding(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (apkParams.selectMultipleApps && _selectedApps.isNotEmpty)
              Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + getNavBarPadding(context)),
                decoration: BoxDecoration(
                  color: colors.bg,
                  border: Border(
                    top: BorderSide(color: colors.line, width: tokens.hairlineOf(context)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.apkPickerPage.apps(n: _selectedApps.length),
                        style: tokens.monoSm.copyWith(color: colors.muted),
                      ),
                    ),
                    LsButton(
                      label: t.general.add,
                      icon: LucideIcons.plus,
                      onPressed: () async => await _pickApps(_selectedApps),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The two list filters of the picker, phrased as the "exclude" options the
/// menu shows.
enum _AppFilter { systemApps, launchIntent }
