import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmtp_plugin/codecs.dart';

/// A codec whose typeId differs from libxmtp's canonical id silently misses the
/// registry: the message decodes to a blank bubble, or never decodes. This
/// happened to LeaveRequestCodec ('leaveRequest') and MultiRemoteAttachmentCodec
/// ('multiRemoteStaticContent') from the 2026-04-03 release until 2026-10-02.
/// A "fix" was recorded on 2026-06-07 but never reached the code, so these
/// assertions keep it fixed.
///
/// Canonical ids come from the upstream SDKs (xmtp-ios Codecs/*.swift,
/// xmtp-android codecs/*.kt). Mixed casing is real: see wiki xmtp_plugin/codecs.
void main() {
  test('leave_request typeId is the canonical snake_case id', () {
    final c = LeaveRequestCodec();
    expect(c.authorityId, 'xmtp.org');
    expect(c.typeId, 'leave_request');
  });

  test('multi remote attachment typeId is the canonical id', () {
    final c = MultiRemoteAttachmentCodec();
    expect(c.authorityId, 'xmtp.org');
    expect(c.typeId, 'multiRemoteStaticAttachment');
  });

  // The caption rides in our non-standard `description` parameter, the same
  // way single attachments carry it (threads/multi_attachments).
  test('multi remote attachment round-trips files + caption', () async {
    RemoteAttachmentContent item(int i) => RemoteAttachmentContent(
          url: 'https://example.com/$i.bin',
          contentDigest: 'digest$i',
          secret: Uint8List.fromList(List.filled(32, i)),
          salt: Uint8List.fromList(List.filled(32, i + 1)),
          nonce: Uint8List.fromList(List.filled(12, i + 2)),
          scheme: 'https://',
          contentLength: 1000 + i,
          filename: 'photo$i.jpg',
        );
    final c = MultiRemoteAttachmentCodec();
    final encoded = await c.encode(MultiRemoteAttachmentContent(
      attachments: [item(1), item(2), item(3)],
      description: 'beach day',
    ));
    final params = Map<String, String>.from(encoded['parameters'] as Map);
    expect(params['description'], 'beach day');

    final decoded = await c.decode(EncodedContent(
      content: encoded['content'] as Uint8List,
      parameters: params.entries,
    ));
    expect(decoded.description, 'beach day');
    expect(decoded.attachments.length, 3);
    expect(decoded.attachments[1].url, 'https://example.com/2.bin');
    expect(decoded.attachments[1].filename, 'photo2.jpg');
    expect(decoded.attachments[1].contentLength, 1002);
    expect(decoded.attachments[1].secret, List.filled(32, 2));
    expect(decoded.attachments[1].nonce, List.filled(12, 4));
    expect(c.getFallback(decoded), '[3 attachments]');

    // No caption → no parameter, and decode gives null (not '').
    final bare = await c.encode(MultiRemoteAttachmentContent(attachments: [item(1)]));
    expect((bare['parameters'] as Map).containsKey('description'), isFalse);
    final bareDecoded = await c.decode(EncodedContent(content: bare['content'] as Uint8List));
    expect(bareDecoded.description, isNull);
  });
}
