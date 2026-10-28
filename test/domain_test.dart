import 'package:flutter_test/flutter_test.dart';
import 'package:pivo_pivo/domain.dart';

void main() {
  group('parseMoneyMinor', () {
    test('parses whole and fractional BYN without floating point', () {
      expect(parseMoneyMinor('25'), 2500);
      expect(parseMoneyMinor('25,5'), 2550);
      expect(parseMoneyMinor('25.05'), 2505);
      expect(parseMoneyMinor(''), isNull);
    });

    test('rejects invalid and over-precision values', () {
      expect(() => parseMoneyMinor('-1'), throwsFormatException);
      expect(() => parseMoneyMinor('1.234'), throwsFormatException);
      expect(() => parseMoneyMinor('abc'), throwsFormatException);
    });
  });

  test('budget sums only entered prices and shows missing values', () {
    const data = UserData(
      stops: [
        PlanStop(placeId: 'demo-01', visitCostMinor: 1250),
        PlanStop(placeId: 'demo-02'),
      ],
      participants: 2,
      transportCostMinor: 500,
    );

    final summary = calculateBudget(data);

    expect(summary.knownSubtotalMinor, 1750);
    expect(summary.perPersonMinor, 875);
    expect(summary.missingVisitCosts, 1);
    expect(summary.transportCostKnown, isTrue);
    expect(formatMoneyMinor(summary.knownSubtotalMinor), '17,50 BYN');
  });

  test('filters the demo catalogue by name and category', () {
    expect(
      filterPlaces(demoPlaces, query: 'точка 01').map((place) => place.id),
      ['demo-01'],
    );
    expect(filterPlaces(demoPlaces, category: 'Бар').map((place) => place.id), [
      'demo-01',
      'demo-05',
    ]);
  });

  test('reorders stops while retaining each stop cost', () {
    const stops = [
      PlanStop(placeId: 'first', visitCostMinor: 100),
      PlanStop(placeId: 'second', visitCostMinor: 200),
      PlanStop(placeId: 'third'),
    ];

    final result = reorderStops(stops, 0, 2);

    expect(result.map((stop) => stop.placeId), ['second', 'third', 'first']);
    expect(result.last.visitCostMinor, 100);
  });

  test('local data JSON round-trips favorites, notes and plan', () {
    final data = UserData(
      favorites: {'demo-01'},
      stops: [PlanStop(placeId: 'demo-01', visitCostMinor: 1234)],
      savedPlaces: {'demo-01': demoPlaces.first},
      noteByPlace: {'demo-01': 'Позвонить перед выходом'},
      participants: 3,
      transportCostMinor: 450,
      budgetMinor: 5000,
    );

    final restored = UserData.fromJson(data.toJson());

    expect(restored.favorites, data.favorites);
    expect(restored.stops.single.visitCostMinor, 1234);
    expect(restored.savedPlaces['demo-01']?.name, demoPlaces.first.name);
    expect(restored.noteByPlace, data.noteByPlace);
    expect(restored.participants, 3);
    expect(restored.transportCostMinor, 450);
    expect(restored.budgetMinor, 5000);
  });

  test('version 1 local data migrates without losing personal data', () {
    final restored = UserData.fromJson({
      'version': 1,
      'favorites': ['demo-01'],
      'stops': [
        {'placeId': 'demo-01', 'visitCostMinor': 1500},
      ],
      'notes': {'demo-01': 'Позвонить'},
      'participants': 2,
      'transportCostMinor': 300,
    });

    expect(restored.favorites, {'demo-01'});
    expect(restored.stops.single.visitCostMinor, 1500);
    expect(restored.noteByPlace, {'demo-01': 'Позвонить'});
    expect(restored.transportCostMinor, 300);
    expect(restored.budgetMinor, isNull);
    expect(restored.toJson()['version'], 4);
  });

  test(
    'version 2 data migrates while leaving unknown estimate dates unknown',
    () {
      final restored = UserData.fromJson({
        'version': 2,
        'favorites': ['demo-02'],
        'stops': [
          {'placeId': 'demo-02', 'visitCostMinor': 2200},
        ],
        'notes': {'demo-02': 'Личная заметка'},
        'participants': 4,
        'transportCostMinor': 700,
        'budgetMinor': 8000,
      });

      expect(restored.stops.single.visitCostMinor, 2200);
      expect(restored.stops.single.visitCostObservedAt, isNull);
      expect(
        restored.stops.single.visitCostStatus,
        PriceVerification.estimated,
      );
      expect(restored.budgetMinor, 8000);
      expect(restored.toJson()['version'], 4);
    },
  );

  test('version 3 data migrates without losing saved plan values', () {
    final restored = UserData.fromJson({
      'version': 3,
      'favorites': ['demo-03'],
      'stops': [
        {
          'placeId': 'demo-03',
          'visitCostMinor': 1800,
          'visitCostSource': 'user_estimate',
          'visitCostStatus': 'estimated',
        },
      ],
      'notes': {'demo-03': 'Позвонить'},
      'participants': 2,
      'transportCostMinor': null,
      'budgetMinor': 5000,
    });

    expect(restored.favorites, {'demo-03'});
    expect(restored.stops.single.visitCostMinor, 1800);
    expect(restored.savedPlaces, isEmpty);
    expect(restored.budgetMinor, 5000);
    expect(restored.toJson()['version'], 4);
  });

  group('budget assessment', () {
    test('an empty plan has no visit spend and never invents transit cost', () {
      const emptyPlan = UserData(budgetMinor: 1000);

      final summary = calculateBudget(emptyPlan);
      final assessment = assessBudget(emptyPlan);

      expect(summary.knownSubtotalMinor, 0);
      expect(summary.missingVisitCosts, 0);
      expect(summary.transportCostKnown, isFalse);
      expect(assessment.status, BudgetStatus.incomplete);
      expect(assessment.missingCosts, 1);
    });

    test(
      'rejects zero participants before calculating a per-person amount',
      () {
        expect(
          () => calculateBudget(const UserData(participants: 0)),
          throwsRangeError,
        );
      },
    );

    test('does not claim a plan is affordable while prices are unknown', () {
      const data = UserData(
        stops: [
          PlanStop(placeId: 'known', visitCostMinor: 700),
          PlanStop(placeId: 'unknown'),
        ],
        transportCostMinor: 0,
        budgetMinor: 1000,
      );

      final assessment = assessBudget(data);

      expect(assessment.status, BudgetStatus.incomplete);
      expect(assessment.missingCosts, 1);
      expect(suggestBudgetAdjustment(data), isNull);
    });

    test('marks known overspend and suggests removals only when complete', () {
      const data = UserData(
        stops: [
          PlanStop(placeId: 'first', visitCostMinor: 700),
          PlanStop(placeId: 'second', visitCostMinor: 600),
        ],
        transportCostMinor: 200,
        budgetMinor: 1000,
      );

      final assessment = assessBudget(data);
      final suggestion = suggestBudgetAdjustment(data);

      expect(assessment.status, BudgetStatus.overBudget);
      expect(assessment.remainingMinor, -500);
      expect(suggestion?.placeIdsToRemove, ['first']);
      expect(suggestion?.savedMinor, 700);
      expect(suggestion?.remainingMinor, 800);
    });

    test('suggests multiple removals when one stop is not enough', () {
      const data = UserData(
        stops: [
          PlanStop(placeId: 'one', visitCostMinor: 600),
          PlanStop(placeId: 'two', visitCostMinor: 500),
          PlanStop(placeId: 'three', visitCostMinor: 400),
        ],
        transportCostMinor: 100,
        budgetMinor: 700,
      );

      final suggestion = suggestBudgetAdjustment(data);

      expect(suggestion?.placeIdsToRemove, ['one', 'two']);
      expect(suggestion?.remainingMinor, 500);
    });
  });
}
