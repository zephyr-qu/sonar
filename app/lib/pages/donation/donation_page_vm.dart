import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/model/state/purchase_state.dart';
// [FOSS_REMOVE_START]
import 'package:sonar/provider/purchase_provider.dart';
// [FOSS_REMOVE_END]
import 'package:sonar/util/native/platform_check.dart';

class DonationPageVm {
  final bool platformSupportPayment;
  final Map<PurchaseItem, String> prices;
  final Set<PurchaseItem> purchased;
  final bool pending;
  final Future<void> Function(PurchaseItem item) purchase;

  DonationPageVm({
    required this.platformSupportPayment,
    required this.prices,
    required this.purchased,
    required this.pending,
    required this.purchase,
  });
}

// [FOSS_REMOVE_START]
final donationPageVmProvider = ViewProvider<DonationPageVm>((ref) {
  final state = ref.watch(purchaseProvider);
  return DonationPageVm(
    platformSupportPayment: checkPlatformSupportPayment(),
    prices: state.prices,
    purchased: state.purchases,
    pending: state.pending,
    purchase: (item) => ref.redux(purchaseProvider).dispatchAsync(PurchaseAction(item)),
  );
});
// [FOSS_REMOVE_END]

/// This is a noop version of the original view model.
/// Used to compile the FOSS version of the app by removing the original provider above.
final donationPageNoopVmProvider = ViewProvider<DonationPageVm>((ref) {
  return DonationPageVm(
    platformSupportPayment: false,
    prices: {},
    purchased: {},
    pending: false,
    purchase: (_) async {},
  );
});
