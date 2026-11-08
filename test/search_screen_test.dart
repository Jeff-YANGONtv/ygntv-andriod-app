import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/screens/catalog_browser_screen.dart';

class _CatalogTestService extends AuthService {
  _CatalogTestService()
    : super(client: MockClient((_) async => http.Response('{}', 200)));

  final queries = <String>[];
  final catalogKinds = <String>[];

  static const catalogItems = [
    CatalogItem(
      id: 1,
      title: 'Alpha Action',
      posterUrl: '',
      kind: 'movie',
      genres: ['Action'],
    ),
    CatalogItem(
      id: 2,
      title: 'Alpha Comedy',
      posterUrl: '',
      kind: 'series',
      genres: ['Comedy'],
    ),
  ];

  @override
  Future<List<CatalogItem>> searchCatalog(String query) async {
    queries.add(query);
    return catalogItems;
  }

  @override
  Future<List<CatalogItem>> loadCatalog(
    String kind, {
    int page = 1,
    int perPage = 48,
  }) async {
    catalogKinds.add('$kind:$page');
    if (page > 1) return const [];
    // Deliberately return mixed kinds to verify the tab itself scopes results.
    return catalogItems;
  }
}

Widget _testApp(_CatalogTestService service, {required String kind}) =>
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: CatalogBrowserScreen(
          service: service,
          kind: kind,
          title: kind == 'movie' ? 'Movies to discover' : 'Series to binge',
          catalogFuture: service.loadCatalog(kind),
          onOpenItem: (_) {},
          onRefresh: () async {},
        ),
      ),
    );

void main() {
  testWidgets('Movie tab shows only movies and searches only movie results', (
    tester,
  ) async {
    final service = _CatalogTestService();
    await tester.pumpWidget(_testApp(service, kind: 'movie'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha Action'), findsOneWidget);
    expect(find.text('Alpha Comedy'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Action'), findsOneWidget);

    final input = find.byType(TextField);
    await tester.enterText(input, 'al');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(service.queries, ['al']);
    expect(find.text('Alpha Action'), findsOneWidget);
    expect(find.text('Alpha Comedy'), findsNothing);
  });

  testWidgets('genre chips filter the current catalog without a search', (
    tester,
  ) async {
    final service = _CatalogTestService();
    await tester.pumpWidget(_testApp(service, kind: 'series'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha Comedy'), findsOneWidget);
    expect(find.text('Alpha Action'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Comedy'));
    await tester.pumpAndSettle();

    expect(find.text('1 titles in “Comedy”'), findsOneWidget);
    expect(find.text('Alpha Comedy'), findsOneWidget);
    expect(service.queries, isEmpty);
  });
}
