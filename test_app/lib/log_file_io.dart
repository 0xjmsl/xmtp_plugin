import 'dart:io';

final _logFile = File('${Directory.systemTemp.path}/xmtp_test_results.log');

void writeLog(String content) {
  _logFile.writeAsStringSync(content);
}

String? getLogPath() => _logFile.path;
