import 'xmtp_plugin_platform_interface.dart';

/// Stub for XmtpPluginWindows on platforms where dart:ffi / Rust bindings
/// are not available (e.g., web). The real implementation lives in
/// xmtp_plugin_windows.dart and is only compiled on native platforms.
class XmtpPluginWindows extends XmtpPluginPlatform {
  static void registerWith() {
    // No-op on non-Windows platforms.
  }
}
