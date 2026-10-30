import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/config/init.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/settings_page.dart';
import 'package:localsend_app/pages/tabs/nearby_tab.dart';
import 'package:localsend_app/pages/tabs/transfer_tab.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/widget/ls/ls_scaffold.dart';
import 'package:localsend_app/widget/responsive_builder.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum HomeTab {
  nearby(LucideIcons.radar),
  transfer(LucideIcons.history),
  settings(LucideIcons.slidersHorizontal);

  const HomeTab(this.icon);

  final IconData icon;

  /// Tabs shown in the mobile bottom bar. Settings is a desktop rail screen.
  static const mobileTabs = [nearby, transfer];

  String get label {
    switch (this) {
      case HomeTab.nearby:
        return t.nearbyTab.title;
      case HomeTab.transfer:
        return t.transferTab.title;
      case HomeTab.settings:
        return t.settingsTab.title;
    }
  }
}

class HomePage extends StatefulWidget {
  final HomeTab initialTab;

  /// It is important for the initializing step
  /// because the first init clears the cache
  final bool appStart;

  const HomePage({
    required this.initialTab,
    required this.appStart,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with Refena {
  bool _dragAndDropIndicator = false;

  @override
  void initState() {
    super.initState();

    ensureRef((ref) async {
      ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(widget.initialTab));
      await postInit(context, ref, widget.appStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context); // rebuild on locale change
    final vm = context.watch(homePageControllerProvider);

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragAndDropIndicator = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _dragAndDropIndicator = false;
        });
      },
      onDragDone: (event) async {
        // the drop may contain a mix of files and directories
        final droppedDirectories = event.files.where((file) => Directory(file.path).existsSync()).toList();
        final droppedFiles = event.files.where((file) => !Directory(file.path).existsSync()).toList();

        for (final directory in droppedDirectories) {
          await ref.redux(selectedSendingFilesProvider).dispatchAsync(AddDirectoryAction(directory.path));
        }

        if (droppedFiles.isNotEmpty) {
          await ref
              .redux(selectedSendingFilesProvider)
              .dispatchAsync(
                AddFilesAction(
                  files: droppedFiles,
                  converter: CrossFileConverters.convertXFile,
                ),
              );
        }
        vm.changeTab(HomeTab.nearby);
      },
      child: ResponsiveBuilder(
        builder: (sizingInformation) {
          final tabs = sizingInformation.isDesktop ? HomeTab.values : HomeTab.mobileTabs;
          // Settings only exists on desktop. If the window shrinks while it is active,
          // fall back to the first mobile tab instead of leaving the tab bar without a selection.
          if (!sizingInformation.isDesktop && !tabs.contains(vm.currentTab)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                vm.changeTab(HomeTab.nearby);
              }
            });
          }
          final tabItems = tabs.map((tab) => LsTabItem(icon: tab.icon, label: tab.label)).toList();
          // The rail keeps navigation at the top and pins "settings" to the bottom
          // (prototype: rail-spacer before the settings entry).
          final railTabs = sizingInformation.isDesktop ? tabs.where((tab) => tab != HomeTab.settings).toList() : tabs;
          final pages = PageView(
            controller: vm.controller,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Kept alive so switching tabs does not drop the tab state
              // (search term, selection, expanded history, scroll position).
              _KeepAliveTab(child: NearbyTab(desktop: sizingInformation.isDesktop)),
              _KeepAliveTab(child: TransferTab(desktop: sizingInformation.isDesktop)),
              if (sizingInformation.isDesktop) _KeepAliveTab(child: const SettingsPage(desktop: true)),
            ],
          );

          return Scaffold(
            body: SafeArea(
              child: Stack(
                children: [
                  if (sizingInformation.isDesktop)
                    Row(
                      children: [
                        LsRail(
                          items: railTabs.map((tab) => LsTabItem(icon: tab.icon, label: tab.label)).toList(),
                          index: railTabs.indexOf(vm.currentTab),
                          onTap: (index) => vm.changeTab(railTabs[index]),
                          mark: const Icon(LucideIcons.radar),
                          footer: [
                            LsRailButton(
                              icon: HomeTab.settings.icon,
                              label: HomeTab.settings.label,
                              selected: vm.currentTab == HomeTab.settings,
                              onTap: () => vm.changeTab(HomeTab.settings),
                            ),
                          ],
                        ),
                        Expanded(child: pages),
                      ],
                    )
                  else
                    pages,
                  if (_dragAndDropIndicator)
                    Positioned.fill(
                      child: ColoredBox(
                        color: context.ls.colors.bg,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.download, size: 56, color: context.ls.colors.accent),
                            const SizedBox(height: 16),
                            Text(t.sendTab.placeItems, style: context.ls.title),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            bottomNavigationBar: sizingInformation.isDesktop
                ? null
                : LsTabBar(
                    items: tabItems,
                    index: vm.currentTab.index,
                    onTap: (index) => vm.changeTab(tabs[index]),
                  ),
          );
        },
      ),
    );
  }
}

/// Keeps a tab's subtree alive while another tab is shown.
///
/// [PageView] disposes its off-screen pages, which dropped the whole tab state
/// on every tab switch (search term, selection, expanded history, scroll
/// position) and could trigger a new device scan when going back to the nearby tab.
class _KeepAliveTab extends StatefulWidget {
  final Widget child;

  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
