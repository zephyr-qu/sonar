import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path/path.dart' as path;
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/transfer_history_session.dart';
import 'package:sonar/provider/transfer_history_provider.dart';
import 'package:sonar/util/file_type_ext.dart';
import 'package:sonar/util/native/open_file.dart';
import 'package:sonar/util/native/open_folder.dart';
import 'package:sonar/util/system_date_time_formatter.dart';
import 'package:sonar/widget/dialogs/file_info_dialog.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_header.dart';
import 'package:sonar/widget/ls/ls_hover.dart';
import 'package:sonar/widget/ls/ls_menu.dart';
import 'package:sonar/widget/ls/ls_search_field.dart';
import 'package:sonar/widget/ls/ls_segmented.dart';
import 'package:sonar/widget/responsive_builder.dart';
import 'package:sonar_isolates/model/file_type.dart';
import 'package:sonar_isolates/util/file_size_helper.dart';

enum _SortMode {
  date,
  name,
  size
  ;

  String get label => switch (this) {
    // The strings still carry the direction they used to bake in (`Date ↓`), but
    // the direction is now its own toggle; strip it so all 60 locales agree.
    _SortMode.date => t.transferTab.sortDate,
    _SortMode.name => t.transferTab.sortName,
    _SortMode.size => t.transferTab.sortSize,
  }.replaceFirst(RegExp(r'\s*[↑↓]\s*$'), '');

  /// Whether this mode starts out ascending: names read A→Z, while dates and
  /// sizes are most useful newest/largest first.
  bool get defaultAscending => this == _SortMode.name;
}

enum _FileAction {
  open,
  showInFolder,
  info,
  delete
  ;

  String get label {
    return switch (this) {
      _FileAction.open => t.receiveHistoryPage.entryActions.open,
      _FileAction.showInFolder => t.receiveHistoryPage.entryActions.showInFolder,
      _FileAction.info => t.receiveHistoryPage.entryActions.info,
      _FileAction.delete => t.receiveHistoryPage.entryActions.deleteFromHistory,
    };
  }
}

/// Second level of the transfer tab: all files of one finished transfer session,
/// searchable and switchable between list and grid, like the design's detail page.
class TransferDetailPage extends StatefulWidget {
  final TransferHistorySession session;

  const TransferDetailPage({required this.session, super.key});

  @override
  State<TransferDetailPage> createState() => _TransferDetailPageState();
}

class _TransferDetailPageState extends State<TransferDetailPage> {
  late List<TransferHistoryFile> _files = widget.session.files.toList();
  String _query = '';

  /// Null means "all types".
  FileType? _type;
  _SortMode _sort = _SortMode.date;

  /// Direction of [_sort]. Picking another mode resets it to that mode's default
  /// (see [_SortMode.defaultAscending]) rather than carrying over, which would
  /// open "Date" oldest-first for anyone who had just sorted names A→Z.
  bool _ascending = false;
  bool _grid = _rememberGrid;

  TransferHistorySession get _session => widget.session;

  List<TransferHistoryFile> get _visibleFiles {
    final needle = _query.trim().toLowerCase();
    final filtered = _files.where((file) {
      if (_type != null && file.fileType != _type) {
        return false;
      }
      return needle.isEmpty || file.fileName.toLowerCase().contains(needle);
    }).toList();

    final sorted = [...filtered];
    sorted.sort((a, b) {
      // A file with no announced modification date stays last either way, so the
      // direction is applied to the actual comparison only.
      if (_sort == _SortMode.date && (a.modified == null || b.modified == null)) {
        return a.modified == null ? (b.modified == null ? 0 : 1) : -1;
      }
      final result = _compare(a, b);
      return _ascending ? result : -result;
    });
    return sorted;
  }

  /// [a] before [b] when ascending: oldest first, A→Z, smallest first.
  int _compare(TransferHistoryFile a, TransferHistoryFile b) {
    return switch (_sort) {
      _SortMode.date => a.modified!.compareTo(b.modified!),
      _SortMode.name => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
      _SortMode.size => a.fileSize.compareTo(b.fileSize),
    };
  }

  void _selectSort(_SortMode sort) {
    setState(() {
      _sort = sort;
      _ascending = sort.defaultAscending;
    });
  }

  /// Types that actually occur in this session, with their file count.
  Map<FileType, int> get _typeCounts {
    final counts = <FileType, int>{};
    for (final file in _files) {
      counts[file.fileType] = (counts[file.fileType] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _open(TransferHistoryFile file) async {
    if (file.isMessage) {
      await _showInfo(file);
      return;
    }
    final filePath = file.path;
    if (filePath == null) {
      return;
    }
    await openFile(
      context,
      file.fileType,
      filePath,
      onDeleteTap: () => _delete(file),
    );
  }

  Future<void> _showInFolder(TransferHistoryFile file) async {
    final filePath = file.path;
    if (filePath == null) {
      return;
    }
    await openFolder(folderPath: File(filePath).parent.path, fileName: path.basename(filePath));
  }

  Future<void> _showInfo(TransferHistoryFile file) async {
    await showDialog(
      context: context,
      builder: (_) => FileInfoDialog(file: file, session: _session),
    );
  }

  Future<void> _delete(TransferHistoryFile file) async {
    await context
        .redux(transferHistoryProvider)
        .dispatchAsync(
          RemoveTransferHistoryFileAction(sessionId: _session.id, fileId: file.id),
        );
    if (!mounted) {
      return;
    }
    setState(() => _files = _files.where((f) => f.id != file.id).toList());
    if (_files.isEmpty) {
      context.pop();
    }
  }

  Future<void> _onAction(TransferHistoryFile file, _FileAction action) {
    return switch (action) {
      _FileAction.open => _open(file),
      _FileAction.showInFolder => _showInFolder(file),
      _FileAction.info => _showInfo(file),
      _FileAction.delete => _delete(file),
    };
  }

  Future<void> _openFolder() async {
    final filePath = _files.where((file) => file.path != null && file.path!.isNotEmpty).map((file) => file.path!).firstOrNull;
    if (filePath == null) {
      return;
    }
    await openFolder(folderPath: File(filePath).parent.path);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final files = _visibleFiles;
    final totalSize = _files.fold<int>(0, (sum, file) => sum + file.fileSize);
    // The page is pushed over the whole window, so the content column follows the
    // window instead of staying a phone-width strip on a wide desktop window.
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    return _DetailScaffold(
      title: _session.isSend ? t.transferTab.sentTo(device: _session.peerAlias) : t.transferTab.receivedFrom(device: _session.peerAlias),
      subtitle: Text(
        [
          SystemDateTimeFormatter.dateTime(context, _session.timestamp.toLocal()),
          totalSize.asReadableFileSize,
          // The size is everything a delivered session has to say; a failed one
          // also has to say that it failed, and why.
          if (_session.failed) t.transferTab.failed,
          if (_session.errorMessage != null) _session.errorMessage!,
        ].join('  '),
        style: tokens.mono,
      ),
      maxWidth: wide ? 1120 : 760,
      // The direction and gallery state sit next to the title instead of in a
      // chip row of their own: the row repeated the title and the item count.
      actions: [
        const SizedBox(width: 10),
        if (_session.savedToGallery) ...[
          LsChip.text(t.progressPage.savedToGallery, accent: true),
          const SizedBox(width: 6),
        ],
        LsChip.text(_session.isSend ? t.transferTab.sent : t.transferTab.received),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.pad),
            child: LsSearchField(
              hint: t.transferTab.searchInSession(n: _files.length),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 26,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: tokens.pad),
              children: [
                LsChip.text(
                  t.transferTab.allItems(n: _files.length),
                  accent: _type == null,
                  onTap: () => setState(() => _type = null),
                ),
                for (final MapEntry(key: type, value: count) in _typeCounts.entries) ...[
                  const SizedBox(width: 6),
                  LsChip.text(
                    '${_typeLabel(type)} $count',
                    accent: _type == type,
                    onTap: () => setState(() => _type = type),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: files.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: tokens.pad, vertical: 24),
                    child: Text(t.transferTab.noResults, style: tokens.bodySm),
                  )
                : _grid
                ? _buildGrid(files)
                : _buildList(files),
          ),
        ],
      ),
      footer: _buildFooter(context, files),
    );
  }

  String _typeLabel(FileType type) {
    return switch (type) {
      FileType.image => t.transferTab.typeImage,
      FileType.video => t.transferTab.typeVideo,
      FileType.pdf => t.transferTab.typePdf,
      FileType.text => t.transferTab.typeText,
      FileType.apk => t.transferTab.typeApk,
      FileType.other => t.transferTab.typeOther,
    };
  }

  Widget _buildList(List<TransferHistoryFile> files) {
    final tokens = context.ls;
    final colors = tokens.colors;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(tokens.pad, 2, tokens.pad, 12),
      itemCount: files.length,
      separatorBuilder: (_, _) => Divider(height: tokens.hairlineOf(context) * 2, thickness: tokens.hairlineOf(context), color: colors.line),
      itemBuilder: (context, index) {
        final file = files[index];
        return _DetailFileRow(
          file: file,
          onTap: () async => _open(file),
          onAction: (action) async => _onAction(file, action),
        );
      },
    );
  }

  Widget _buildGrid(List<TransferHistoryFile> files) {
    final tokens = context.ls;
    return LayoutBuilder(
      builder: (context, constraints) {
        // A phone keeps the prototype's four columns; a wider window adds columns
        // instead of stretching the tiles, so a square stays around 104px rather
        // than growing to ~130px on a maximized desktop window.
        final columns = (constraints.maxWidth / 104).floor().clamp(4, 12);
        const spacing = 5.0;
        final cellWidth = (constraints.maxWidth - tokens.pad * 2 - spacing * (columns - 1)) / columns;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(tokens.pad, 2, tokens.pad, 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: spacing,
            // The caption gets a fixed pixel band instead of a share of the tile height: a percentage
            // stretch (`childAspectRatio: 1 / 1.24`) leaves fewer pixels for the two-line name than the
            // text needs on phone columns, and the name then paints outside its cell.
            mainAxisExtent: cellWidth + _gridCaptionHeight(context),
          ),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return _DetailFileCell(file: file, onTap: () async => _open(file));
          },
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, List<TransferHistoryFile> files) {
    final tokens = context.ls;
    // A phone has no room for the 44px standalone button next to the sort chip
    // and the view switch, so the action drops into their 30px band and the
    // (already duplicated) file counter of the header gives way.
    final mobile = SizingInformation(MediaQuery.sizeOf(context).width).isMobile;
    return Padding(
      padding: EdgeInsets.fromLTRB(tokens.pad, 10, tokens.pad, 10),
      child: Row(
        children: [
          LsButton(
            label: t.transferTab.openFolder,
            icon: LucideIcons.folder,
            variant: LsButtonVariant.ghost,
            compact: mobile,
            onPressed: _session.hasLocalPath ? _openFolder : null,
          ),
          const Spacer(),
          if (!mobile) ...[
            Text('${files.length} / ${_files.length}', style: tokens.monoSm),
            const SizedBox(width: 8),
          ],
          LsMenuChip<_SortMode>(
            label: _sort.label,
            tooltip: t.transferTab.sort,
            items: [
              for (final sort in _SortMode.values) LsMenuItem(value: sort, label: sort.label, checked: sort == _sort),
            ],
            onSelected: _selectSort,
          ),
          const SizedBox(width: 4),
          // The chip label no longer carries the direction, so it gets its own
          // one-tap toggle next to it; the glyph shows the state in effect.
          LsIconButton(
            icon: _ascending ? LucideIcons.arrowUpNarrowWide : LucideIcons.arrowDownWideNarrow,
            tooltip: _ascending ? t.transferTab.sortAscending : t.transferTab.sortDescending,
            onPressed: () => setState(() => _ascending = !_ascending),
          ),
          const SizedBox(width: 8),
          // [LsSegmented] lays its items out with [Expanded], so it needs a bounded
          // width: a plain [Row] child gets an unbounded one and fails `performLayout`.
          SizedBox(
            width: 88,
            child: LsSegmented(
              options: [t.transferTab.gridView, t.transferTab.listView],
              icons: const [LucideIcons.layoutGrid, LucideIcons.list],
              index: _grid ? 0 : 1,
              onChanged: (index) => setState(() {
                _grid = index == 0;
                _rememberGrid = _grid;
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// The page shell of the second-level page.
///
/// The header and the footer bar span the whole window while the scrollable
/// content stays centered in a readable column, so the page does not look like a
/// phone screen glued into the middle of a maximized desktop window.
class _DetailScaffold extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final double maxWidth;
  final Widget body;
  final Widget footer;
  final List<Widget> actions;

  const _DetailScaffold({
    required this.title,
    required this.subtitle,
    required this.maxWidth,
    required this.body,
    required this.footer,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final hairline = tokens.hairlineOf(context);

    return CallbackShortcuts(
      bindings: {
        // Desktop users expect Esc to leave a second-level page.
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colors.line, width: hairline),
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: LsSubHeader(
                        title: title,
                        subtitle: subtitle,
                        actions: actions,
                        onBack: () => Navigator.maybePop(context),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: body,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: colors.line, width: hairline),
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: footer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One file of the detail page in list mode: name, modification date and size.
class _DetailFileRow extends StatelessWidget {
  final TransferHistoryFile file;
  final VoidCallback onTap;
  final Future<void> Function(_FileAction action) onAction;

  const _DetailFileRow({required this.file, required this.onTap, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final canOpen = file.path != null || file.isMessage;
    final options = file.path != null ? _FileAction.values : const [_FileAction.open, _FileAction.info, _FileAction.delete];

    return LsHover(
      color: Colors.transparent,
      hoverColor: colors.bg2,
      borderRadius: tokens.tileRadius,
      cursor: canOpen ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onTap: canOpen ? onTap : null,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            _KindBox(kind: _kindOf(file), size: 24),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                file.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.bodyStrong,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _shortDate(file.modified),
              style: tokens.monoSm.copyWith(color: colors.faint),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 62,
              child: Text(
                file.fileSize.asReadableFileSize,
                textAlign: TextAlign.end,
                style: tokens.monoSm,
              ),
            ),
            SizedBox(
              width: 28,
              child: LsMenuButton<_FileAction>(
                icon: LucideIcons.moreHorizontal,
                compact: true,
                dense: true,
                // Hangs off the trigger's right edge: the row's ⋯ sits against the
                // window edge, so a left-anchored panel would be clamped flush to it.
                panelWidth: 150,
                alignRight: true,
                items: [
                  for (final option in options) LsMenuItem(value: option, label: option.label),
                ],
                onSelected: (action) async {
                  await onAction(action);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One file of the detail page in grid mode: a tinted tile with the file kind
/// and the file name below it (the design keeps real thumbnails out of v1).
class _DetailFileCell extends StatelessWidget {
  final TransferHistoryFile file;
  final VoidCallback onTap;

  const _DetailFileCell({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final gradient = _photoGradient(file);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Tooltip(
            message: '${file.fileName}\n${file.fileSize.asReadableFileSize}',
            child: LsHover(
              color: gradient == null ? (lsKindTint[fileKind(file.fileName, fallback: '')] ?? colors.bg3) : Colors.transparent,
              hoverColor: gradient == null ? colors.bg3 : colors.fg.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(9),
              borderColor: colors.line,
              onTap: onTap,
              builder: (context, hovered) => Container(
                alignment: Alignment.center,
                decoration: gradient == null ? null : BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(9)),
                child: Text(
                  _kindOf(file),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.monoSm.copyWith(color: colors.fg.withValues(alpha: 0.82), letterSpacing: 0.4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // [Flexible] bounds the caption to the band the grid reserved for it, so a text scale or a
        // longer name ellipsizes instead of overflowing the cell.
        Flexible(
          child: Text(
            file.fileName,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: tokens.label.copyWith(height: _gridCaptionLineHeight, fontSize: _gridCaptionFontSize),
          ),
        ),
      ],
    );
  }
}

/// The 24px kind plate of a file row.
class _KindBox extends StatelessWidget {
  final String kind;
  final double size;

  const _KindBox({required this.kind, required this.size});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tokens.colors.bg3, borderRadius: BorderRadius.circular(7)),
      child: Text(
        kind,
        maxLines: 1,
        style: tokens.monoSm.copyWith(color: tokens.colors.muted),
      ),
    );
  }
}

/// The uppercase extension of a file name, or the type name as a fallback.
String _kindOf(TransferHistoryFile file) {
  if (file.isMessage) {
    return 'MSG';
  }
  return fileKind(file.fileName, fallback: file.fileType.name.toUpperCase());
}

/// `MM-DD HH:mm`: the fixed-width form the design uses next to the file size.
///
/// The full locale format is too wide for the mono column and the year is
/// already in the page header.
String _shortDate(DateTime? value) {
  if (value == null) {
    return '—';
  }
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

/// Whether the last opened detail page was shown as a grid.
///
/// The design remembers the chosen view when the page is opened again, which a
/// state field per page cannot do.
bool _rememberGrid = false;

/// The two-line caption under a grid tile: 9px on a 1.3 line box, with the 4px gap above it.
/// The grid reserves exactly [_gridCaptionHeight] as a fixed band, so the name always has room
/// to render its two lines and ellipsizes beyond that instead of painting past the cell. The band
/// follows the text scale, like the pending-file tray, so a larger system font grows the cell.
const double _gridCaptionFontSize = 9;
const double _gridCaptionLineHeight = 1.3;
double _gridCaptionHeight(BuildContext context) => 4 + 2 * MediaQuery.textScalerOf(context).scale(_gridCaptionFontSize) * _gridCaptionLineHeight;

/// Hue, saturation, lightness of both gradient stops and their opacity, per
/// photo tint. The design cycles through six of them so a grid of images does
/// not read as one flat block.
const _photoTints = <({double hue, double saturation, double top, double bottom, double topAlpha, double bottomAlpha})>[
  (hue: 214, saturation: 0.48, top: 0.44, bottom: 0.26, topAlpha: 0.42, bottomAlpha: 0.18),
  (hue: 266, saturation: 0.38, top: 0.46, bottom: 0.26, topAlpha: 0.36, bottomAlpha: 0.16),
  (hue: 182, saturation: 0.36, top: 0.40, bottom: 0.24, topAlpha: 0.34, bottomAlpha: 0.15),
  (hue: 32, saturation: 0.52, top: 0.42, bottom: 0.24, topAlpha: 0.34, bottomAlpha: 0.15),
  (hue: 92, saturation: 0.34, top: 0.38, bottom: 0.22, topAlpha: 0.30, bottomAlpha: 0.13),
  (hue: 352, saturation: 0.42, top: 0.44, bottom: 0.24, topAlpha: 0.32, bottomAlpha: 0.15),
];

/// The gradient of a grid tile, or null when the file is not an image.
LinearGradient? _photoGradient(TransferHistoryFile file) {
  if (file.isMessage || file.fileType != FileType.image) {
    return null;
  }
  final tint = _photoTints[_nameHash(file.fileName) % _photoTints.length];
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      HSLColor.fromAHSL(tint.topAlpha, tint.hue, tint.saturation, tint.top).toColor(),
      HSLColor.fromAHSL(tint.bottomAlpha, tint.hue, tint.saturation, tint.bottom).toColor(),
    ],
  );
}

/// Picks a stable tile tint per file name, like the design does.
int _nameHash(String text) {
  var hash = 0;
  for (final unit in text.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}
