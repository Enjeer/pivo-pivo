import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pivo_pivo/app.dart';
import 'package:pivo_pivo/domain.dart';
import 'package:pivo_pivo/local_store.dart';

void main() {
  testWidgets('map search filters the labelled demo catalogue', (tester) async {
    final controller = AppController(store: MemoryLocalUserStore());
    await tester.pumpWidget(
      PivoPivoApp(controller: controller, showLiveMap: false),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('ДЕМО-КАТАЛОГ · точки тестовые, не реальные заведения'),
      findsOneWidget,
    );
    expect(find.text('Точка 01'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('place-search')), 'нет');
    await tester.pumpAndSettle();
    expect(
      find.text('В демо-каталоге нет совпадений для «нет»'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const ValueKey('place-search')), '');
    await tester.pumpAndSettle();
    expect(find.text('Точка 01'), findsOneWidget);
  });

  testWidgets('user can add a place to the evening plan', (tester) async {
    final controller = AppController(store: MemoryLocalUserStore());
    await tester.pumpWidget(
      PivoPivoApp(controller: controller, showLiveMap: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Точка 01').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('В план вечера'));
    await tester.pumpAndSettle();

    expect(controller.data.stops, hasLength(1));
    await tester.tap(find.byTooltip('Закрыть карточку'));
    await tester.pumpAndSettle();
    await _openPlanFromMap(tester);
    expect(find.text('План вечера'), findsOneWidget);
    expect(find.text('Точка 01'), findsOneWidget);
    expect(find.text('Добавьте оценки'), findsOneWidget);
  });

  testWidgets('manual stop estimate saves as BYN and survives restoration', (
    tester,
  ) async {
    final store = MemoryLocalUserStore(
      const UserData(stops: [PlanStop(placeId: 'demo-01')]),
    );
    final controller = AppController(store: store);
    await tester.pumpWidget(
      PivoPivoApp(controller: controller, showLiveMap: false),
    );
    await tester.pumpAndSettle();
    await _openPlanFromMap(tester);

    final costField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Ваша оценка посещения, BYN',
    );
    await tester.enterText(costField, '12,50');
    await tester.tap(find.byTooltip('Сохранить оценку'));
    await tester.pumpAndSettle();

    expect(controller.data.stops.single.visitCostMinor, 1250);
    final restored = AppController(store: store);
    await restored.initialize();
    expect(restored.data.stops.single.visitCostMinor, 1250);
  });

  testWidgets('map and list use the same search and category filters', (
    tester,
  ) async {
    final controller = AppController(store: MemoryLocalUserStore());
    await tester.pumpWidget(
      PivoPivoApp(controller: controller, showLiveMap: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Фильтры и режим карты'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Список'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.text('Точка 01'), findsOneWidget);
    expect(find.text('Точка 02'), findsOneWidget);

    await tester.tap(find.byTooltip('Фильтры и режим карты'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Клуб'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.text('Точка 03'), findsOneWidget);
    expect(find.text('Точка 01'), findsNothing);
  });

  testWidgets('map and plan fit a small mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(store: MemoryLocalUserStore());
    await tester.pumpWidget(
      PivoPivoApp(controller: controller, showLiveMap: false),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _openPlanFromMap(tester);

    expect(find.text('План вечера'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map controls remain scrollable on a small viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PivoPivoApp(
        controller: AppController(store: MemoryLocalUserStore()),
        showLiveMap: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Фильтры и режим карты'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Источник данных и ограничения'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Источник данных и ограничения'), findsOneWidget);
  });

  testWidgets('budget suggestions remove only the required known-cost stops', (
    tester,
  ) async {
    final controller = AppController(
      store: MemoryLocalUserStore(
        const UserData(
          stops: [
            PlanStop(placeId: 'demo-01', visitCostMinor: 700),
            PlanStop(placeId: 'demo-02', visitCostMinor: 600),
          ],
          transportCostMinor: 200,
          budgetMinor: 1000,
        ),
      ),
    );
    await tester.pumpWidget(
      PivoPivoApp(controller: controller, showLiveMap: false),
    );
    await tester.pumpAndSettle();

    await _openPlanFromMap(tester);
    expect(find.text('ПРЕВЫШЕНИЕ ЛИМИТА'), findsOneWidget);
    expect(
      find.text('Можно убрать 1 место: известная сумма станет 8,00 BYN.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Применить вариант'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Применить вариант'));
    await tester.pumpAndSettle();

    expect(controller.data.stops, hasLength(1));
    expect(controller.data.stops.single.placeId, 'demo-02');
    expect(find.text('В ПРЕДЕЛАХ БЮДЖЕТА'), findsOneWidget);
  });
}

Future<void> _openPlanFromMap(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Фильтры и режим карты'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('План вечера ·'));
  await tester.pumpAndSettle();
}
