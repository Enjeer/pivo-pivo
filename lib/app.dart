import 'package:flutter/material.dart';

import 'domain.dart';
import 'features/map_screen.dart';
import 'features/profile_screen.dart';
import 'features/search_screen.dart';
import 'features/saved_screen.dart';
import 'local_store.dart';
import 'ui/pixel_components.dart';
import 'ui/pixel_theme.dart';

ThemeData buildAppTheme() {
  return buildPixelTheme();
}

class PivoPivoApp extends StatelessWidget {
  const PivoPivoApp({
    required this.controller,
    this.showLiveMap = true,
    super.key,
  });

  final AppController controller;
  final bool showLiveMap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Пиво-Пиво',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AppShell(controller: controller, showLiveMap: showLiveMap),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.controller,
    required this.showLiveMap,
    super.key,
  });

  final AppController controller;
  final bool showLiveMap;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late Future<void> _initialization;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _initialization = widget.controller.initialize();
  }

  void _retryLoading() {
    setState(() {
      _initialization = widget.controller.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: context.pixel.accent),
            ),
          );
        }
        if (snapshot.hasError || widget.controller.loadError != null) {
          return _StorageErrorScreen(
            onRetry: _retryLoading,
            error: snapshot.error ?? widget.controller.loadError!,
          );
        }
        return ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final destinations = [
              const PixelBottomNavItem(
                icon: Icons.public,
                selectedIcon: Icons.public,
                label: 'Карта',
              ),
              const PixelBottomNavItem(
                icon: Icons.search,
                selectedIcon: Icons.search,
                label: 'Поиск',
              ),
              const PixelBottomNavItem(
                icon: Icons.favorite_border,
                selectedIcon: Icons.favorite,
                label: 'Избранное',
              ),
              const PixelBottomNavItem(
                icon: Icons.face_outlined,
                selectedIcon: Icons.face,
                label: 'Профиль',
              ),
            ];
            return Scaffold(
              body: IndexedStack(
                index: _selectedTab,
                children: [
                  MapScreen(
                    controller: widget.controller,
                    showLiveMap: widget.showLiveMap,
                  ),
                  SearchScreen(controller: widget.controller),
                  SavedScreen(controller: widget.controller),
                  ProfileScreen(controller: widget.controller),
                ],
              ),
              bottomNavigationBar: PixelBottomNav(
                items: destinations,
                selectedIndex: _selectedTab,
                onSelected: (index) => setState(() => _selectedTab = index),
              ),
            );
          },
        );
      },
    );
  }
}

class _StorageErrorScreen extends StatelessWidget {
  const _StorageErrorScreen({required this.onRetry, required this.error});

  final VoidCallback onRetry;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.pixel.space24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 40, color: context.pixel.accent),
                SizedBox(height: context.pixel.space16),
                Text(
                  'Не удалось открыть локальные данные',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: context.pixel.space8),
                const Text(
                  'Данные не сброшены. Проверьте доступ к защищённому '
                  'хранилищу устройства и повторите попытку.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.pixel.space12),
                SelectableText(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(height: context.pixel.space24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> performUserAction(
  BuildContext context,
  Future<void> action, {
  String successMessage = 'Сохранено',
}) async {
  try {
    await action;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(successMessage)));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Не удалось сохранить: $error')));
  }
}

Place? placeById(String placeId) {
  for (final place in demoPlaces) {
    if (place.id == placeId) return place;
  }
  return null;
}
