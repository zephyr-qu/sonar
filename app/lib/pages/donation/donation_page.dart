import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/config/design_tokens.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/state/purchase_state.dart';
import 'package:sonar/pages/donation/donation_page_vm.dart';
// [FOSS_REMOVE_START]
import 'package:sonar/provider/purchase_provider.dart';
// [FOSS_REMOVE_END]
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_card.dart';
import 'package:sonar/widget/ls/ls_chip.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';
import 'package:sonar/widget/ls/ls_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

final _logger = Logger('DonationPage');

class DonationPage extends StatelessWidget {
  const DonationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => donationPageVmProvider,
      // [FOSS_REMOVE_START]
      init: (context) => context.redux(purchaseProvider).dispatchAsync(FetchPricesAndPurchasesAction()), // ignore: discarded_futures
      // [FOSS_REMOVE_END]
      builder: (context, vm) {
        final tokens = context.ls;
        final colors = tokens.colors;
        // Only offer the store when it actually resolved products for this build: a
        // rebranded or sideloaded build owns no SKUs, so every purchase would fail.
        final canBuy = vm.platformSupportPayment && vm.prices.isNotEmpty;

        return LsPageScaffold(
          title: t.donationPage.title,
          body: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(tokens.pad, 4, tokens.pad, 32),
                children: [
                  LsCard(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentSoft),
                          child: Icon(LucideIcons.heart, size: 22, color: colors.accent),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          t.donationPage.info,
                          textAlign: TextAlign.center,
                          style: tokens.bodySm.copyWith(color: colors.fg),
                        ),
                        const SizedBox(height: 18),
                        if (vm.purchased.isNotEmpty) ...[
                          LsChip.text(t.donationPage.thanks, accent: true),
                          const SizedBox(height: 14),
                        ],
                        if (canBuy) _StoreDonation(vm) else const _LinkDonation(),
                        if (canBuy) ...[
                          const SizedBox(height: 8),
                          const _LinkDonation(variant: LsButtonVariant.ghost),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          t.donationPage.note,
                          textAlign: TextAlign.center,
                          style: tokens.label,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (vm.pending)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.1),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StoreDonation extends StatelessWidget {
  final DonationPageVm vm;

  const _StoreDonation(this.vm);

  @override
  Widget build(BuildContext context) {
    // Purchased tiers are dropped instead of being rendered as disabled buttons,
    // so the amount picker only ever offers what can still be bought.
    final availableItems = PurchaseItem.values.where((item) => !vm.purchased.contains(item)).toList();
    return LsButton(
      label: t.donationPage.title,
      icon: LucideIcons.heart,
      expand: true,
      onPressed: availableItems.isEmpty ? null : () => _pickAmount(context, availableItems),
    );
  }

  Future<void> _pickAmount(BuildContext context, List<PurchaseItem> items) async {
    final selected = await showDialog<PurchaseItem>(
      context: context,
      builder: (context) => LsDialog(
        title: Text(t.donationPage.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LsButton(
                  label: t.donationPage.donate(amount: vm.prices[item] ?? item.amount),
                  icon: LucideIcons.heart,
                  variant: LsButtonVariant.plain,
                  expand: true,
                  onPressed: () => context.pop(item),
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
        ],
      ),
    );
    if (selected == null) {
      return;
    }
    try {
      await vm.purchase(selected);
    } catch (e) {
      // The store can reject the purchase (e.g. the product is not configured for this build).
      _logger.warning('Purchase failed', e);
      if (context.mounted) {
        context.showSnackBar(t.general.error);
      }
    }
  }
}

/// Opens the github sponsors page: the only option where the stores are not
/// available, a secondary one next to the store button otherwise.
class _LinkDonation extends StatelessWidget {
  final LsButtonVariant variant;

  const _LinkDonation({this.variant = LsButtonVariant.primary});

  @override
  Widget build(BuildContext context) {
    return LsButton(
      label: 'GitHub Sponsors',
      icon: LucideIcons.externalLink,
      variant: variant,
      expand: true,
      onPressed: () async {
        await launchUrl(Uri.parse('https://github.com/sponsors/Tienisto'), mode: LaunchMode.externalApplication);
      },
    );
  }
}
