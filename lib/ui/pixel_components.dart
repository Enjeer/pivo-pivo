import 'package:flutter/material.dart';

import 'pixel_theme.dart';

class PixelPanel extends StatelessWidget {
  const PixelPanel({
    required this.child,
    this.color,
    this.padding,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Container(
      padding: padding ?? EdgeInsets.all(pixel.space12),
      decoration: BoxDecoration(
        color: color ?? pixel.surface,
        border: Border.all(
          color: borderColor ?? pixel.line,
          width: pixel.borderWidth,
        ),
      ),
      child: child,
    );
  }
}

class PixelSearchField extends StatelessWidget {
  const PixelSearchField({
    required this.controller,
    required this.onChanged,
    this.onHelp,
    this.onSubmitted,
    this.hintText = 'КУДА ДВИГАЕМ',
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onHelp;
  final ValueChanged<String>? onSubmitted;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Очистить поиск',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close),
              ),
            if (onHelp != null)
              IconButton(
                tooltip: 'О приложении',
                onPressed: onHelp,
                icon: const Icon(Icons.help_outline),
              ),
          ],
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: pixel.accent, width: pixel.borderWidth),
        ),
      ),
    );
  }
}

class PixelFilterChip extends StatelessWidget {
  const PixelFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? pixel.accent : pixel.surface,
        child: InkWell(
          onTap: () => onSelected(!selected),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(horizontal: pixel.space12),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? pixel.accent : pixel.line,
                width: pixel.borderWidth,
              ),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? pixel.onAccent : pixel.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PixelBottomNavItem {
  const PixelBottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class PixelBottomNav extends StatelessWidget {
  const PixelBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<PixelBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          pixel.space12,
          pixel.space4,
          pixel.space12,
          pixel.space8,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: pixel.surface,
            border: Border.all(color: pixel.line, width: pixel.borderWidth),
          ),
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _BottomNavButton(
                    item: items[index],
                    selected: selectedIndex == index,
                    onPressed: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final PixelBottomNavItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                color: selected ? pixel.accent : Colors.transparent,
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected ? pixel.onAccent : pixel.primaryText,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum ProvenanceKind { confirmed, estimate, unknown }

class PixelIconButton extends StatelessWidget {
  const PixelIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? pixel.accent : pixel.surface,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? pixel.accent : pixel.line,
                  width: pixel.borderWidth,
                ),
              ),
              child: Icon(
                icon,
                color: selected ? pixel.onAccent : pixel.primaryText,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PixelPlaceCard extends StatelessWidget {
  const PixelPlaceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
    this.selected = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Material(
      color: pixel.surface,
      child: InkWell(
        onTap: onTap,
        child: PixelPanel(
          color: pixel.surface,
          borderColor: selected ? pixel.accent : pixel.line,
          padding: EdgeInsets.all(pixel.space8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                color: selected ? pixel.accent : pixel.raisedSurface,
                child: Icon(
                  icon,
                  color: selected ? pixel.onAccent : pixel.accent,
                  size: 20,
                ),
              ),
              SizedBox(width: pixel.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: pixel.primaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: pixel.space4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (actionIcon case final icon?)
                IconButton(
                  tooltip: actionTooltip,
                  onPressed: onAction,
                  icon: Icon(icon, color: pixel.accent),
                )
              else
                Icon(Icons.chevron_right, color: pixel.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class PixelMarker extends StatelessWidget {
  const PixelMarker({
    required this.icon,
    required this.label,
    this.selected = false,
    this.planOrder,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int? planOrder;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    final isPlanned = planOrder != null;
    final fill = selected || isPlanned ? pixel.accent : pixel.surface;
    final foreground = selected || isPlanned ? pixel.onAccent : pixel.accent;
    return Semantics(
      label: label,
      child: CustomPaint(
        painter: _PixelMarkerPainter(
          fill: fill,
          stroke: pixel.accent,
          strokeWidth: pixel.borderWidth,
        ),
        child: SizedBox(
          width: 44,
          height: 48,
          child: Align(
            alignment: const Alignment(0, -0.28),
            child: isPlanned
                ? Text(
                    '${planOrder!}'.padLeft(2, '0'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : Icon(icon, size: 20, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _PixelMarkerPainter extends CustomPainter {
  const _PixelMarkerPainter({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
  });

  final Color fill;
  final Color stroke;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(size.width * 0.1, size.height * 0.4)
      ..lineTo(size.width * 0.1, size.height * 0.2)
      ..lineTo(size.width * 0.3, 0)
      ..lineTo(size.width * 0.7, 0)
      ..lineTo(size.width * 0.9, size.height * 0.2)
      ..lineTo(size.width * 0.9, size.height * 0.4)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _PixelMarkerPainter oldDelegate) =>
      fill != oldDelegate.fill ||
      stroke != oldDelegate.stroke ||
      strokeWidth != oldDelegate.strokeWidth;
}

class ProvenanceBadge extends StatelessWidget {
  const ProvenanceBadge({required this.kind, this.age, this.source, super.key});

  final ProvenanceKind kind;
  final String? age;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    final (label, marker, color) = switch (kind) {
      ProvenanceKind.confirmed => ('подтверждено', '✓', pixel.accent),
      ProvenanceKind.estimate => ('оценка', '≈', pixel.warning),
      ProvenanceKind.unknown => ('нет данных', '—', pixel.mutedText),
    };
    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: pixel.space8,
        vertical: pixel.space4,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: pixel.borderWidth),
      ),
      child: Text(
        '$marker $label',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
    if (age == null && source == null) return badge;
    return Tooltip(message: [?age, ?source].join(' · '), child: badge);
  }
}

class PixelBudgetMeter extends StatelessWidget {
  const PixelBudgetMeter({
    required this.fraction,
    required this.label,
    super.key,
  });

  final double? fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    final value = fraction;
    final activeSegments = value == null ? 0 : (value.clamp(0, 1) * 10).ceil();
    final color = value == null
        ? pixel.mutedText
        : value > 1
        ? pixel.danger
        : value >= 0.8
        ? pixel.warning
        : pixel.accent;
    return Semantics(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var index = 0; index < 10; index++) ...[
                Expanded(
                  child: Container(
                    height: pixel.space8,
                    color: index < activeSegments
                        ? color
                        : pixel.line.withValues(alpha: 0.45),
                  ),
                ),
                if (index != 9) SizedBox(width: pixel.space4),
              ],
            ],
          ),
          SizedBox(height: pixel.space4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class PixelPlacePopupCard extends StatelessWidget {
  const PixelPlacePopupCard({
    required this.title,
    required this.category,
    required this.onClose,
    required this.child,
    super.key,
  });

  final String title;
  final String category;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return PixelPanel(
      color: pixel.accent,
      borderColor: pixel.onAccent,
      padding: EdgeInsets.all(pixel.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: pixel.onAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: pixel.space4),
                    Text(
                      category,
                      style: TextStyle(
                        color: pixel.onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Закрыть карточку',
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: pixel.onAccent,
                  foregroundColor: pixel.accent,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          SizedBox(height: pixel.space8),
          child,
        ],
      ),
    );
  }
}

class PixelStateMessage extends StatelessWidget {
  const PixelStateMessage({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(pixel.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: pixel.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel case final label? when onAction != null) ...[
              SizedBox(height: pixel.space16),
              FilledButton(onPressed: onAction, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}

class PixelEveningBar extends StatelessWidget {
  const PixelEveningBar({
    required this.stopCount,
    required this.onOpen,
    super.key,
  });

  final int stopCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Material(
      color: pixel.raisedSurface,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: pixel.space16,
            vertical: pixel.space8,
          ),
          child: Row(
            children: [
              Icon(Icons.route_outlined, color: pixel.accent),
              SizedBox(width: pixel.space8),
              Expanded(
                child: Text(
                  'ВЕЧЕР · $stopCount ${stopCount == 1 ? "место" : "мест"}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: pixel.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Открыть',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: pixel.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: pixel.space4),
              Icon(Icons.chevron_right, color: pixel.accent),
            ],
          ),
        ),
      ),
    );
  }
}
