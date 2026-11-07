import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ygntv_customer/auth/auth_service.dart';

class _QueuedResponse {
  const _QueuedResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

class _CaptureClient extends http.BaseClient {
  _CaptureClient(this.responses);

  final List<_QueuedResponse> responses;
  final List<String> methods = [];
  final List<Uri> urls = [];
  final List<Map<String, String>> requestHeaders = [];
  final List<Map<String, Object?>> jsonBodies = [];
  final List<Map<String, Object?>> multipartBodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    methods.add(request.method);
    urls.add(request.url);
    final stream = request.finalize();
    requestHeaders.add({
      for (final entry in request.headers.entries)
        entry.key.toLowerCase(): entry.value,
    });
    if (request is http.Request) {
      jsonBodies.add(
        jsonDecode(utf8.decode(await stream.toBytes())) as Map<String, Object?>,
      );
    } else if (request is http.MultipartRequest) {
      final files = request.files
          .map(
            (file) => {
              'field': file.field,
              'filename': file.filename,
              'contentType': file.contentType.toString(),
            },
          )
          .toList(growable: false);
      multipartBodies.add({
        'fields': Map<String, String>.from(request.fields),
        'files': files,
        'bodyBytes': await stream.toBytes(),
        'contentType': request.headers['content-type'],
      });
    } else {
      await stream.drain<void>();
    }

    final response = responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response.body)),
      response.statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

void main() {
  test(
    'creates an authenticated order using the YGNTV TV payment API',
    () async {
      final client = _CaptureClient([
        const _QueuedResponse(
          201,
          '{"data":{"order":{"id":501,"reference":"YTV-TEST-123456","plan_key":"1_month","amount_ks":2500,"status":"awaiting_receipt"}}}',
        ),
      ]);
      final service = AuthService(
        client: client,
        tokenReader: () async => 'unit-test-token',
      );
      addTearDown(service.dispose);

      final order = await service.createPaymentOrder(
        paymentAccountId: 8,
        planKey: '1_month',
      );

      expect(order.id, '501');
      expect(order.status, 'awaiting_receipt');
      expect(client.methods.single, 'POST');
      expect(client.urls.single.path, '/api/tv/payment-orders');
      expect(
        client.requestHeaders.single['authorization'],
        'Bearer unit-test-token',
      );
      expect(client.jsonBodies.single, {
        'payment_account_id': 8,
        'plan_key': '1_month',
      });
    },
  );

  test(
    'submits the receipt as multipart for authenticated admin review',
    () async {
      final client = _CaptureClient([
        const _QueuedResponse(
          200,
          '{"data":{"id":501,"reference":"YTV-TEST-123456","amount_ks":2500,"status":"submitted"}}',
        ),
      ]);
      final service = AuthService(
        client: client,
        tokenReader: () async => 'unit-test-token',
      );
      addTearDown(service.dispose);

      final order = await service.submitOrderReceipt(
        orderId: '501',
        receiptBytes: [1, 2, 3, 4],
        fileName: 'transfer.jpg',
        mimeType: 'image/jpeg',
        receiptReference: 'TX-ABC123456',
      );

      expect(order.status, 'submitted');
      expect(client.methods.single, 'POST');
      expect(
        client.urls.single.path,
        '/api/tv/payment-orders/501/submit-receipt',
      );
      expect(
        client.requestHeaders.single['authorization'],
        'Bearer unit-test-token',
      );
      expect(
        client.requestHeaders.single['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final multipart = client.multipartBodies.single;
      expect(multipart['fields'], {'receipt_reference': 'TX-ABC123456'});
      expect(multipart['files'], [
        {
          'field': 'receipt',
          'filename': 'transfer.jpg',
          'contentType': 'image/jpeg',
        },
      ]);
      expect((multipart['bodyBytes'] as List<int>).isNotEmpty, isTrue);
    },
  );
}
