import 'package:flutter/material.dart';

import '../domain.dart';
import '../local_store.dart';
import '../ui/pixel_components.dart';
import '../ui/pixel_theme.dart';
import 'map_screen.dart';
import 'plan_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pixel = context.pixel;
        final categories = <String?>[
          null,
          ...widget.controller.places.map((place) => place.category).toSet(),
        ];
        final results = filterPlaces(
          widget.controller.places,
          query: _queryController.text,
          category: _category,
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('Поиск мест'),
            actions: [
              IconButton(
                tooltip: 'Открыть план вечера',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlanScreen(controller: widget.controller),
                  ),
                ),
                icon: const Icon(Icons.route_outlined),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(pixel.space16),
                  child: PixelSearchField(
                    controller: _queryController,
                    onChanged: (_) => setState(() {}),
                    hintText: 'КУДА ДВИГАЕМ',
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: pixel.space16),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => SizedBox(width: pixel.space8),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return PixelFilterChip(
                        label: category ?? 'Все места',
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      );
                    },
                  ),
                ),
                SizedBox(height: pixel.space12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pixel.space16),
                  child: _catalogStatusPanel(context),
                ),
                SizedBox(height: pixel.space8),
                Expanded(
                  child: results.isEmpty
                      ? PixelStateMessage(
                          title: 'Совпадений нет',
                          message: widget.controller.isDemoCatalog
                              ? 'В тестовом каталоге ничего не нашлось.'
                              : 'В загруженной области нет совпадений. '
                                    'Загрузите места на карте или измените поиск.',
                          actionLabel: 'Сбросить фильтры',
                          onAction: () {
                            _queryController.clear();
                            setState(() => _category = null);
                          },
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            pixel.space16,
                            pixel.space8,
                            pixel.space16,
                            pixel.space24,
                          ),
                          itemCount: results.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(height: pixel.space8),
                          itemBuilder: (context, index) {
                            final place = results[index];
                            return PixelPlaceCard(
                              title: place.name,
                              subtitle:
                                  '${place.category} · '
                                  '${place.isDemo ? 'демо-точка' : 'OpenStreetMap'}'
                                  '${place.address == null ? '' : ' · ${place.address}'}',
                              icon: Icons.place_outlined,
                              onTap: () => showPlaceDetails(
                                context,
                                widget.controller,
                                place,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _catalogStatusPanel(BuildContext context) {
    final pixel = context.pixel;
    final message = switch (widget.controller.catalogStatus) {
      CatalogLoadStatus.idle =>
        'Откройте карту и загрузите места в видимой области.',
      CatalogLoadStatus.loading => 'Загружаем OpenStreetMap…',
      CatalogLoadStatus.ready when widget.controller.isDemoCatalog =>
        'Демо-каталог: точки тестовые, не реальные заведения.',
      CatalogLoadStatus.ready =>
        '${widget.controller.catalogSource}: '
            '${widget.controller.places.length} мест в загруженной области.',
      CatalogLoadStatus.error =>
        'Каталог недоступен. Проверьте сеть и обновите его на карте.',
    };
    return PixelPanel(
      color: pixel.raisedSurface,
      borderColor: widget.controller.catalogStatus == CatalogLoadStatus.error
          ? pixel.danger
          : pixel.accent,
      child: Row(
        children: [
          if (widget.controller.catalogStatus == CatalogLoadStatus.loading)
            SizedBox(
              width: pixel.space16,
              height: pixel.space16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: pixel.accent,
              ),
            )
          else
            Icon(Icons.place_outlined, color: pixel.accent),
          SizedBox(width: pixel.space8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
