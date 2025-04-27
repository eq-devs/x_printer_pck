import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_printer_pck/x_printer_pck_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelXPrinterPck platform = MethodChannelXPrinterPck();
  const MethodChannel channel = MethodChannel('x_printer_pck');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

 
}
