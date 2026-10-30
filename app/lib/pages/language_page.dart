import 'package:flutter/material.dart';
import 'package:localsend_app/config/design_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/i18n.dart';
import 'package:localsend_app/widget/ls/ls_header.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ls;
    final colors = tokens.colors;
    final t = Translations.of(context);
    final activeLocale = context.ref.watch(settingsProvider.select((s) => s.locale));
    final locales = <AppLocale?>[null, ...AppLocale.values];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LsSubHeader(
                  title: t.settingsTab.general.language,
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: locales.length,
                    separatorBuilder: (_, _) => Divider(color: colors.line, height: 1),
                    itemBuilder: (context, index) {
                      final locale = locales[index];
                      final selected = locale == activeLocale;
                      return InkWell(
                        onTap: () async {
                          await context.ref.notifier(settingsProvider).setLocale(locale);
                          if (locale == null) {
                            await LocaleSettings.useDeviceLocale();
                          } else {
                            await LocaleSettings.setLocale(locale);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  locale?.getLocaleName() ?? t.settingsTab.general.languageOptions.system,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tokens.bodyStrong.copyWith(
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                    color: selected ? colors.fg : colors.muted,
                                  ),
                                ),
                              ),
                              if (selected) Icon(LucideIcons.check, size: 16, color: colors.accent),
                            ],
                          ),
                        ),
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
