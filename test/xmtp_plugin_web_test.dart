import 'package:flutter_test/flutter_test.dart';
import 'package:xmtp_plugin/xmtp_plugin_platform_interface.dart';
import 'package:xmtp_plugin/xmtp_plugin_web.dart';
import 'package:xmtp_plugin/xmtp_plugin.dart';

void main() {
  group('XmtpPluginWeb', () {
    late XmtpPluginWeb plugin;

    setUp(() {
      plugin = XmtpPluginWeb();
      XmtpPluginPlatform.instance = plugin;
    });

    test('getPlatformVersion returns Web', () async {
      expect(await plugin.getPlatformVersion(), 'Web');
    });

    test('can create instance', () {
      expect(plugin, isA<XmtpPluginPlatform>());
    });

    test('registers correctly', () {
      XmtpPluginWeb.registerWith(MockRegistrar());
      expect(XmtpPluginPlatform.instance, isA<XmtpPluginWeb>());
    });
  });
}

class MockRegistrar {
  // Mock registrar for testing
}