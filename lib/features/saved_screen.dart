import 'package:flutter/material.dart';

import '../app.dart';
import '../local_store.dart';
import '../ui/pixel_components.dart';
import '../ui/pixel_theme.dart';
import 'map_screen.dart';
import 'plan_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ваше'),
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
              padding: EdgeInsets.fromLTRB(
                pixel.space16,
                pixel.space4,
                pixel.space16,
                pixel.space16,
              ),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.bookmark_border),
                    label: Text('Избранное'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.edit_note),
                    label: Text('Заметки'),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (selected) {
                  setState(() => _section = selected.first);
                },
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) => _section == 0
                    ? _FavoritesList(controller: widget.controller)
                    : _NotesList(controller: widget.controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesList extends StatelessWidget {
  const _FavoritesList({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    final places = controller.knownPlaces
        .where((place) => controller.data.favorites.contains(place.id))
        .toList(growable: false);
    if (places.isEmpty) {
      return const _SavedEmptyState(
        icon: Icons.bookmark_border,
        title: 'Пока ничего не сохранено',
        subtitle: 'Отмечайте места на карте, чтобы быстро найти их позже.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        pixel.space16,
        0,
        pixel.space16,
        pixel.space24,
      ),
      itemCount: places.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final place = places[index];
        return PixelPlaceCard(
          title: place.name,
          subtitle:
              '${place.category} · '
              '${place.isDemo ? 'демо-запись' : 'OpenStreetMap'}'
              '${place.address == null ? '' : ' · ${place.address}'}',
          icon: Icons.place_outlined,
          onTap: () => showPlaceDetails(context, controller, place),
          actionIcon: Icons.bookmark_remove_outlined,
          actionTooltip: 'Убрать из избранного',
          onAction: () => performUserAction(
            context,
            controller.toggleFavorite(place.id),
            successMessage: 'Убрано из избранного',
          ),
        );
      },
    );
  }
}

class _NotesList extends StatelessWidget {
  const _NotesList({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    final entries = controller.data.noteByPlace.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) {
      return const _SavedEmptyState(
        icon: Icons.edit_note,
        title: 'Записей пока нет',
        subtitle:
            'Добавляйте личные заметки из карточек мест. '
            'Они остаются на устройстве.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        pixel.space16,
        0,
        pixel.space16,
        pixel.space24,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final place = controller.findPlace(entry.key);
        return Card(
          child: ListTile(
            onTap: place == null
                ? null
                : () => showPlaceDetails(context, controller, place),
            leading: Container(
              width: pixel.space32,
              height: pixel.space32,
              color: pixel.raisedSurface,
              alignment: Alignment.center,
              child: Icon(Icons.lock_outline, color: pixel.accent),
            ),
            title: Text(place?.name ?? 'Архивная заметка'),
            subtitle: Text(
              entry.value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: entry.value.length > 45,
          ),
        );
      },
    );
  }
}

class _SavedEmptyState extends StatelessWidget {
  const _SavedEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(pixel.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: pixel.accent),
            SizedBox(height: pixel.space12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: pixel.space8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
