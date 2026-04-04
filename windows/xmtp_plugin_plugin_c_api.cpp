#include "include/xmtp_plugin/xmtp_plugin_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "xmtp_plugin_plugin.h"

void XmtpPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  xmtp_plugin::XmtpPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
