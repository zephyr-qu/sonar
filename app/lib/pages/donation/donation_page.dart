import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:sonar/gen/strings.g.dart';
import 'package:sonar/model/state/purchase_state.dart';
import 'package:sonar/pages/donation/donation_page_vm.dart';
// [FOSS_REMOVE_START]
import 'package:sonar/provider/purchase_provider.dart';
// [FOSS_REMOVE_END]
import 'package:sonar/util/ui/snackbar.dart';
import 'package:sonar/widget/ls/ls_buttons.dart';
import 'package:sonar/widget/ls/ls_dialog.dart';
import 'package:sonar/widget/ls/ls_scaffold.dart';
import 'package:sonar/widget/responsive_list_view.dart';
import 'package:url_launcher/url_launcher.dart';

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
        return LsPageScaffold(
          title: t.donationPage.title,
          body: Stack(
            children: [
              ResponsiveListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 50),
                  Center(
                    child: Text(
                      t.donationPage.info,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 50),
                  if (vm.purchased.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Center(
                        child: Text(
                          t.donationPage.thanks,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                  if (vm.platformSupportPayment) _StoreDonation(vm) else const _LinkDonation(),
                ],
              ),
              if (vm.pending)
                Container(
                  color: Colors.black.withValues(alpha: 0.1),
                  child: const Center(
                    child: CircularProgressIndicator(),
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
    return FilledButton.icon(
      onPressed: availableItems.isEmpty ? null : () => _pickAmount(context, availableItems),
      icon: const Icon(LucideIcons.heart),
      label: Text(t.donationPage.title),
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
    } catch (_) {
      // The store can reject the purchase (e.g. the product is not configured for this build).
      if (context.mounted) {
        context.showSnackBar(t.general.error);
      }
    }
  }
}

class _LinkDonation extends StatelessWidget {
  const _LinkDonation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          await launchUrl(Uri.parse('https://github.com/sponsors/Tienisto'), mode: LaunchMode.externalApplication);
        },
        icon: const Icon(LucideIcons.externalLink),
        label: const Text('Github'),
      ),
    );
  }
}
