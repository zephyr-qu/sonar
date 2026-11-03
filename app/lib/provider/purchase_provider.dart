import 'dart:async';

import 'package:collection/collection.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:sonar/model/state/purchase_state.dart';
import 'package:sonar/util/native/platform_check.dart';

final purchaseProvider = ReduxProvider<PurchaseService, PurchaseState>((ref) {
  return PurchaseService();
});

class PurchaseService extends ReduxNotifier<PurchaseState> {
  @override
  PurchaseState init() => const PurchaseState(
    prices: {},
    purchases: {},
    pending: false,
  );
}

class InitPurchaseStream extends AsyncReduxAction<PurchaseService, PurchaseState> {
  final listening = Completer<void>();

  @override
  Future<PurchaseState> reduce() async {
    Future.delayed(Duration.zero, () => listening.complete());
    await for (final event in InAppPurchase.instance.purchaseStream) {
      for (final purchase in event) {
        // A single bad event must never cancel the stream, otherwise every later
        // purchase / restore callback would be lost for the rest of the session.
        try {
          await dispatchAsync(_HandlePurchaseUpdate(purchase));
        } catch (e) {
          emitMessage('Failed to handle purchase update: $e');
        }
      }
    }
    return state;
  }
}

class FetchPricesAndPurchasesAction extends AsyncReduxAction<PurchaseService, PurchaseState> {
  @override
  Future<PurchaseState> reduce() async {
    if (!checkPlatformSupportPayment()) {
      emitMessage('Platform does not support payments');
      return state;
    }

    if (state.prices.isNotEmpty) {
      emitMessage('Already fetched');
      return state;
    }

    // Loaded silently in the background: labels fall back to the nominal amount and
    // errors are swallowed so a broken billing client cannot stall the page.
    try {
      await dispatchAsync(FetchPricesAction()).timeout(const Duration(seconds: 15));
    } catch (_) {}
    try {
      await dispatchAsync(PurchaseRestoreAction()).timeout(const Duration(seconds: 30));
    } catch (_) {}
    return state;
  }
}

/// Fetches prices for all products.
/// They come from the platform's store and vary by country.
class FetchPricesAction extends AsyncReduxAction<PurchaseService, PurchaseState> {
  @override
  Future<PurchaseState> reduce() async {
    // Devices without a working store (e.g. Android without Play services) never answer,
    // so check availability first and fail fast instead of hanging.
    if (!await _isStoreAvailable()) {
      emitMessage('Store is not available on this device');
      return state;
    }

    final response = await InAppPurchase.instance
        .queryProductDetails(PurchaseItem.values.map((e) => e.platformProductId).toSet())
        .timeout(const Duration(seconds: 15));
    final priceMap = <PurchaseItem, String>{};
    for (final product in response.productDetails) {
      final item = PurchaseItem.values.firstWhereOrNull((e) => e.platformProductId == product.id);
      if (item == null) {
        continue;
      }
      priceMap[item] = product.price;
    }
    return state.copyWith(
      prices: priceMap,
    );
  }
}

/// Handles the update information triggered by the purchase flow of the platform.
class _HandlePurchaseUpdate extends AsyncReduxAction<PurchaseService, PurchaseState> {
  final PurchaseDetails purchase;

  _HandlePurchaseUpdate(this.purchase);

  @override
  bool get trackOrigin => false;

  @override
  Future<PurchaseState> reduce() async {
    if (purchase.status == PurchaseStatus.pending) {
      return state.copyWith(pending: true);
    } else {
      dispatch(_SetPendingAction(false));
    }

    if (purchase.status == PurchaseStatus.error) {
      throw Exception('Error purchasing: ${purchase.error?.message}');
    } else if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
      final purchaseEnum = PurchaseItem.values.firstWhereOrNull((element) => element.platformProductId == purchase.productID);
      if (purchaseEnum == null) {
        throw Exception('Unknown product ID: ${purchase.productID}');
      }
      dispatch(AddPurchaseAction(purchaseEnum, purchase));
    }

    if (purchase.pendingCompletePurchase) {
      // No need to verify. It's just a donation...
      await InAppPurchase.instance.completePurchase(purchase);
    }

    return state;
  }

  @override
  String get debugLabel => 'HandlePurchaseUpdate(${purchase.status}, ${purchase.productID})';
}

class AddPurchaseAction extends ReduxAction<PurchaseService, PurchaseState> {
  final PurchaseItem item;
  final PurchaseDetails purchase;

  AddPurchaseAction(this.item, this.purchase);

  @override
  PurchaseState reduce() {
    return state.copyWith(
      purchases: {
        ...state.purchases,
        item,
      },
    );
  }
}

class _SetPendingAction extends ReduxAction<PurchaseService, PurchaseState> {
  final bool pending;

  _SetPendingAction(this.pending);

  @override
  PurchaseState reduce() => state.copyWith(pending: pending);
}

/// Action to restore purchases.
/// Dispatched when the donation page opens, so bought tiers are hidden again.
class PurchaseRestoreAction extends AsyncReduxAction<PurchaseService, PurchaseState> {
  /// Guards against overlapping restores: a second call while one is in flight
  /// would queue another platform request on top of a non-responsive store.
  static bool _restoring = false;

  @override
  Future<PurchaseState> reduce() async {
    if (_restoring) {
      emitMessage('Restore is already running');
      return state;
    }

    final available = await _isStoreAvailable();
    if (!available) {
      // Without a connected billing client the platform call never completes.
      emitMessage('Store is not available on this device');
      return state;
    }

    _restoring = true;
    try {
      await InAppPurchase.instance.restorePurchases().timeout(const Duration(seconds: 15));
    } catch (e) {
      emitMessage('Restoring purchases failed: $e');
    } finally {
      _restoring = false;
    }
    return state;
  }
}

/// Action to reset the purchase state.
/// Only used for testing.
class PurchaseResetAction extends ReduxAction<PurchaseService, PurchaseState> {
  @override
  PurchaseState reduce() => state.copyWith(
    purchases: {},
    pending: false,
  );
}

/// Initiate the purchase flow for a product.
/// The actual callbacks are handled by [_HandlePurchaseUpdate].
class PurchaseAction extends AsyncReduxAction<PurchaseService, PurchaseState> {
  /// A second tap while the billing client is still answering would stack
  /// another native purchase request, which is what froze the app before.
  static bool _purchasing = false;

  final PurchaseItem item;

  PurchaseAction(this.item);

  @override
  Future<PurchaseState> reduce() async {
    if (_purchasing) {
      throw Exception('A purchase is already running');
    }

    _purchasing = true;
    dispatch(_SetPendingAction(true));
    try {
      if (!await _isStoreAvailable()) {
        throw Exception('Store is not available on this device');
      }

      final response = await InAppPurchase.instance.queryProductDetails(<String>{item.platformProductId}).timeout(const Duration(seconds: 15));
      final productDetails = response.productDetails.firstOrNull;
      if (productDetails == null) {
        throw Exception('Product not found: ${item.platformProductId}');
      }

      // TODO: Handle changing subscriptions if subscriptions would be added
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: productDetails),
      );
    } finally {
      _purchasing = false;
      dispatch(_SetPendingAction(false));
    }

    return state;
  }

  @override
  String get debugLabel => 'BuyAction(${item.name})';
}

/// [InAppPurchase.isAvailable] itself can hang when the billing client never reports
/// a connection state, so never wait for it longer than a few seconds.
Future<bool> _isStoreAvailable() async {
  try {
    return await InAppPurchase.instance.isAvailable().timeout(const Duration(seconds: 5));
  } catch (_) {
    return false;
  }
}
