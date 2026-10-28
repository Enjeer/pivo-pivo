import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../catalog.dart';
import '../domain.dart';
import '../local_store.dart';
import '../routing.dart';
import '../ui/pixel_components.dart';
import '../ui/pixel_theme.dart';
import 'plan_screen.dart';

const _minsk = LatLng(53.9006, 27.559);

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.controller,
    required this.showLiveMap,
    super.key,
  });

  final AppController controller;
  final bool showLiveMap;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  String? _selectedCategory;
  String _query = '';
  String? _selectedPlaceId;
  LatLng? _userLocation;
  bool _showList = false;
  bool _mapHadTileError = false;
  int _tileLayerRevision = 0;
  GeoBounds? _lastVisibleBounds;
  RouteEstimate? _lastDisplayedRoute;

  @override
  void initState() {
    super.initState();
    _lastDisplayedRoute = widget.controller.routeEstimate;
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.showLiveMap || widget.controller.isDemoCatalog) {
        return;
      }
      _loadVisiblePlaces();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final estimate = widget.controller.routeEstimate;
    if (identical(estimate, _lastDisplayedRoute)) return;
    _lastDisplayedRoute = estimate;
    if (estimate == null || !widget.showLiveMap) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: estimate.geometry
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(growable: false),
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 200),
        ),
      );
    });
  }

  List<Place> get _places => filterPlaces(
    widget.controller.places,
    query: _query,
    category: _selectedCategory,
  );

  Place? get _selectedPlace {
    for (final place in _places) {
      if (place.id == _selectedPlaceId) return place;
    }
    return null;
  }

  Widget _emptyResults() {
    final controller = widget.controller;
    if (!controller.isDemoCatalog && controller.places.isEmpty) {
      final (title, message) = switch (controller.catalogStatus) {
        CatalogLoadStatus.idle => (
          'Каталог не загружен',
          'Нажмите «Обновить», чтобы проверить заведения в этой области.',
        ),
        CatalogLoadStatus.loading => (
          'Загружаем каталог',
          'Проверяем OpenStreetMap для видимой области карты.',
        ),
        CatalogLoadStatus.error => (
          'Каталог недоступен',
          _catalogErrorMessage(controller.catalogError),
        ),
        CatalogLoadStatus.ready => (
          'Заведений не найдено',
          'В OpenStreetMap нет отмеченных заведений в этой области.',
        ),
      };
      return PixelStateMessage(title: title, message: message);
    }

    return _EmptySearchResults(
      query: _query,
      category: _selectedCategory,
      isDemo: controller.isDemoCatalog,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    final routeEstimate = widget.controller.routeEstimate;
    final selectedPlace = _selectedPlace;
    final showCatalogNotice =
        widget.controller.isDemoCatalog ||
        widget.controller.catalogStatus == CatalogLoadStatus.idle ||
        widget.controller.catalogStatus == CatalogLoadStatus.loading ||
        widget.controller.catalogStatus == CatalogLoadStatus.error;
    return Stack(
      children: [
        Positioned.fill(child: _showList ? _buildList() : _buildMap()),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                pixel.space8,
                pixel.space8,
                pixel.space8,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PixelSearchField(
                      key: const ValueKey('place-search'),
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  SizedBox(width: pixel.space4),
                  PixelIconButton(
                    icon: Icons.tune,
                    tooltip: 'Фильтры и режим карты',
                    selected: _selectedCategory != null || _showList,
                    onPressed: _showMapControls,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showCatalogNotice)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 64,
            left: pixel.space8,
            right: pixel.space8,
            child: _catalogNotice(),
          ),
        if (widget.showLiveMap && _mapHadTileError)
          Positioned(
            top:
                MediaQuery.paddingOf(context).top +
                pixel.space32 * 2 +
                (showCatalogNotice ? pixel.space32 * 2 : 0),
            left: pixel.space8,
            right: pixel.space8,
            child: PixelPanel(
              borderColor: pixel.danger,
              padding: EdgeInsets.symmetric(
                horizontal: pixel.space8,
                vertical: pixel.space4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Часть карты не загрузилась.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _retryMapTiles,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        if (widget.showLiveMap &&
            !_showList &&
            widget.controller.routeStatus == RouteLoadStatus.ready &&
            routeEstimate != null)
          Positioned(
            top:
                MediaQuery.paddingOf(context).top +
                pixel.space32 * 2 +
                (showCatalogNotice ? pixel.space32 * 2 : 0) +
                (_mapHadTileError ? pixel.space24 * 2 : 0),
            left: pixel.space8,
            child: PixelPanel(
              padding: EdgeInsets.symmetric(
                horizontal: pixel.space8,
                vertical: pixel.space4,
              ),
              child: Text(
                '${_formatDistance(routeEstimate.totalDistanceMeters)} · '
                '${_formatDuration(routeEstimate.totalDurationSeconds)} · '
                '${routeEstimate.mode.label}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        if (!_showList && widget.showLiveMap && selectedPlace != null)
          Positioned(
            left: pixel.space8,
            right: pixel.space8,
            bottom: pixel.space8,
            child: PixelPlaceCard(
              title: selectedPlace.name,
              subtitle: [
                selectedPlace.category,
                if (selectedPlace.address != null) selectedPlace.address!,
                selectedPlace.isDemo
                    ? 'демо-точка · не реальные данные'
                    : 'OpenStreetMap · сведения не подтверждены заведением',
              ].join(' · '),
              icon: _categoryIcon(selectedPlace.category),
              selected: true,
              onTap: () => _openPlace(selectedPlace),
              actionIcon: Icons.arrow_forward,
              actionTooltip: 'Подробности о заведении',
              onAction: () => _openPlace(selectedPlace),
            ),
          ),
        if (!_showList && !widget.showLiveMap && _places.isEmpty)
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                pixel.space16,
                pixel.space32 * 3,
                pixel.space16,
                pixel.space32 * 3,
              ),
              child: _emptyResults(),
            ),
          ),
        if (!_showList && !widget.showLiveMap && _places.isNotEmpty)
          Positioned(
            left: pixel.space8,
            right: pixel.space8,
            bottom: pixel.space8,
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _places.length,
              separatorBuilder: (_, _) => SizedBox(width: pixel.space8),
              itemBuilder: (context, index) {
                final place = _places[index];
                return SizedBox(
                  width: 280,
                  child: PixelPlaceCard(
                    title: place.name,
                    subtitle:
                        '${place.category} · демо-точка · не реальные данные',
                    icon: _categoryIcon(place.category),
                    onTap: () => _openPlace(place),
                  ),
                );
              },
            ),
          ),
        if (widget.showLiveMap)
          Positioned(
            right: pixel.space8,
            bottom: selectedPlace == null ? pixel.space8 : pixel.space32 * 3,
            child: PixelIconButton(
              icon: Icons.my_location_outlined,
              tooltip: 'Моё местоположение',
              selected: _userLocation != null,
              onPressed: _requestLocation,
            ),
          ),
        if (widget.showLiveMap)
          Positioned(
            left: pixel.space8,
            bottom: selectedPlace == null ? pixel.space8 : pixel.space32 * 3,
            child: Material(
              color: pixel.surface,
              child: InkWell(
                onTap: _openOsmAttribution,
                child: PixelPanel(
                  padding: EdgeInsets.symmetric(
                    horizontal: pixel.space8,
                    vertical: pixel.space4,
                  ),
                  child: const Text(
                    '© OpenStreetMap contributors · ODbL',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openPlan() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _showMapControls() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.pixel.surface,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) {
            final pixel = context.pixel;
            final controller = widget.controller;
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  pixel.space16,
                  pixel.space16,
                  pixel.space16,
                  pixel.space16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ФИЛЬТРЫ И КАРТА',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: pixel.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: pixel.space12),
                    Wrap(
                      spacing: pixel.space8,
                      runSpacing: pixel.space8,
                      children: [
                        for (final category in _categoryFilters)
                          PixelFilterChip(
                            label: category ?? 'Все места',
                            selected: category == _selectedCategory,
                            onSelected: (_) {
                              setState(() => _selectedCategory = category);
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                    SizedBox(height: pixel.space12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.map_outlined),
                            label: Text('Карта'),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.view_list_outlined),
                            label: Text('Список'),
                          ),
                        ],
                        selected: {_showList},
                        onSelectionChanged: (selection) {
                          setState(() => _showList = selection.single);
                          setSheetState(() {});
                        },
                      ),
                    ),
                    SizedBox(height: pixel.space12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openPlan();
                        },
                        icon: const Icon(Icons.route_outlined),
                        label: Text(
                          'План вечера · ${controller.data.stops.length}',
                        ),
                      ),
                    ),
                    SizedBox(height: pixel.space12),
                    PixelPanel(
                      color: pixel.raisedSurface,
                      padding: EdgeInsets.all(pixel.space8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              controller.isDemoCatalog
                                  ? 'Демо-каталог: точки тестовые, не реальные.'
                                  : _catalogStatusDescription(controller),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          if (!controller.isDemoCatalog)
                            IconButton(
                              tooltip: 'Обновить места в видимой области',
                              onPressed:
                                  controller.catalogStatus ==
                                      CatalogLoadStatus.loading
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      _loadVisiblePlaces(forceRefresh: true);
                                    },
                              icon: const Icon(Icons.refresh),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: pixel.space8),
                    TextButton.icon(
                      onPressed: () => showAboutDialog(
                        context: context,
                        applicationName: 'Пиво-Пиво',
                        applicationVersion: 'MVP',
                        children: const [
                          Text(
                            'Каталог показывает места из OpenStreetMap. '
                            'Наличие и сведения о каждом месте не подтверждаются '
                            'заведением.',
                          ),
                        ],
                      ),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Источник данных и ограничения'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _catalogStatusDescription(
    AppController controller,
  ) => switch (controller.catalogStatus) {
    CatalogLoadStatus.idle => 'Приблизьте карту и загрузите места в области.',
    CatalogLoadStatus.loading => 'Загружаем OpenStreetMap…',
    CatalogLoadStatus.ready =>
      'OpenStreetMap · ${controller.places.length} мест'
          '${controller.catalogIsCached ? ' · кэш' : ''}'
          '${controller.catalogFetchedAt == null ? '' : ' · ${_formatCatalogTime(controller.catalogFetchedAt!)}'}',
    CatalogLoadStatus.error =>
      'Не удалось обновить каталог: ${_catalogErrorMessage(controller.catalogError)}',
  };

  List<String?> get _categoryFilters => [
    null,
    ...widget.controller.places.map((place) => place.category).toSet(),
  ];

  Widget _catalogNotice() {
    final controller = widget.controller;
    final pixel = context.pixel;
    if (controller.isDemoCatalog) {
      return const _DemoNotice();
    }

    final status = switch (controller.catalogStatus) {
      CatalogLoadStatus.idle => 'Приблизьте карту и загрузите места в области.',
      CatalogLoadStatus.loading => 'Загружаем места OpenStreetMap…',
      CatalogLoadStatus.ready =>
        '${controller.catalogIsTruncated ? 'Показана часть мест; приблизьте карту. ' : ''}'
            'OpenStreetMap · ${controller.places.length} мест'
            '${controller.catalogIsCached ? ' · кэш' : ' · получено'}'
            '${controller.catalogFetchedAt == null ? '' : ' ${_formatCatalogTime(controller.catalogFetchedAt!)}'}',
      CatalogLoadStatus.error =>
        controller.places.isEmpty
            ? 'Не удалось загрузить каталог: '
                  '${_catalogErrorMessage(controller.catalogError)}'
            : 'Обновление не удалось. Осталась предыдущая выдача'
                  '${controller.catalogFetchedAt == null ? '' : ' от ${_formatCatalogTime(controller.catalogFetchedAt!)}'}. '
                  '${_catalogErrorMessage(controller.catalogError)}',
    };

    return PixelPanel(
      color: pixel.surface,
      padding: EdgeInsets.symmetric(
        horizontal: pixel.space8,
        vertical: pixel.space4,
      ),
      borderColor: controller.catalogStatus == CatalogLoadStatus.error
          ? pixel.danger
          : pixel.accent,
      child: Row(
        children: [
          if (controller.catalogStatus == CatalogLoadStatus.loading)
            SizedBox(
              width: pixel.space16,
              height: pixel.space16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: pixel.accent,
              ),
            )
          else
            Icon(Icons.place_outlined, size: 16, color: pixel.accent),
          SizedBox(width: pixel.space8),
          Expanded(
            child: Text(
              status,
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Обновить каталог для видимой области карты',
            onPressed: controller.catalogStatus == CatalogLoadStatus.loading
                ? null
                : () => _loadVisiblePlaces(forceRefresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Future<void> _loadVisiblePlaces({
    LatLngBounds? bounds,
    bool forceRefresh = false,
  }) async {
    if (!mounted || !widget.showLiveMap || widget.controller.isDemoCatalog) {
      return;
    }
    try {
      final area = switch ((bounds, _lastVisibleBounds)) {
        (final visibleBounds?, _) => GeoBounds(
          south: visibleBounds.south,
          west: visibleBounds.west,
          north: visibleBounds.north,
          east: visibleBounds.east,
        ),
        (_, final cachedBounds?) => cachedBounds,
        _ => _visibleBoundsFromCamera(),
      };
      _lastVisibleBounds = area;
      await widget.controller.loadPlaces(area, forceRefresh: forceRefresh);
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить места: $error')),
      );
    }
  }

  GeoBounds _visibleBoundsFromCamera() {
    final visible = _mapController.camera.visibleBounds;
    return GeoBounds(
      south: visible.south,
      west: visible.west,
      north: visible.north,
      east: visible.east,
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        Positioned.fill(
          child: widget.showLiveMap
              ? FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _minsk,
                    initialZoom: 13,
                    minZoom: 10,
                    maxZoom: 18,
                    onTap: (_, _) => setState(() => _selectedPlaceId = null),
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        final visible = camera.visibleBounds;
                        _lastVisibleBounds = GeoBounds(
                          south: visible.south,
                          west: visible.west,
                          north: visible.north,
                          east: visible.east,
                        );
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      key: ValueKey(_tileLayerRevision),
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.enjeer.pivo_pivo',
                      tileProvider: NetworkTileProvider(
                        cachingProvider:
                            BuiltInMapCachingProvider.getOrCreateInstance(
                              maxCacheSize: 64 * 1024 * 1024,
                            ),
                      ),
                      maxZoom: 19,
                      errorTileCallback: (_, _, _) {
                        if (mounted && !_mapHadTileError) {
                          setState(() => _mapHadTileError = true);
                        }
                      },
                    ),
                    if (_userLocation case final location?)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: location,
                            radius: 8,
                            useRadiusInMeter: false,
                            color: context.pixel.accent,
                            borderColor: context.pixel.onAccent,
                            borderStrokeWidth: context.pixel.borderWidth,
                          ),
                        ],
                      ),
                    if (widget.controller.routeEstimate case final route?)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route.geometry
                                .map(
                                  (point) =>
                                      LatLng(point.latitude, point.longitude),
                                )
                                .toList(growable: false),
                            strokeWidth: 4,
                            color: context.pixel.accent,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: _places.map(_buildMarker).toList()),
                  ],
                )
              : const _DemoMapArtwork(),
        ),
      ],
    );
  }

  Widget _buildList() {
    final pixel = context.pixel;
    if (_places.isEmpty) {
      return _emptyResults();
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        pixel.space16,
        MediaQuery.paddingOf(context).top + pixel.space32 * 2,
        pixel.space16,
        pixel.space24,
      ),
      itemCount: _places.length,
      separatorBuilder: (_, _) => SizedBox(height: pixel.space8),
      itemBuilder: (context, index) {
        final place = _places[index];
        return PixelPlaceCard(
          title: place.name,
          subtitle:
              '${place.category} · '
              '${place.isDemo ? 'демо-точка' : 'OpenStreetMap'}'
              '${place.address == null ? '' : ' · ${place.address}'}',
          icon: _categoryIcon(place.category),
          selected: place.id == _selectedPlaceId,
          onTap: () => _openPlace(place),
        );
      },
    );
  }

  Future<void> _requestLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationError(
          'Геолокация отключена. Включите службу геолокации '
          'или продолжайте без неё.',
          openLocationSettings: true,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showLocationError(
          'Нет разрешения на геолокацию. Местоположение не показано.',
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationError(
          'Доступ к геолокации запрещён в настройках устройства.',
          openAppSettings: true,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      final location = LatLng(position.latitude, position.longitude);
      setState(() => _userLocation = location);
      if (widget.showLiveMap) _mapController.move(location, 15);
    } on LocationServiceDisabledException {
      _showLocationError(
        'Геолокация отключена. Включите службу геолокации '
        'или продолжайте без неё.',
        openLocationSettings: true,
      );
    } on PermissionDefinitionsNotFoundException {
      _showLocationError(
        'В сборке не настроено разрешение геолокации. '
        'Обновите приложение и попробуйте снова.',
      );
    } on Exception catch (error) {
      _showLocationError('Не удалось получить местоположение: $error');
    }
  }

  Future<void> _openOsmAttribution() async {
    try {
      final opened = await launchUrl(
        Uri.https('www.openstreetmap.org', '/copyright'),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть сведения о лицензии OSM.'),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось открыть сведения о лицензии OSM: $error'),
        ),
      );
    }
  }

  void _retryMapTiles() {
    setState(() {
      _mapHadTileError = false;
      _tileLayerRevision++;
    });
  }

  void _showLocationError(
    String message, {
    bool openAppSettings = false,
    bool openLocationSettings = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: openAppSettings || openLocationSettings
              ? SnackBarAction(
                  label: 'Настройки',
                  onPressed: () {
                    if (openLocationSettings) {
                      Geolocator.openLocationSettings();
                    } else {
                      Geolocator.openAppSettings();
                    }
                  },
                )
              : SnackBarAction(label: 'Повторить', onPressed: _requestLocation),
        ),
      );
  }

  void _openPlace(Place place) {
    setState(() => _selectedPlaceId = place.id);
    showPlaceDetails(context, widget.controller, place);
  }

  void _selectPlace(Place place) {
    setState(() => _selectedPlaceId = place.id);
  }

  Marker _buildMarker(Place place) {
    final planIndex = widget.controller.data.stops.indexWhere(
      (stop) => stop.placeId == place.id,
    );
    return Marker(
      point: LatLng(place.latitude, place.longitude),
      width: 44,
      height: 48,
      alignment: Alignment.topCenter,
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: () => _selectPlace(place),
          child: PixelMarker(
            icon: _categoryIcon(place.category),
            label:
                '${place.name}, ${place.category}, '
                '${place.isDemo ? 'демо-точка' : 'OpenStreetMap'}',
            selected: place.id == _selectedPlaceId,
            planOrder: planIndex < 0 ? null : planIndex + 1,
          ),
        ),
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return PixelPanel(
      color: pixel.surface,
      padding: EdgeInsets.symmetric(
        horizontal: pixel.space8,
        vertical: pixel.space8,
      ),
      borderColor: pixel.accent,
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: pixel.accent),
          SizedBox(width: pixel.space8),
          Expanded(
            child: Text(
              'ДЕМО-КАТАЛОГ · точки тестовые, не реальные заведения',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySearchResults extends StatelessWidget {
  const _EmptySearchResults({
    required this.query,
    required this.category,
    this.isDemo = true,
  });

  final String query;
  final String? category;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return PixelStateMessage(
      title: 'Пока пусто',
      message: isDemo
          ? query.isEmpty
                ? 'В этой демо-категории пока нет точек'
                : 'В демо-каталоге нет совпадений для «$query»'
          : query.isNotEmpty
          ? 'В загруженных местах нет совпадений для «$query»'
          : 'В загруженных местах нет совпадений'
                '${category == null ? '' : ' по категории «$category»'}',
    );
  }
}

IconData _categoryIcon(String category) => switch (category) {
  'Бар' => Icons.local_bar_outlined,
  'Паб' => Icons.local_bar_outlined,
  'Кафе' => Icons.local_cafe_outlined,
  'Ресторан' => Icons.restaurant_outlined,
  'Фастфуд' => Icons.fastfood_outlined,
  'Клуб' => Icons.music_note,
  'Кальянная' => Icons.smoking_rooms_outlined,
  _ => Icons.place_outlined,
};

String _formatCatalogTime(DateTime time) {
  final local = time.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _catalogErrorMessage(Object? error) {
  if (error is TimeoutException) {
    return 'Тайм-аут Overpass. Проверьте сеть и обновите.';
  }
  if (error is StateError) return error.message.toString();
  if (error is FormatException) return error.message;
  return 'Сетевая ошибка. Проверьте подключение и повторите.';
}

String _formatDistance(double meters) => meters < 1000
    ? '${meters.round()} м'
    : '${(meters / 1000).toStringAsFixed(1)} км';

String _formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  return minutes < 1 ? '${seconds.round()} с' : '$minutes мин';
}

String _placeProvenanceText(Place place) {
  final details = <String>[
    'Категория и координаты из OpenStreetMap; проверка заведением не выполнялась.',
    if (place.cuisine != null) 'Кухня по OSM: ${place.cuisine}.',
    if (place.phone != null) 'Телефон по OSM: ${place.phone}.',
  ];
  return details.join(' ');
}

Future<void> showPlaceDetails(
  BuildContext context,
  AppController controller,
  Place place,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.pixel.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (context) =>
        _PlaceDetailsSheet(controller: controller, place: place),
  );
}

class _PlaceDetailsSheet extends StatelessWidget {
  const _PlaceDetailsSheet({required this.controller, required this.place});

  final AppController controller;
  final Place place;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        pixel.space16,
        pixel.space12,
        pixel.space16,
        pixel.space16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final isFavorite = controller.data.favorites.contains(place.id);
          final inPlan = controller.data.stops.any(
            (stop) => stop.placeId == place.id,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelPlacePopupCard(
                title: place.name,
                category:
                    '${place.category} · '
                    '${place.isDemo ? 'демонстрационная запись' : 'OpenStreetMap'}',
                onClose: () => Navigator.pop(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.description,
                      style: TextStyle(color: pixel.onAccent),
                    ),
                    SizedBox(height: pixel.space8),
                    Text(
                      place.isDemo
                          ? 'Адрес, часы и цены не загружены. Каталог содержит '
                                'только демонстрационные точки.'
                          : _placeProvenanceText(place),
                      style: TextStyle(color: pixel.onAccent),
                    ),
                    SizedBox(height: pixel.space12),
                    if (place.priceObservations.isEmpty)
                      const ProvenanceBadge(kind: ProvenanceKind.unknown)
                    else
                      _PriceProvenanceList(
                        observations: place.priceObservations,
                      ),
                    if (place.address != null) ...[
                      SizedBox(height: pixel.space8),
                      Text(
                        'Адрес: ${place.address}',
                        style: TextStyle(color: pixel.onAccent),
                      ),
                    ],
                    if (place.openingHours != null) ...[
                      SizedBox(height: pixel.space8),
                      Text(
                        'Часы по OSM: ${place.openingHours}',
                        style: TextStyle(color: pixel.onAccent),
                      ),
                    ],
                    if (place.sourceReference != null) ...[
                      SizedBox(height: pixel.space8),
                      TextButton.icon(
                        onPressed: () =>
                            _openPlaceSource(context, place.sourceReference!),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Источник OpenStreetMap'),
                      ),
                    ],
                    SizedBox(height: pixel.space12),
                    Wrap(
                      spacing: pixel.space8,
                      runSpacing: pixel.space8,
                      children: [
                        FilledButton.icon(
                          onPressed: inPlan
                              ? null
                              : () => performUserAction(
                                  context,
                                  controller.addStop(place.id),
                                  successMessage: 'Добавлено в план',
                                ),
                          icon: Icon(inPlan ? Icons.check : Icons.add_road),
                          label: Text(inPlan ? 'Уже в плане' : 'В план вечера'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => performUserAction(
                            context,
                            controller.toggleFavorite(place.id),
                            successMessage: isFavorite
                                ? 'Убрано из сохранённого'
                                : 'Сохранено в избранное',
                          ),
                          icon: Icon(
                            isFavorite ? Icons.bookmark : Icons.bookmark_border,
                          ),
                          label: Text(isFavorite ? 'Сохранено' : 'В избранное'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _editNote(context),
                          icon: const Icon(Icons.edit_note),
                          label: Text(
                            controller.data.noteByPlace.containsKey(place.id)
                                ? 'Изменить заметку'
                                : 'Личная заметка',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editNote(BuildContext context) async {
    final noteController = TextEditingController(
      text: controller.data.noteByPlace[place.id] ?? '',
    );
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Личная заметка'),
        content: TextField(
          controller: noteController,
          autofocus: true,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Только на этом устройстве',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, noteController.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (note == null || !context.mounted) return;
    await performUserAction(
      context,
      controller.updateNote(place.id, note),
      successMessage: 'Личная заметка сохранена на устройстве',
    );
  }
}

Future<void> _openPlaceSource(BuildContext context, String reference) async {
  try {
    final opened = await launchUrl(
      Uri.parse(reference),
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть карточку OSM.')),
    );
  } on Exception catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось открыть карточку OSM: $error')),
    );
  }
}

class _PriceProvenanceList extends StatelessWidget {
  const _PriceProvenanceList({required this.observations});

  final List<PriceObservation> observations;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final observation in observations) ...[
          Text(
            observation.amountMinor == null
                ? 'Цена: нет данных'
                : 'Цена: ${_formatPriceObservation(observation)}',
            style: TextStyle(color: pixel.onAccent),
          ),
          Text(
            '${_priceStatusLabel(observation)} · ${observation.sourceLabel}'
            '${observation.observedAt == null ? ' · дата получения неизвестна' : ' · ${_formatCatalogTime(observation.observedAt!)}'}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: pixel.onAccent),
          ),
          if (observation.sourceReference != null)
            Text(
              observation.sourceReference!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: pixel.onAccent),
            ),
          SizedBox(height: pixel.space4),
        ],
      ],
    );
  }
}

String _formatPriceObservation(PriceObservation observation) {
  final amount = observation.amountMinor!;
  if (observation.currency == 'BYN') return formatMoneyMinor(amount);
  return '${amount ~/ 100},${(amount % 100).toString().padLeft(2, '0')} '
      '${observation.currency}';
}

String _priceStatusLabel(PriceObservation observation) {
  if (observation.isStaleAt(DateTime.now())) return 'Устаревшие данные';
  return switch (observation.status) {
    PriceVerification.verified => 'Подтверждённая цена',
    PriceVerification.estimated => 'Оценка',
    PriceVerification.stale => 'Устаревшие данные',
    PriceVerification.unknown => 'Не проверено',
  };
}

class _DemoMapArtwork extends StatelessWidget {
  const _DemoMapArtwork();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DemoMapPainter(
        background: context.pixel.background,
        street: context.pixel.line,
        mainStreet: context.pixel.dimAccent,
        park: context.pixel.raisedSurface,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _DemoMapPainter extends CustomPainter {
  const _DemoMapPainter({
    required this.background,
    required this.street,
    required this.mainStreet,
    required this.park,
  });

  final Color background;
  final Color street;
  final Color mainStreet;
  final Color park;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final streetPaint = Paint()
      ..color = street
      ..strokeWidth = 3;
    final mainStreetPaint = Paint()
      ..color = mainStreet
      ..strokeWidth = 7;
    for (var index = -2; index < 14; index++) {
      final offset = index * 64.0;
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + 180, size.height),
        streetPaint,
      );
      canvas.drawLine(
        Offset(0, offset),
        Offset(size.width, offset + 40),
        streetPaint,
      );
    }
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.8),
      Offset(size.width * 0.88, size.height * 0.22),
      mainStreetPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.7, size.height * 0.72),
        width: size.width * 0.25,
        height: 70,
      ),
      Paint()..color = park,
    );
  }

  @override
  bool shouldRepaint(covariant _DemoMapPainter oldDelegate) =>
      background != oldDelegate.background ||
      street != oldDelegate.street ||
      mainStreet != oldDelegate.mainStreet ||
      park != oldDelegate.park;
}
