import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmtp_plugin/codecs.dart';

/// Builds an EncodedContent whose body is the given JSON string.
EncodedContent _encoded(String typeId, String json) {
  return EncodedContent()
    ..type = (ContentTypeId()
      ..authorityId = 'xmtp.org'
      ..typeId = typeId
      ..versionMajor = 1
      ..versionMinor = 0)
    ..content = utf8.encode(json);
}

void main() {
  group('TransactionReferenceCodec', () {
    test('decodes the real wrapped + partial-metadata wire sample', () async {
      // Verbatim from a Base USDC payment receipt observed in the wild.
      const wire =
          '{"transactionReference":{"networkId":"0x2105","reference":"0xb9e384d7d8fb516ebc50de70a2ec5c1a0f5471edcaa38a3a71babc6de0161dee","metadata":{"transactionType":"send","fromAddress":"0x22209cfc1397832f32160239c902b10a624cab1a"}}}';

      final ref = await TransactionReferenceCodec()
          .decode(_encoded('transactionReference', wire)) as TransactionReference;

      expect(ref.networkId, '0x2105');
      expect(ref.reference,
          '0xb9e384d7d8fb516ebc50de70a2ec5c1a0f5471edcaa38a3a71babc6de0161dee');
      expect(ref.metadata, isNotNull);
      expect(ref.metadata!.transactionType, 'send');
      expect(ref.metadata!.fromAddress,
          '0x22209cfc1397832f32160239c902b10a624cab1a');
      // Fields the sender omitted must be null, not a crash.
      expect(ref.metadata!.currency, isNull);
      expect(ref.metadata!.amount, isNull);
    });

    test('decodes the canonical flat shape with full metadata', () async {
      const wire =
          '{"namespace":"eip155","networkId":1,"reference":"0xabc","metadata":{"transactionType":"payment","currency":"ETH","amount":1.2345,"decimals":18,"fromAddress":"0xfrom","toAddress":"0xto"}}';

      final ref = await TransactionReferenceCodec()
          .decode(_encoded('transactionReference', wire)) as TransactionReference;

      expect(ref.namespace, 'eip155');
      expect(ref.networkId, '1'); // number normalized to string
      expect(ref.metadata!.currency, 'ETH');
      expect(ref.metadata!.amount, 1.2345);
      expect(ref.metadata!.decimals, 18);
      expect(ref.metadata!.toAddress, '0xto');
    });

    test('encodes canonical flat (no wrapper, omits null fields)', () async {
      final ref = TransactionReference(networkId: '0x2105', reference: '0xdead');
      final encoded = await TransactionReferenceCodec().encode(ref);
      final json = jsonDecode(utf8.decode(encoded['content'] as List<int>));

      expect(json.containsKey('transactionReference'), isFalse); // flat
      expect(json['networkId'], '0x2105');
      expect(json['reference'], '0xdead');
      expect(json.containsKey('namespace'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('round-trips a fully-populated reference', () async {
      final original = TransactionReference(
        namespace: 'eip155',
        networkId: '8453',
        reference: '0xfeed',
        metadata: TransactionMetadata(
          transactionType: 'send',
          currency: 'USDC',
          amount: 1.0,
          decimals: 6,
          fromAddress: '0xa',
          toAddress: '0xb',
        ),
      );
      final encoded = await TransactionReferenceCodec().encode(original);
      final back = await TransactionReferenceCodec()
          .decode(EncodedContent()..content = encoded['content'] as List<int>)
          as TransactionReference;

      expect(back.networkId, '8453');
      expect(back.metadata!.currency, 'USDC');
      expect(back.metadata!.decimals, 6);
    });
  });

  group('WalletSendCallsCodec', () {
    test('decodes the real flat wire sample (USDC transfer on Base)', () async {
      const wire =
          '{"version":"1.0","chainId":"0x2105","from":"0x22209cfc1397832f32160239c902b10a624cab1a","calls":[{"to":"0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913","data":"0xa9059cbb00000000000000000000000083546713bd755e46757109353564a7419d23c3fe00000000000000000000000000000000000000000000000000000000000f4240","value":"0x0"}]}';

      final wsc = await WalletSendCallsCodec()
          .decode(_encoded('walletSendCalls', wire)) as WalletSendCalls;

      expect(wsc.version, '1.0');
      expect(wsc.chainId, '0x2105');
      expect(wsc.from, '0x22209cfc1397832f32160239c902b10a624cab1a');
      expect(wsc.calls.length, 1);
      expect(wsc.calls.first.to, '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913');
      expect(wsc.calls.first.value, '0x0');
      expect(wsc.calls.first.metadata, isNull); // none on this call
    });

    test('decodes call metadata with flattened extras', () async {
      const wire =
          '{"version":"1","chainId":"0x1","from":"0xf","calls":[{"to":"0xt","metadata":{"description":"Send funds","transactionType":"transfer","note":"hi"}}]}';

      final wsc = await WalletSendCallsCodec()
          .decode(_encoded('walletSendCalls', wire)) as WalletSendCalls;
      final meta = wsc.calls.first.metadata!;

      expect(meta.description, 'Send funds');
      expect(meta.transactionType, 'transfer');
      expect(meta.extra['note'], 'hi'); // flattened sibling preserved
    });

    test('round-trips and re-flattens extras on encode', () async {
      final original = WalletSendCalls(
        version: '1',
        chainId: '0x1',
        from: '0xf',
        calls: [
          WalletCall(
            to: '0xt',
            value: '0x0',
            metadata: WalletCallMetadata(
              description: 'd',
              transactionType: 'transfer',
              extra: {'note': 'hi'},
            ),
          ),
        ],
      );
      final encoded = await WalletSendCallsCodec().encode(original);
      final json = jsonDecode(utf8.decode(encoded['content'] as List<int>));

      expect(json['version'], '1');
      final meta = json['calls'][0]['metadata'];
      expect(meta['description'], 'd');
      expect(meta['note'], 'hi'); // extra flattened back to a sibling key
    });
  });
}
