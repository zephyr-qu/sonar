import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/persistence/favorite_device.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';

class FavoriteDeleteDialog extends StatelessWidget {
  final FavoriteDevice favorite;

  const FavoriteDeleteDialog(this.favorite);

  @override
  Widget build(BuildContext context) {
    return LsDialog(
      title: Text(t.dialogs.favoriteDeleteDialog.title),
      content: Text(t.dialogs.favoriteDeleteDialog.content(name: favorite.alias)),
      actions: [
        LsButton(
          label: t.general.cancel,
          variant: LsButtonVariant.ghost,
          onPressed: () => context.pop(),
        ),
        LsButton(
          label: t.general.delete,
          onPressed: () => context.pop(true),
        ),
      ],
    );
  }
}
