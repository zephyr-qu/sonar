import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/config/init.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/pages/home_page_controller.dart';
import 'package:sonar/pages/settings_page.dart';
import 'package:sonar/pages/tabs/nearby_tab.dart';
import 'package:sonar/pages/tabs/transfer_tab.dart';
import 'package:sonar/provider/selection/selected_sending_files_provider.dart';
import 'package:sonar/util/native/cross_file_converters.dart';
import 'package:sonar/widget/ls/ls_scaffold.dart';
import 'package:sonar/widget/responsive_builder.dart';
import 'package:sonar/widget/transfer_mini_bar.dart';

enum HomeTab {
  nearby(LucideIcons.radar),
  transfer(LucideIcons.history),
  settings(LucideIcons.slidersHorizontal)
  ;

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
        // Partition the drop in a single pass: `existsSync()` is a synchronous stat call,
        // so asking the file system twice per dropped item is wasted work on large drops.
        final droppedDirectories = <DropItem>[];
        final droppedFiles = <DropItem>[];
        for (final file in event.files) {
          (Directory(file.path).existsSync() ? droppedDirectories : droppedFiles).add(file);
        }

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
              _KeepAliveTab(
                active: vm.currentTab == HomeTab.nearby,
                child: NearbyTab(desktop: sizingInformation.isDesktop),
              ),
              _KeepAliveTab(
                active: vm.currentTab == HomeTab.transfer,
                child: TransferTab(desktop: sizingInformation.isDesktop),
              ),
              if (sizingInformation.isDesktop) _KeepAliveTab(active: vm.currentTab == HomeTab.settings, child: const SettingsPage(desktop: true)),
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
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The Transfers tab shows the transfers themselves, so the
                      // strip only exists while the user is looking elsewhere.
                      if (vm.currentTab != HomeTab.transfer) const TransferMiniBar(),
                      LsTabBar(
                        items: tabItems,
                        index: vm.currentTab.index,
                        onTap: (index) => vm.changeTab(tabs[index]),
                      ),
                    ],
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
///
/// A kept-alive page stays mounted, so it also keeps its tickers running: [TickerMode]
/// mutes the animations of a hidden tab (the radar sweep would otherwise request a
/// frame on every vsync while the user is on another tab).
class _KeepAliveTab extends StatefulWidget {
  final Widget child;

  /// Whether this tab is the one on screen. Only the visible tab may animate.
  final bool active;

  const _KeepAliveTab({required this.child, required this.active});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TickerMode(enabled: widget.active, child: widget.child);
  }
}
