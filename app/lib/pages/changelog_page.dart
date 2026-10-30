import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/assets.gen.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/ui/nav_bar_padding.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:routerino/routerino.dart';

class ChangelogPage extends StatelessWidget {
  const ChangelogPage();

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LsSubHeader(
                  title: t.changelogPage.title,
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: FutureBuilder(
                    future: rootBundle.loadString(Assets.changelog), // ignore: discarded_futures
                    builder: (context, data) {
                      if (!data.hasData) {
                        return const SizedBox();
                      }
                      return Markdown(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + getNavBarPadding(context)),
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          p: tokens.body,
                          h1: tokens.display,
                          h2: tokens.title,
                          h3: tokens.title,
                          listBullet: tokens.body,
                        ),
                        data: data.data!,
                      );
                    },
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
