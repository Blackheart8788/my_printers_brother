import 'package:my_printers_brother/my_printers_brother.dart';
import 'package:my_printers_brother/bluetooth_preference.dart';
import 'package:my_printers_brother/printer_info.dart';
import 'package:my_printers_brother/type_b_printer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('another_brother');

  // Calls received by the mock native side, and how it replies to them.
  final List<MethodCall> calls = [];
  late Object? Function(MethodCall call) reply;

  setUp(() {
    calls.clear();
    reply = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return reply(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Map<String, dynamic> statusMap(ErrorCode errorCode) =>
      PrinterStatus(errorCode: errorCode).toMap();

  test('platformVersion', () async {
    reply = (_) => 'Android 15';

    expect(await AnotherBrother.platformVersion, 'Android 15');
    expect(calls.single.method, 'getPlatformVersion');
  });

  group('Printer', () {
    late Printer printer;

    setUp(() {
      printer = Printer();
    });

    test('identifies the printer in every call', () async {
      reply = (_) => statusMap(ErrorCode.ERROR_NONE);

      await printer.getPrinterStatus();

      final Map args = calls.single.arguments;
      expect(args['printerId'], printer.mPrinterId);
      expect(args['printInfo'], isA<Map>());
    });

    test('getPrinterStatus parses the returned status', () async {
      reply = (_) => statusMap(ErrorCode.ERROR_COMMUNICATION_ERROR);

      final PrinterStatus status = await printer.getPrinterStatus();

      expect(calls.single.method, 'getPrinterStatus');
      expect(status.errorCode, ErrorCode.ERROR_COMMUNICATION_ERROR);
    });

    test('printFile sends the file path', () async {
      reply = (_) => statusMap(ErrorCode.ERROR_NONE);

      final PrinterStatus status = await printer.printFile('/tmp/label.png');

      expect(calls.single.method, 'printFile');
      expect(calls.single.arguments['filePath'], '/tmp/label.png');
      expect(status.errorCode, ErrorCode.ERROR_NONE);
    });

    test('printPdfFile sends the file path and page', () async {
      reply = (_) => statusMap(ErrorCode.ERROR_NONE);

      await printer.printPdfFile('/tmp/doc.pdf', 2);

      expect(calls.single.method, 'printPdfFile');
      expect(calls.single.arguments['filePath'], '/tmp/doc.pdf');
      expect(calls.single.arguments['pagenum'], 2);
    });

    test('getPdfFilePages returns the page count', () async {
      reply = (_) => 7;

      expect(await printer.getPdfFilePages('/tmp/doc.pdf'), 7);
      expect(calls.single.method, 'getPDFFilePages');
    });

    test('updateFirm sends the firmware file path', () async {
      reply = (_) => statusMap(ErrorCode.ERROR_NONE);

      await printer.updateFirm('/tmp/firmware.bin');

      expect(calls.single.method, 'updateFirm');
      expect(calls.single.arguments['filePath'], '/tmp/firmware.bin');
    });

    test('sendBinary sends the raw bytes', () async {
      reply = (_) => statusMap(ErrorCode.ERROR_NONE);

      await printer.sendBinary(Uint8List.fromList([1, 2, 3]));

      expect(calls.single.method, 'sendBinary');
      expect(calls.single.arguments['data'], [1, 2, 3]);
    });

    test('getFirmVersion returns the version', () async {
      reply = (_) => '1.04';

      expect(await printer.getFirmVersion(), '1.04');
      expect(calls.single.method, 'getFirmVersion');
    });

    test('getBatteryInfo parses the battery info', () async {
      reply = (_) => BatteryInfo(
              chargeLevel: 80, healthLevel: 95, healthStatus: HealthStatus.Good)
          .toMap();

      final BatteryInfo info = await printer.getBatteryInfo();

      expect(info.batteryChargeLevel, 80);
      expect(info.batteryHealthLevel, 95);
      expect(info.batteryHealthStatus, HealthStatus.Good);
    });

    test('getNetPrinters sends the models and parses the printers', () async {
      reply = (_) => [
            NetPrinter(modelName: 'QL-820NWB', ipAddress: '192.168.1.20')
                .toMap()
          ];

      final List<NetPrinter> printers =
          await printer.getNetPrinters(['QL-820NWB']);

      expect(calls.single.method, 'getNetPrinters');
      expect(calls.single.arguments['models'], ['QL-820NWB']);
      expect(printers.single.modelName, 'QL-820NWB');
      expect(printers.single.ipAddress, '192.168.1.20');
    });

    test('getBluetoothPrinters parses the paired printers', () async {
      reply = (_) => [
            {'modelName': 'RJ-4250WB', 'macAddress': '00:11:22:33:44:55'}
          ];

      final List<BluetoothPrinter> printers =
          await printer.getBluetoothPrinters(['RJ-4250WB']);

      expect(calls.single.method, 'getBluetoothPrinters');
      expect(printers.single.macAddress, '00:11:22:33:44:55');
    });

    test('getBLEPrinters asks the native side to scan', () async {
      reply = (_) => [
            {'localName': 'PT-P910BT1234'}
          ];

      final List<BLEPrinter> printers = await printer.getBLEPrinters(3000);

      expect(calls.single.method, 'getBLEPrinters');
      expect(calls.single.arguments['timeout'], 3000);
      expect(printers.single.localName, 'PT-P910BT1234');
    });

    test('startCommunication returns the native result', () async {
      reply = (_) => true;

      expect(await printer.startCommunication(), isTrue);
      expect(calls.single.method, 'startCommunication');
    });

    test('native errors surface as PlatformException', () async {
      reply = (_) => throw PlatformException(
          code: 'NATIVE_ERROR', message: 'Printer not found');

      expect(
          printer.getPrinterStatus(),
          throwsA(isA<PlatformException>()
              .having((e) => e.code, 'code', 'NATIVE_ERROR')
              .having((e) => e.message, 'message', 'Printer not found')));
    });
  });

  group('TbPrinter', () {
    test('uses the id returned by startCommunication for later calls',
        () async {
      reply = (MethodCall call) =>
          call.method == 'typeB-startCommunication' ? 'tb-printer-1' : true;
      final TbPrinter printer = TbPrinter();

      expect(await printer.startCommunication(), isTrue);
      expect(await printer.clearBuffer(), isTrue);

      expect(calls.map((c) => c.method),
          ['typeB-startCommunication', 'typeB-clearBuffer']);
      expect(calls.last.arguments['printerId'], 'tb-printer-1');
    });

    test('startCommunication fails when no printer id is returned', () async {
      reply = (_) => '';

      expect(await TbPrinter().startCommunication(), isFalse);
    });

    test('sendCommand sends the command text', () async {
      reply = (_) => true;

      await TbPrinter().sendCommand('CLS\r\n');

      expect(calls.single.method, 'typeB-sendCommand');
      expect(calls.single.arguments['command'], 'CLS\r\n');
    });
  });

  group('RJ-4235B', () {
    test('uses the Brother SDK model id and the RJ-4230B defaults', () {
      // 139 is PrinterInfo.Model.RJ_4235B's id in Brother Print SDK 4.13.
      expect(Model.RJ_4235B.getId(), 139);
      expect(Model.valueFromID(139), Model.RJ_4235B);
      expect(Model.getValues(), contains(Model.RJ_4235B));
      expect(Model.RJ_4235B.getName(), 'RJ-4235B');
      expect(Model.RJ_4235B.getDefaultPaper(), Model.RJ_4230B.getDefaultPaper());
      expect(Model.RJ_4235B.customPaperPrinter(), Model.RJ_4230B.customPaperPrinter());
    });

    test('is sent to the native side by id and name', () async {
      reply = (_) => PrinterStatus().toMap();
      final Printer printer = Printer();
      await printer.setPrinterInfo(PrinterInfo()..printerModel = Model.RJ_4235B);

      await printer.getPrinterStatus();

      // Android looks the model up by id, iOS by name.
      expect(calls.single.arguments['printInfo']['printerModel'],
          {'id': 139, 'name': 'RJ_4235B'});
    });
  });

  group('serialization', () {
    test('PrinterStatus round-trips through a map', () {
      final PrinterStatus status = PrinterStatus(
          errorCode: ErrorCode.ERROR_BROTHER_PRINTER_NOT_FOUND,
          labelId: 3,
          batteryLevel: 50);

      final PrinterStatus copy = PrinterStatus.fromMap(status.toMap());

      expect(copy.errorCode, ErrorCode.ERROR_BROTHER_PRINTER_NOT_FOUND);
      expect(copy.labelId, 3);
      expect(copy.batteryLevel, 50);
    });

    test('BluetoothPreference round-trips through a map', () {
      final BluetoothPreference preference = BluetoothPreference(
          enableSsp: SSP.ENABLE,
          powerMode: PowerSaveMode.ECO_MODE,
          authMode: AuthMode.AUTH_ON_ENC_ON);

      final BluetoothPreference copy =
          BluetoothPreference.fromMap(preference.toMap());

      expect(copy.enableSsp, SSP.ENABLE);
      expect(copy.powerMode, PowerSaveMode.ECO_MODE);
      expect(copy.authMode, AuthMode.AUTH_ON_ENC_ON);
    });
  });
}
