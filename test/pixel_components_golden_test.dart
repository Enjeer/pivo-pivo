import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pivo_pivo/ui/pixel_components.dart';
import 'package:pivo_pivo/ui/pixel_theme.dart';

void main() {
  testWidgets('Pixel Night City panels and navigation render consistently', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(360, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPixelTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelPlaceCard(
                    title: 'Бар на проспекте',
                    subtitle: 'Бар · OpenStreetMap · сведения не подтверждены',
                    icon: Icons.local_bar_outlined,
                    selected: true,
                    onTap: () {},
                    actionIcon: Icons.arrow_forward,
                    actionTooltip: 'Подробности',
                    onAction: () {},
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PixelFilterChip(
                        label: 'Бары',
                        selected: true,
                        onSelected: (_) {},
                      ),
                      const SizedBox(width: 8),
                      PixelIconButton(
                        icon: Icons.tune,
                        tooltip: 'Фильтры',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: PixelBottomNav(
            items: const [
              PixelBottomNavItem(
                icon: Icons.public,
                selectedIcon: Icons.public,
                label: 'Карта',
              ),
              PixelBottomNavItem(
                icon: Icons.search,
                selectedIcon: Icons.search,
                label: 'Поиск',
              ),
              PixelBottomNavItem(
                icon: Icons.favorite_border,
                selectedIcon: Icons.favorite,
                label: 'Избранное',
              ),
              PixelBottomNavItem(
                icon: Icons.face_outlined,
                selectedIcon: Icons.face,
                label: 'Профиль',
              ),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Карта'), findsOneWidget);
    semantics.dispose();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/pixel_night_components.png'),
    );
  });
}
