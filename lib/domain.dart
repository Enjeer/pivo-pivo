import 'dart:math' as math;

enum PlaceSource { demo, openStreetMap }

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.description,
    this.source = PlaceSource.demo,
    this.sourceReference,
    this.address,
    this.website,
    this.openingHours,
    this.phone,
    this.cuisine,
    this.priceObservations = const [],
  });

  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final String description;
  final PlaceSource source;
  final String? sourceReference;
  final String? address;
  final String? website;
  final String? openingHours;
  final String? phone;
  final String? cuisine;
  final List<PriceObservation> priceObservations;

  bool get isDemo => source == PlaceSource.demo;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'source': source.name,
    'sourceReference': sourceReference,
    'address': address,
    'website': website,
    'openingHours': openingHours,
    'phone': phone,
    'cuisine': cuisine,
    'priceObservations': priceObservations
        .map((observation) => observation.toJson())
        .toList(),
  };

  factory Place.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final category = json['category'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final description = json['description'];
    final source = json['source'];
    final rawObservations = json['priceObservations'] ?? const [];
    final optionalStrings = [
      json['sourceReference'],
      json['address'],
      json['website'],
      json['openingHours'],
      json['phone'],
      json['cuisine'],
    ];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        category is! String ||
        category.isEmpty ||
        latitude is! num ||
        longitude is! num ||
        !latitude.toDouble().isFinite ||
        !longitude.toDouble().isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        description is! String ||
        !PlaceSource.values.any((value) => value.name == source) ||
        optionalStrings.any((value) => value != null && value is! String) ||
        rawObservations is! List) {
      throw const FormatException('Некорректный снимок места');
    }

    final observations = <PriceObservation>[];
    for (final item in rawObservations) {
      if (item is! Map) {
        throw const FormatException('Некорректное наблюдение цены в месте');
      }
      observations.add(
        PriceObservation.fromJson(Map<String, Object?>.from(item)),
      );
    }

    return Place(
      id: id,
      name: name,
      category: category,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      description: description,
      source: PlaceSource.values.firstWhere((value) => value.name == source),
      sourceReference: json['sourceReference'] as String?,
      address: json['address'] as String?,
      website: json['website'] as String?,
      openingHours: json['openingHours'] as String?,
      phone: json['phone'] as String?,
      cuisine: json['cuisine'] as String?,
      priceObservations: observations,
    );
  }
}

const demoPlaces = <Place>[
  Place(
    id: 'demo-01',
    name: 'Точка 01',
    category: 'Бар',
    latitude: 53.9012,
    longitude: 27.5618,
    description: 'Пример карточки для проверки поиска и плана.',
  ),
  Place(
    id: 'demo-02',
    name: 'Точка 02',
    category: 'Кафе',
    latitude: 53.9081,
    longitude: 27.5537,
    description: 'Демонстрационная запись. Это не реальное заведение.',
  ),
  Place(
    id: 'demo-03',
    name: 'Точка 03',
    category: 'Клуб',
    latitude: 53.8947,
    longitude: 27.5743,
    description: 'Демонстрационная запись. Это не реальное заведение.',
  ),
  Place(
    id: 'demo-04',
    name: 'Точка 04',
    category: 'Кальянная',
    latitude: 53.913,
    longitude: 27.579,
    description: 'Демонстрационная запись. Это не реальное заведение.',
  ),
  Place(
    id: 'demo-05',
    name: 'Точка 05',
    category: 'Бар',
    latitude: 53.8872,
    longitude: 27.5486,
    description: 'Демонстрационная запись. Это не реальное заведение.',
  ),
];

List<Place> filterPlaces(
  Iterable<Place> places, {
  String query = '',
  String? category,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return places
      .where((place) {
        final matchesQuery =
            normalizedQuery.isEmpty ||
            place.name.toLowerCase().contains(normalizedQuery) ||
            place.category.toLowerCase().contains(normalizedQuery);
        final matchesCategory = category == null || place.category == category;
        return matchesQuery && matchesCategory;
      })
      .toList(growable: false);
}

class PlanStop {
  const PlanStop({
    required this.placeId,
    this.visitCostMinor,
    this.visitCostObservedAt,
    this.visitCostSource = 'user_estimate',
    this.visitCostStatus = PriceVerification.estimated,
  });

  final String placeId;
  final int? visitCostMinor;
  final DateTime? visitCostObservedAt;
  final String visitCostSource;
  final PriceVerification visitCostStatus;

  PlanStop copyWith({
    int? visitCostMinor,
    DateTime? visitCostObservedAt,
    String? visitCostSource,
    PriceVerification? visitCostStatus,
    bool clearVisitCost = false,
  }) {
    return PlanStop(
      placeId: placeId,
      visitCostMinor: clearVisitCost
          ? null
          : visitCostMinor ?? this.visitCostMinor,
      visitCostObservedAt: clearVisitCost
          ? null
          : visitCostObservedAt ?? this.visitCostObservedAt,
      visitCostSource: clearVisitCost
          ? 'user_estimate'
          : visitCostSource ?? this.visitCostSource,
      visitCostStatus: clearVisitCost
          ? PriceVerification.estimated
          : visitCostStatus ?? this.visitCostStatus,
    );
  }

  Map<String, Object?> toJson() => {
    'placeId': placeId,
    'visitCostMinor': visitCostMinor,
    'visitCostObservedAt': visitCostObservedAt?.toIso8601String(),
    'visitCostSource': visitCostSource,
    'visitCostStatus': visitCostStatus.name,
  };

  factory PlanStop.fromJson(Map<String, Object?> json) {
    final placeId = json['placeId'];
    final cost = json['visitCostMinor'];
    final observedAt = json['visitCostObservedAt'];
    final source = json['visitCostSource'] ?? 'user_estimate';
    final status = json['visitCostStatus'] ?? 'estimated';
    if (placeId is! String ||
        (cost != null && (cost is! int || cost < 0)) ||
        (observedAt != null && observedAt is! String) ||
        source is! String ||
        !PriceVerification.values.any((value) => value.name == status)) {
      throw const FormatException('Некорректная остановка в сохранённом плане');
    }
    final parsedAt = observedAt == null
        ? null
        : DateTime.tryParse(observedAt as String);
    if (observedAt != null && parsedAt == null) {
      throw const FormatException('Некорректная дата оценки стоимости');
    }
    return PlanStop(
      placeId: placeId,
      visitCostMinor: cost as int?,
      visitCostObservedAt: parsedAt,
      visitCostSource: source,
      visitCostStatus: PriceVerification.values.firstWhere(
        (value) => value.name == status,
      ),
    );
  }
}

enum PriceVerification { verified, estimated, stale, unknown }

enum PriceSourceType { officialMenu, partnerFeed, openData, userEstimate }

class PriceObservation {
  const PriceObservation({
    required this.amountMinor,
    required this.currency,
    required this.sourceType,
    required this.sourceLabel,
    required this.status,
    this.sourceReference,
    this.observedAt,
    this.validUntil,
  });

  final int? amountMinor;
  final String currency;
  final PriceSourceType sourceType;
  final String sourceLabel;
  final PriceVerification status;
  final String? sourceReference;
  final DateTime? observedAt;
  final DateTime? validUntil;

  bool isStaleAt(DateTime now) =>
      status == PriceVerification.stale ||
      (validUntil != null && now.isAfter(validUntil!));

  Map<String, Object?> toJson() => {
    'amountMinor': amountMinor,
    'currency': currency,
    'sourceType': sourceType.name,
    'sourceLabel': sourceLabel,
    'status': status.name,
    'sourceReference': sourceReference,
    'observedAt': observedAt?.toIso8601String(),
    'validUntil': validUntil?.toIso8601String(),
  };

  factory PriceObservation.fromJson(Map<String, Object?> json) {
    final amount = json['amountMinor'];
    final currency = json['currency'];
    final sourceType = json['sourceType'];
    final sourceLabel = json['sourceLabel'];
    final status = json['status'];
    final sourceReference = json['sourceReference'];
    final observedAt = json['observedAt'];
    final validUntil = json['validUntil'];
    if ((amount != null && (amount is! int || amount < 0)) ||
        currency is! String ||
        currency.isEmpty ||
        sourceLabel is! String ||
        sourceLabel.isEmpty ||
        (sourceReference != null && sourceReference is! String) ||
        (observedAt != null && observedAt is! String) ||
        (validUntil != null && validUntil is! String) ||
        !PriceSourceType.values.any((value) => value.name == sourceType) ||
        !PriceVerification.values.any((value) => value.name == status)) {
      throw const FormatException('Некорректное происхождение цены');
    }
    final parsedObservedAt = observedAt == null
        ? null
        : DateTime.tryParse(observedAt as String);
    final parsedValidUntil = validUntil == null
        ? null
        : DateTime.tryParse(validUntil as String);
    if ((observedAt != null && parsedObservedAt == null) ||
        (validUntil != null && parsedValidUntil == null)) {
      throw const FormatException('Некорректная дата происхождения цены');
    }
    return PriceObservation(
      amountMinor: amount as int?,
      currency: currency,
      sourceType: PriceSourceType.values.firstWhere(
        (value) => value.name == sourceType,
      ),
      sourceLabel: sourceLabel,
      status: PriceVerification.values.firstWhere(
        (value) => value.name == status,
      ),
      sourceReference: sourceReference as String?,
      observedAt: parsedObservedAt,
      validUntil: parsedValidUntil,
    );
  }
}

class UserData {
  const UserData({
    this.favorites = const {},
    this.stops = const [],
    this.savedPlaces = const {},
    this.noteByPlace = const {},
    this.participants = 1,
    this.transportCostMinor,
    this.budgetMinor,
  });

  final Set<String> favorites;
  final List<PlanStop> stops;
  final Map<String, Place> savedPlaces;
  final Map<String, String> noteByPlace;
  final int participants;
  final int? transportCostMinor;
  final int? budgetMinor;

  UserData copyWith({
    Set<String>? favorites,
    List<PlanStop>? stops,
    Map<String, Place>? savedPlaces,
    Map<String, String>? noteByPlace,
    int? participants,
    int? transportCostMinor,
    int? budgetMinor,
    bool clearTransportCost = false,
    bool clearBudget = false,
  }) {
    return UserData(
      favorites: favorites ?? this.favorites,
      stops: stops ?? this.stops,
      savedPlaces: savedPlaces ?? this.savedPlaces,
      noteByPlace: noteByPlace ?? this.noteByPlace,
      participants: participants ?? this.participants,
      transportCostMinor: clearTransportCost
          ? null
          : transportCostMinor ?? this.transportCostMinor,
      budgetMinor: clearBudget ? null : budgetMinor ?? this.budgetMinor,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 4,
    'favorites': favorites.toList(),
    'stops': stops.map((stop) => stop.toJson()).toList(),
    'savedPlaces': savedPlaces.values.map((place) => place.toJson()).toList(),
    'notes': noteByPlace,
    'participants': participants,
    'transportCostMinor': transportCostMinor,
    'budgetMinor': budgetMinor,
  };

  factory UserData.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version != 1 && version != 2 && version != 3 && version != 4) {
      throw const FormatException('Неизвестная версия локальных данных');
    }
    final rawFavorites = json['favorites'];
    final rawStops = json['stops'];
    final rawNotes = json['notes'];
    final rawSavedPlaces = version == 4 ? json['savedPlaces'] : const [];
    final participants = json['participants'];
    final transport = json['transportCostMinor'];
    final budget = version == 1 ? null : json['budgetMinor'];
    if (rawFavorites is! List ||
        rawStops is! List ||
        rawNotes is! Map ||
        rawSavedPlaces is! List ||
        participants is! int ||
        participants < 1 ||
        participants > 99 ||
        (transport != null && transport is! int) ||
        (budget != null && (budget is! int || budget < 0))) {
      throw const FormatException('Некорректные локальные данные');
    }

    final favorites = <String>{};
    for (final item in rawFavorites) {
      if (item is! String) {
        throw const FormatException('Некорректный список избранного');
      }
      favorites.add(item);
    }

    final stops = <PlanStop>[];
    for (final item in rawStops) {
      if (item is! Map) {
        throw const FormatException('Некорректный список остановок');
      }
      stops.add(PlanStop.fromJson(Map<String, Object?>.from(item)));
    }

    final notes = <String, String>{};
    for (final entry in rawNotes.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Некорректные личные заметки');
      }
      notes[entry.key as String] = entry.value as String;
    }

    final savedPlaces = <String, Place>{};
    for (final item in rawSavedPlaces) {
      if (item is! Map) {
        throw const FormatException('Некорректные сохранённые места');
      }
      final place = Place.fromJson(Map<String, Object?>.from(item));
      if (savedPlaces.containsKey(place.id)) {
        throw const FormatException('Повторяющийся снимок места');
      }
      savedPlaces[place.id] = place;
    }

    return UserData(
      favorites: favorites,
      stops: stops,
      savedPlaces: savedPlaces,
      noteByPlace: notes,
      participants: participants,
      transportCostMinor: transport as int?,
      budgetMinor: budget as int?,
    );
  }
}

int? parseMoneyMinor(String input) {
  final value = input.trim().replaceAll(',', '.');
  if (value.isEmpty) return null;
  if (!RegExp(r'^\d{1,7}(?:\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException('Введите сумму, например 25 или 25,50');
  }
  final parts = value.split('.');
  final whole = int.parse(parts.first);
  final fractional = parts.length == 1
      ? 0
      : int.parse(parts.last.padRight(2, '0'));
  return whole * 100 + fractional;
}

String formatMoneyMinor(int amountMinor) {
  final whole = amountMinor ~/ 100;
  final fractional = (amountMinor % 100).abs();
  return '$whole,${fractional.toString().padLeft(2, '0')} BYN';
}

class BudgetSummary {
  const BudgetSummary({
    required this.knownSubtotalMinor,
    required this.missingVisitCosts,
    required this.transportCostKnown,
    required this.participants,
  });

  final int knownSubtotalMinor;
  final int missingVisitCosts;
  final bool transportCostKnown;
  final int participants;

  int get perPersonMinor =>
      (knownSubtotalMinor + participants ~/ 2) ~/ participants;
}

enum BudgetStatus { notSet, incomplete, withinBudget, overBudget }

class BudgetAssessment {
  const BudgetAssessment({
    required this.status,
    required this.knownSubtotalMinor,
    required this.missingCosts,
    required this.budgetMinor,
  });

  final BudgetStatus status;
  final int knownSubtotalMinor;
  final int missingCosts;
  final int? budgetMinor;

  int? get remainingMinor {
    final budget = budgetMinor;
    if (budget == null) return null;
    return budget - knownSubtotalMinor;
  }
}

class BudgetSuggestion {
  const BudgetSuggestion({
    required this.placeIdsToRemove,
    required this.savedMinor,
    required this.remainingMinor,
  });

  final List<String> placeIdsToRemove;
  final int savedMinor;
  final int remainingMinor;
}

BudgetSummary calculateBudget(UserData data) {
  if (data.participants < 1 || data.participants > 99) {
    throw RangeError.range(data.participants, 1, 99, 'participants');
  }
  var subtotal = data.transportCostMinor ?? 0;
  var missing = 0;
  for (final stop in data.stops) {
    final cost = stop.visitCostMinor;
    if (cost == null) {
      missing++;
    } else {
      subtotal += cost;
    }
  }
  return BudgetSummary(
    knownSubtotalMinor: subtotal,
    missingVisitCosts: missing,
    transportCostKnown: data.transportCostMinor != null,
    participants: data.participants,
  );
}

BudgetAssessment assessBudget(UserData data) {
  final budget = data.budgetMinor;
  final summary = calculateBudget(data);
  final missingCosts =
      summary.missingVisitCosts + (summary.transportCostKnown ? 0 : 1);
  final knownSubtotal = summary.knownSubtotalMinor;

  if (budget == null) {
    return BudgetAssessment(
      status: BudgetStatus.notSet,
      knownSubtotalMinor: knownSubtotal,
      missingCosts: missingCosts,
      budgetMinor: null,
    );
  }

  final status = knownSubtotal > budget
      ? BudgetStatus.overBudget
      : missingCosts > 0
      ? BudgetStatus.incomplete
      : BudgetStatus.withinBudget;
  return BudgetAssessment(
    status: status,
    knownSubtotalMinor: knownSubtotal,
    missingCosts: missingCosts,
    budgetMinor: budget,
  );
}

BudgetSuggestion? suggestBudgetAdjustment(UserData data) {
  final assessment = assessBudget(data);
  final budget = data.budgetMinor;
  if (budget == null ||
      assessment.status != BudgetStatus.overBudget ||
      assessment.missingCosts > 0) {
    return null;
  }

  final removableStops =
      data.stops.where((stop) => stop.visitCostMinor != null).toList()
        ..sort((a, b) => b.visitCostMinor!.compareTo(a.visitCostMinor!));
  final removedIds = <String>[];
  var remaining = assessment.knownSubtotalMinor;
  var saved = 0;
  for (final stop in removableStops) {
    final cost = stop.visitCostMinor!;
    if (cost <= 0) continue;
    removedIds.add(stop.placeId);
    saved += cost;
    remaining -= cost;
    if (remaining <= budget) break;
  }
  if (remaining > budget || removedIds.isEmpty) return null;

  return BudgetSuggestion(
    placeIdsToRemove: removedIds,
    savedMinor: saved,
    remainingMinor: remaining,
  );
}

List<PlanStop> reorderStops(List<PlanStop> stops, int oldIndex, int newIndex) {
  final reordered = List<PlanStop>.of(stops);
  final stop = reordered.removeAt(oldIndex);
  reordered.insert(newIndex, stop);
  return reordered;
}

double distanceBetweenMeters(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _toRadians(latitudeB - latitudeA);
  final dLon = _toRadians(longitudeB - longitudeA);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(latitudeA)) *
          math.cos(_toRadians(latitudeB)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
