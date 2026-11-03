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
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_header.dart';
import 'package:sonar/widget/ls/ls_switch.dart';
import 'package:sonar/widget/responsive_list_view.dart';
import 'package:sonar/widget/sliver/sliver_pinned_header.dart';
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
                PopupMenuButton<int>(
                  itemBuilder: (context) {
                    return [
                      CheckedPopupMenuItem<int>(
                        value: 0,
                        checked: !apkParams.includeSystemApps,
                        child: Text(t.apkPickerPage.excludeSystemApps),
                      ),
                      CheckedPopupMenuItem<int>(
                        value: 1,
                        checked: apkParams.onlyAppsWithLaunchIntent,
                        child: Text(t.apkPickerPage.excludeAppsWithoutLaunchIntent),
                      ),
                    ];
                  },
                  onSelected: (value) {
                    switch (value) {
                      case 0:
                        ref.notifier(apkSearchParamProvider).setState((old) => old.copyWith(includeSystemApps: !old.includeSystemApps));
                        break;
                      case 1:
                        ref.notifier(apkSearchParamProvider).setState((old) => old.copyWith(onlyAppsWithLaunchIntent: !old.onlyAppsWithLaunchIntent));
                        break;
                    }
                  },
                ),
              ],
            ),
            Expanded(
              child: ResponsiveListView.single(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tabletPadding: const EdgeInsets.symmetric(horizontal: 16),
                child: CustomScrollView(
                  slivers: [
                    SliverPinnedHeader(
                      height: 72,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: FormField<String>(
                          builder: (_) => TextFormField(
                            controller: _textController,
                            autofocus: true,
                            onChanged: (s) {
                              ref.notifier(apkSearchParamProvider).setState((old) => old.copyWith(query: s));
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              prefixIcon: Icon(LucideIcons.search, size: 18, color: colors.faint),
                              suffixIcon: apkParams.query.isNotEmpty
                                  ? IconButton(
                                      iconSize: 18,
                                      onPressed: () {
                                        ref.notifier(apkSearchParamProvider).setState((old) => old.copyWith(query: ''));
                                        _textController.clear();
                                      },
                                      icon: const Icon(LucideIcons.x),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text(t.apkPickerPage.apps(n: apkAsync.data?.length ?? 0).toUpperCase(), style: tokens.eyebrow),
                            const Spacer(),
                            Text(t.apkPickerPage.title, style: tokens.bodySm),
                            const SizedBox(width: 6),
                            LsSwitch(
                              value: apkParams.selectMultipleApps,
                              label: t.apkPickerPage.title,
                              onChanged: (_) {
                                setState(() {
                                  apkParams.selectMultipleApps = !apkParams.selectMultipleApps;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    apkAsync.when(
                      data: (appList) {
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            childCount: appList.length,
                            (context, index) {
                              final app = appList[index];
                              final thumbnail = (app as ApplicationWithIcon).icon;
                              final selected = _selectedApps.contains(app);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
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
                      error: (e, st) {
                        return SliverToBoxAdapter(child: Text('Error: $e\n$st'));
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
                      child: SizedBox(height: getNavBarPadding(context) + 50),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedApps.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: colors.accent,
              foregroundColor: colors.accentFg,
              onPressed: () async => await _pickApps(_selectedApps),
              label: Row(
                children: [
                  const Icon(LucideIcons.plus, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    t.apkPickerPage.apps(n: _selectedApps.length),
                    style: tokens.buttonLabel,
                  ),
                ],
              ),
            ),
    );
  }
}
