# my_printers_brother

A Flutter plugin for printing on Brother label, receipt and mobile printers, plus Brother TypeB printers, on Android and iOS.

This is a fork of [another_brother](https://github.com/CodeMinion/another_brother) by Rounin Labs. It bundles Brother Print SDK 4.13.2 and adds support for newer printers such as the RJ-4235B.

## Migrating from another_brother

1. Rename the dependency in your `pubspec.yaml`:
   ```yaml
   dependencies:
     # Before
     # another_brother: ^2.2.4
     # After
     my_printers_brother: ^3.0.0
   ```
2. Update your imports:
   ```dart
   // Before
   import 'package:another_brother/printer_info.dart';
   // After
   import 'package:my_printers_brother/printer_info.dart';
   ```
3. Raise your iOS deployment target to 14.0 and your Android `minSdkVersion` to 21 if they are lower.
4. If you relied on Android native failures crashing the app or being ignored, handle `PlatformException` (see [Handle errors](#handle-errors)).

The Dart API is otherwise unchanged. See [CHANGELOG.md](CHANGELOG.md) for the full list of changes in 3.0.0.

## Features

| Connection | Android | iOS |
|---|:---:|:---:|
| Wi-Fi / network | ✓ | ✓ |
| Bluetooth Classic | ✓ | ✓ (MFi) |
| Bluetooth Low Energy | ✓ | ✓ |
| USB | ✓ | — |

- Print images, PDFs and files, and P-touch Templates (Android).
- Discover printers on the network, paired over Bluetooth, or over BLE.
- Read printer status, battery, firmware and settings (several of these are Android-only, see [Platform differences](#platform-differences)).
- Use Brother's custom paper files (`BinPaper_*` classes) or define paper sizes in code with `CustomPaperInfo`.
- TypeB printers through `TbPrinter`.

## Supported printers

Printer models are listed in `Model` (`lib/printer_info.dart`) and include the QL, PT, TD, RJ, PJ and MW series. Each model maps to the Brother Print SDK model of the same name.

Added in this fork: **RJ-4235B** (`Model.RJ_4235B`).

## Requirements

- Android `minSdkVersion` 21 or later.
- iOS 14.0 or later.
- Bundled native SDKs:
  - Brother Print SDK 4.13.2 for Android (`android/libs/repo`) and iOS (`ios/Frameworks`).
  - Brother TypeB SDK: `com.brother.typeb:print:1.0.0` on Android (`android/libs/repo`) and the `BROTHERSDK` pod on iOS.

## Installation

The plugin is published on [pub.dev](https://pub.dev/packages/my_printers_brother). Add it to your app:

```sh
flutter pub add my_printers_brother
```

Or add it to your `pubspec.yaml` yourself:

```yaml
dependencies:
  my_printers_brother: ^3.0.0
```

### Android setup

The plugin declares the Bluetooth, location, network and storage permissions it uses in its own manifest. On Android 6.0 and later, your app must still request the runtime permissions before scanning or connecting, for example with [permission_handler](https://pub.dev/packages/permission_handler):

- Android 12 and later: `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`.
- Android 11 and earlier: `ACCESS_FINE_LOCATION` for Bluetooth scanning.

USB printing asks the user for permission to access the printer the first time it is used.

### iOS setup

Set the deployment target to iOS 14 in `ios/Podfile`:

```ruby
platform :ios, '14.0'
```

Add the following to your `Info.plist`:

```xml
<!-- my_printers_brother -->
<key>NSLocalNetworkUsageDescription</key>
<string>Looking for local tcp Bonjour service</string>
<key>NSBonjourServices</key>
<array>
    <string>_ipp._tcp</string>
    <string>_printer._tcp</string>
    <string>_pdl-datastream._tcp</string>
</array>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notifications</string>
</array>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Need BLE permission</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Need BLE permission</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Need Location permission</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Need Location permission</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Need Location permission</string>
<key>UISupportedExternalAccessoryProtocols</key>
<array>
    <string>com.brother.ptcbp</string>
    <!-- Only needed for TypeB printers. Don't include it in App Store builds, it leads to a rejection. -->
    <string>com.issc.datapath</string>
</array>
<!-- End my_printers_brother -->
```

Replace the usage descriptions with text that explains why your app needs each permission.

#### Publishing to the App Store

Apps that talk to Brother printers over Bluetooth (MFi) need a PPID from Brother before App Store submission. Request one at https://secure6.brother.co.jp/mfi/Top.aspx. Without it, the review is likely to be rejected with:

```
App has not been authorized by the accessory manufacturer to work with the MFi accessory
```

## Usage

### Print an image over the network

```dart
import 'dart:ui' as ui;

import 'package:my_printers_brother/label_info.dart';
import 'package:my_printers_brother/printer_info.dart';

Future<void> printLabel(ui.Image image) async {
  final printer = Printer();
  final printInfo = PrinterInfo()
    ..printerModel = Model.QL_1110NWB
    ..port = Port.NET
    ..ipAddress = '192.168.1.20'
    ..printMode = PrintMode.FIT_TO_PAGE
    ..isAutoCut = true
    ..labelNameIndex = QL1100.ordinalFromID(QL1100.W62.getId());
  await printer.setPrinterInfo(printInfo);

  final PrinterStatus status = await printer.printImage(image);
  if (status.errorCode != ErrorCode.ERROR_NONE) {
    print('Print failed: ${status.errorCode.getName()}');
  }
}
```

`printPdfFile(path, page)`, `printFile(path)` and `printFileList(paths)` work the same way.

### Find printers

```dart
final printer = Printer();

// Printers on the local network.
final List<NetPrinter> netPrinters =
    await printer.getNetPrinters([Model.QL_1110NWB.getName()]);

// Printers paired over Bluetooth. Use macAddress with Port.BLUETOOTH.
final List<BluetoothPrinter> btPrinters =
    await printer.getBluetoothPrinters([Model.RJ_4235B.getName()]);

// Printers advertising over BLE, scanning for 5 seconds.
final List<BLEPrinter> blePrinters = await printer.getBLEPrinters(5000);
```

### Print on an RJ-4235B with a custom paper size

The RJ-4235B has no bundled paper file, so describe the paper in code:

```dart
final printInfo = PrinterInfo()
  ..printerModel = Model.RJ_4235B
  ..port = Port.BLUETOOTH
  ..macAddress = btPrinters.first.macAddress
  ..printMode = PrintMode.FIT_TO_PAGE
  // Example: 4 inch continuous roll. Adjust the width and margins to your media.
  ..customPaperInfo = CustomPaperInfo.newCustomRollPaper(
      Model.RJ_4235B, Unit.Mm, 101.6, 0.0, 0.0, 0.0);
await printer.setPrinterInfo(printInfo);
```

For printers with bundled paper files, set `binCustomPaper` instead, for example `BinPaper_RJ4230.RD_W4in`.

### Keep the connection open

Each print call opens and closes its own connection. To send several jobs in a row, open the connection once:

```dart
await printer.startCommunication();
await printer.printImage(firstImage);
await printer.printImage(secondImage);
await printer.endCommunication();
```

### Handle errors

Printing calls report printer-side problems through `PrinterStatus.errorCode`. If the native side fails unexpectedly on Android, for example because of an invalid argument, the call throws a `PlatformException` with code `NATIVE_ERROR` instead of crashing the app:

```dart
try {
  final status = await printer.printImage(image);
} on PlatformException catch (e) {
  if (e.code == 'NATIVE_ERROR') {
    // e.message describes the failure; e.details holds the native stack trace.
  }
}
```

USB printing returns `ERROR_COMMUNICATION_ERROR` if the user denies access to the printer, or doesn't answer within 60 seconds.

### TypeB printers

TypeB printers use `TbPrinter` and `TbPrinterInfo` from `package:my_printers_brother/type_b_printer.dart`. Call `startCommunication()` first; it returns `false` if the printer can't be reached.

## Platform differences

### Android-only APIs

These `Printer` methods are not implemented on iOS and throw a `MissingPluginException` there:

- Printer info: `getFirmVersion`, `getMediaVersion`, `getSerialNumber`, `getBatteryWeak`, `getBatteryInfo`, `getBootMode`, `getFirmFileVer`, `getMediaFileVer`, `getSystemReport`, `getLabelInfo`, `getLabelParam`, `getNetPrinterInfo`
- Settings: `getPrinterSettings`, `updatePrinterSettings`, `getBluetoothPreference`, `updateBluetoothPreference`
- P-touch Templates: `transfer`, `getTemplateList`, `removeTemplate`, `startPTTPrint`, `replaceText`, `replaceTextIndex`, `replaceTextName`, `flushPTTPrint`
- Data transfer: `sendBinary`, `sendBinaryFile`, `sendDatabase`, `updateFirm`

Each of these is marked "Available on Android only." in its documentation.

### iOS simulator

TypeB printers are not available on the iOS simulator, because Brother's TypeB library (`libBROTHERSDK.a`) only supports devices. On the simulator, `TbPrinter.startCommunication()` returns `false`.

## Development

Run the tests from the repository root:

```sh
flutter test
```

The tests cover:

- **`test/my_printers_brother_test.dart`:** the method channel calls each Dart method sends and how results are parsed, using a mock native side.
- **`test/channel_contract_test.dart`:** every method Dart calls is handled on Android, and the methods missing on iOS match the documented Android-only list.
- **`test/custom_paper_assets_test.dart`:** every custom paper path points to a bundled `.bin` file under this package's asset path.

### Updating the Brother SDK

The Brother Print SDK is downloaded from Brother's [Mobile SDK page](https://support.brother.com/g/s/es/dev/en/mobilesdk/download/index.html).

- **Android:** copy `libs/BrotherPrintLibrary.aar` to `android/libs/repo/com/brother/sdk/printer/<version>/printer-<version>.aar`, add a matching `.pom`, and update the version in `android/build.gradle`.
- **iOS:** replace `ios/Frameworks/BRLMPrinterKit.xcframework` with the one in the SDK's `libs/BT_Net` folder (the `Net` build has no Bluetooth support).
- **New printer models:**
  - Add a `Model` entry whose id matches the SDK's `PrinterInfo.Model` id, because Android looks models up by id.
  - Add the `BRLMPrinterModel` mapping in `ios/Classes/Method/BrotherUtils.m`.

## License

The plugin code is licensed under the BSD license in [LICENSE](LICENSE), © 2021 Rounin Labs.

The Brother Print SDK and TypeB SDK are © Brother Industries, Ltd. and are licensed under Brother's End-User License Agreement, not the plugin's license. Review Brother's terms before distributing an app that includes them.

## Credits

Based on [another_brother](https://github.com/CodeMinion/another_brother) by Rounin Labs. For a full demo app of the original plugin, see [Another-Brother-Demo-Prime](https://github.com/CodeMinion/Demo-Another-Brother-Prime).
