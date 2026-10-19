import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Runs a single BLE scan that lasts [timeout] and returns every device seen.
/// The scan results listener is always cancelled, and a scan failure is rethrown.
Future<List<ScanResult>> scanBle(
    {required Duration timeout, List<Guid> withServices = const []}) async {
  List<ScanResult> latest = [];
  Object? scanError;

  // Each event holds all the results since the scan started.
  final subscription = FlutterBluePlus.onScanResults.listen(
      (results) => latest = results,
      onError: (Object e) => scanError ??= e);

  try {
    await FlutterBluePlus.startScan(withServices: withServices, timeout: timeout);
    // startScan returns once scanning begins, so wait for the timeout to stop it.
    await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
  } finally {
    await subscription.cancel();
  }

  if (scanError != null) {
    throw scanError!;
  }
  return latest;
}
