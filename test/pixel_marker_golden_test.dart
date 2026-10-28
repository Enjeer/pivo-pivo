import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pivo_pivo/ui/pixel_components.dart';
import 'package:pivo_pivo/ui/pixel_theme.dart';

void main() {
  testWidgets('pixel markers show ordinary, selected and planned states', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 140));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPixelTheme(),
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MarkerExample(
                  title: 'ОБЫЧНОЕ',
                  marker: const PixelMarker(
                    icon: Icons.local_bar_outlined,
                    label: 'Бар',
                  ),
                ),
                const SizedBox(width: 24),
                _MarkerExample(
                  title: 'ВЫБРАНО',
                  marker: const PixelMarker(
                    icon: Icons.local_cafe_outlined,
                    label: 'Кафе, выбрано',
                    selected: true,
                  ),
                ),
                const SizedBox(width: 24),
                _MarkerExample(
                  title: 'В ПЛАНЕ',
                  marker: const PixelMarker(
                    icon: Icons.place_outlined,
                    label: 'Остановка 02',
                    planOrder: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/pixel_marker_states.png'),
    );
  });
}

class _MarkerExample extends StatelessWidget {
  const _MarkerExample({required this.title, required this.marker});

  final String title;
  final Widget marker;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
