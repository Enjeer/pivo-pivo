import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../domain.dart';
import '../local_store.dart';
import '../routing.dart';
import '../ui/pixel_components.dart';
import '../ui/pixel_theme.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _transportController = TextEditingController();
  final _budgetController = TextEditingController();
  final Map<String, TextEditingController> _costControllers = {};
  bool _transportControllerReady = false;
  bool _budgetControllerReady = false;
  DirectionsMode _directionsMode = DirectionsMode.walking;

  @override
  void dispose() {
    _transportController.dispose();
    _budgetController.dispose();
    for (final controller in _costControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _buildPlan(context),
    );
  }

  Widget _buildPlan(BuildContext context) {
    final pixel = context.pixel;
    final data = widget.controller.data;
    if (!_transportControllerReady) {
      _transportController.text = data.transportCostMinor == null
          ? ''
          : _moneyFieldValue(data.transportCostMinor!);
      _transportControllerReady = true;
    }
    if (!_budgetControllerReady) {
      _budgetController.text = data.budgetMinor == null
          ? ''
          : _moneyFieldValue(data.budgetMinor!);
      _budgetControllerReady = true;
    }
    for (final stop in data.stops) {
      _costControllers.putIfAbsent(
        stop.placeId,
        () => TextEditingController(
          text: stop.visitCostMinor == null
              ? ''
              : _moneyFieldValue(stop.visitCostMinor!),
        ),
      );
    }
    final summary = calculateBudget(data);
    final budgetAssessment = assessBudget(data);
    final budgetSuggestion = suggestBudgetAdjustment(data);
    final hasAnyCost =
        data.transportCostMinor != null ||
        data.stops.any((stop) => stop.visitCostMinor != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('План вечера'),
        actions: [
          if (data.stops.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: pixel.space16),
              child: Center(
                child: Text(
                  '${data.stops.length} ${_pluralStops(data.stops.length)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pixel.space16,
            pixel.space8,
            pixel.space16,
            pixel.space32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.stops.isEmpty)
                const _EmptyPlan()
              else ...[
                Text(
                  'Сначала места, потом арифметика.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: pixel.mutedText),
                ),
                SizedBox(height: pixel.space16),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.stops.length,
                  onReorderItem: (oldIndex, newIndex) {
                    performUserAction(
                      context,
                      widget.controller.reorderPlan(oldIndex, newIndex),
                      successMessage: 'Порядок остановок сохранён',
                    );
                  },
                  itemBuilder: (context, index) {
                    final stop = data.stops[index];
                    final place = widget.controller.findPlace(stop.placeId);
                    if (place == null) {
                      return ListTile(
                        key: ValueKey(stop.placeId),
                        title: const Text('Точка больше недоступна'),
                        trailing: IconButton(
                          onPressed: () => performUserAction(
                            context,
                            widget.controller.removeStop(stop.placeId),
                          ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      );
                    }
                    return _StopEditor(
                      key: ValueKey(stop.placeId),
                      stop: stop,
                      place: place,
                      index: index,
                      costController: _costControllers[stop.placeId]!,
                      onSaveCost: (value) =>
                          _saveVisitCost(stop.placeId, value),
                      onRemove: () => performUserAction(
                        context,
                        widget.controller.removeStop(stop.placeId),
                        successMessage: 'Убрано из плана',
                      ),
                    );
                  },
                ),
                SizedBox(height: pixel.space24),
                _RouteActions(
                  mode: _directionsMode,
                  onModeChanged: (mode) {
                    if (mode == _directionsMode) return;
                    setState(() => _directionsMode = mode);
                    widget.controller.clearRoute();
                  },
                  routeStatus: widget.controller.routeStatus,
                  routeEstimate: widget.controller.routeEstimate,
                  routeError: widget.controller.routeError,
                  findPlace: widget.controller.findPlace,
                  onCalculateRoute: () =>
                      widget.controller.calculateRoute(_directionsMode),
                  onOpenDirections: _openDirections,
                ),
                SizedBox(height: pixel.space24),
              ],
              _SectionTitle(title: 'ДЕНЬГИ', trailing: 'BYN'),
              SizedBox(height: pixel.space8),
              _CostInputCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Бюджет на весь вечер',
                subtitle: 'Лимит для всех участников',
                controller: _budgetController,
                onSave: _saveBudget,
              ),
              SizedBox(height: pixel.space12),
              _CostInputCard(
                icon: Icons.directions_walk_outlined,
                title: 'Проезд между остановками',
                subtitle: 'Ваша оценка, не тариф перевозчика',
                controller: _transportController,
                onSave: _saveTransportCost,
              ),
              SizedBox(height: pixel.space12),
              _ParticipantsControl(
                participants: data.participants,
                onChanged: (value) => performUserAction(
                  context,
                  widget.controller.updateParticipants(value),
                  successMessage: 'Число участников обновлено',
                ),
              ),
              SizedBox(height: pixel.space12),
              _BudgetCard(
                summary: summary,
                assessment: budgetAssessment,
                suggestion: budgetSuggestion,
                hasAnyCost: hasAnyCost,
                transportCostKnown: data.transportCostMinor != null,
                hasStops: data.stops.isNotEmpty,
                onApplySuggestion: budgetSuggestion == null
                    ? null
                    : () => performUserAction(
                        context,
                        widget.controller.removeStops(
                          budgetSuggestion.placeIdsToRemove,
                        ),
                        successMessage: 'Указанные остановки удалены из плана',
                      ),
              ),
              SizedBox(height: pixel.space12),
              Text(
                'Суммы вводите сами. Без оценки заведения не включаются '
                'в итог; он не является гарантией бюджета.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveVisitCost(String placeId, String value) async {
    try {
      final cost = parseMoneyMinor(value);
      await performUserAction(
        context,
        widget.controller.updateVisitCost(placeId, cost),
        successMessage: 'Оценка места сохранена',
      );
    } on FormatException catch (error) {
      _showInputError(error.message);
    }
  }

  Future<void> _saveTransportCost(String value) async {
    try {
      final cost = parseMoneyMinor(value);
      await performUserAction(
        context,
        widget.controller.updateTransportCost(cost),
        successMessage: 'Оценка проезда сохранена',
      );
    } on FormatException catch (error) {
      _showInputError(error.message);
    }
  }

  Future<void> _saveBudget(String value) async {
    try {
      final budget = parseMoneyMinor(value);
      await performUserAction(
        context,
        widget.controller.updateBudget(budget),
        successMessage: budget == null
            ? 'Лимит бюджета убран'
            : 'Лимит бюджета сохранён',
      );
    } on FormatException catch (error) {
      _showInputError(error.message);
    }
  }

  Future<void> _openDirections() async {
    try {
      final stops = widget.controller.data.stops
          .map((stop) {
            final place = widget.controller.findPlace(stop.placeId);
            if (place == null) {
              throw StateError(
                'Остановка ${stop.placeId} отсутствует в текущем каталоге.',
              );
            }
            return place;
          })
          .toList(growable: false);
      final uri = buildGoogleMapsDirectionsUri(stops, _directionsMode);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw StateError('Не удалось открыть приложение Google Maps.');
      }
    } on DirectionsLinkException catch (error) {
      _showInputError(
        'Не удалось открыть маршрут: ${error.message} '
        'Порядок остановок в плане не изменён.',
      );
    } on Exception catch (error) {
      _showInputError(
        'Не удалось открыть маршрут: $error. '
        'Порядок остановок в плане не изменён.',
      );
    }
  }

  void _showInputError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RouteActions extends StatelessWidget {
  const _RouteActions({
    required this.mode,
    required this.onModeChanged,
    required this.routeStatus,
    required this.routeEstimate,
    required this.routeError,
    required this.findPlace,
    required this.onCalculateRoute,
    required this.onOpenDirections,
  });

  final DirectionsMode mode;
  final ValueChanged<DirectionsMode> onModeChanged;
  final RouteLoadStatus routeStatus;
  final RouteEstimate? routeEstimate;
  final Object? routeError;
  final Place? Function(String placeId) findPlace;
  final VoidCallback onCalculateRoute;
  final VoidCallback onOpenDirections;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return PixelPanel(
      color: pixel.raisedSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'МАРШРУТ В ПОРЯДКЕ ОСТАНОВОК',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: pixel.accent, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: pixel.space8),
          Wrap(
            spacing: pixel.space8,
            runSpacing: pixel.space8,
            children: [
              for (final option in DirectionsMode.values)
                PixelFilterChip(
                  label: option.label,
                  selected: mode == option,
                  onSelected: (_) => onModeChanged(option),
                ),
            ],
          ),
          SizedBox(height: pixel.space8),
          Text(
            'Пешком и на автомобиле — маршрут OSM по дорожной сети. '
            'Это оценка без данных о текущем трафике. Запрос координат '
            'остановок отправляется FOSSGIS и может попасть в серверные логи.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: pixel.space8),
          if (mode == DirectionsMode.transit)
            Text(
              'Внутренний маршрут общественного транспорта не поддерживается. '
              'Используйте внешнюю навигацию.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: pixel.mutedText),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: routeStatus == RouteLoadStatus.loading
                    ? null
                    : onCalculateRoute,
                icon: routeStatus == RouteLoadStatus.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.route_outlined),
                label: Text(
                  routeStatus == RouteLoadStatus.ready
                      ? 'Пересчитать маршрут'
                      : 'Построить маршрут на карте',
                ),
              ),
            ),
          if (routeStatus == RouteLoadStatus.error ||
              routeStatus == RouteLoadStatus.unsupported) ...[
            SizedBox(height: pixel.space8),
            Text(
              routeError?.toString() ?? 'Маршрут недоступен.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: pixel.danger),
            ),
          ],
          if (routeEstimate case final estimate?) ...[
            SizedBox(height: pixel.space12),
            PixelPanel(
              color: pixel.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'МАРШРУТ · ${estimate.source}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: pixel.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: pixel.space4),
                  Text(
                    '${_formatDistance(estimate.totalDistanceMeters)} · '
                    '${_formatDuration(estimate.totalDurationSeconds)} суммарно',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final leg in estimate.legs) ...[
                    SizedBox(height: pixel.space8),
                    Text(
                      '${findPlace(leg.fromPlaceId)?.name ?? 'Место'} → '
                      '${findPlace(leg.toPlaceId)?.name ?? 'Место'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${_formatDistance(leg.distanceMeters)} · '
                      '${_formatDuration(leg.durationSeconds)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  SizedBox(height: pixel.space8),
                  Text(
                    'Расчёт обновлён ${_formatLocalDateTime(estimate.observedAt)}. '
                    'Время пути — оценка маршрутизатора, не гарантия.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(height: pixel.space8),
                  Text(
                    'Линия появится на вкладке «Карта».',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: pixel.space8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenDirections,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Открыть в Google Maps'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDistance(double meters) => meters < 1000
    ? '${meters.round()} м'
    : '${(meters / 1000).toStringAsFixed(1)} км';

String _formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  return minutes < 1 ? '${seconds.round()} с' : '$minutes мин';
}

String _formatLocalDateTime(DateTime time) {
  final local = time.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(pixel.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 44, color: pixel.accent),
            SizedBox(height: pixel.space16),
            Text(
              'Пока без остановок',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: pixel.space8),
            Text(
              'Выберите место на карте и добавьте его в план. '
              'Порядок потом можно поменять.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _StopEditor extends StatelessWidget {
  const _StopEditor({
    required super.key,
    required this.stop,
    required this.place,
    required this.index,
    required this.costController,
    required this.onSaveCost,
    required this.onRemove,
  });

  final PlanStop stop;
  final Place place;
  final int index;
  final TextEditingController costController;
  final ValueChanged<String> onSaveCost;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Card(
      key: key,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          pixel.space12,
          pixel.space12,
          pixel.space8,
          pixel.space12,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: pixel.accent),
                  child: Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: pixel.onAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: pixel.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${place.category} · '
                        '${place.isDemo ? 'демо-точка' : 'OpenStreetMap'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Убрать остановку',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: EdgeInsets.all(pixel.space8),
                    child: Icon(Icons.drag_handle, color: pixel.mutedText),
                  ),
                ),
              ],
            ),
            SizedBox(height: pixel.space8),
            TextField(
              controller: costController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: onSaveCost,
              decoration: InputDecoration(
                labelText: 'Ваша оценка посещения, BYN',
                hintText: 'Например, 30',
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: 'Сохранить оценку',
                  onPressed: () => onSaveCost(costController.text),
                  icon: Icon(Icons.check, color: pixel.accent),
                ),
              ),
            ),
            if (stop.visitCostMinor != null) ...[
              SizedBox(height: pixel.space4),
              Text(
                'Ваша оценка · не подтверждена заведением'
                '${stop.visitCostObservedAt == null ? '' : ' · ${_formatLocalDateTime(stop.visitCostObservedAt!)}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CostInputCard extends StatelessWidget {
  const _CostInputCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.onSave,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final ValueChanged<String> onSave;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(pixel.space12),
        child: Row(
          children: [
            Icon(icon, color: pixel.accent),
            SizedBox(width: pixel.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: pixel.space4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  SizedBox(height: pixel.space8),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: onSave,
                    decoration: InputDecoration(
                      labelText: 'Оценка в BYN',
                      hintText: 'Пока нет данных',
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: 'Сохранить оценку проезда',
                        onPressed: () => onSave(controller.text),
                        icon: Icon(Icons.check, color: pixel.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantsControl extends StatelessWidget {
  const _ParticipantsControl({
    required this.participants,
    required this.onChanged,
  });

  final int participants;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: pixel.space12,
          vertical: pixel.space8,
        ),
        child: Row(
          children: [
            Icon(Icons.group_outlined, color: pixel.accent),
            SizedBox(width: pixel.space8),
            Expanded(
              child: Text(
                'Участники',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Уменьшить число участников',
              onPressed: participants > 1
                  ? () => onChanged(participants - 1)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$participants',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              tooltip: 'Увеличить число участников',
              onPressed: participants < 99
                  ? () => onChanged(participants + 1)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.summary,
    required this.assessment,
    required this.suggestion,
    required this.hasAnyCost,
    required this.transportCostKnown,
    required this.hasStops,
    required this.onApplySuggestion,
  });

  final BudgetSummary summary;
  final BudgetAssessment assessment;
  final BudgetSuggestion? suggestion;
  final bool hasAnyCost;
  final bool transportCostKnown;
  final bool hasStops;
  final VoidCallback? onApplySuggestion;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    final incomplete = assessment.missingCosts > 0;
    final budget = assessment.budgetMinor;
    final remaining = assessment.remainingMinor;
    final statusLabel = switch (assessment.status) {
      BudgetStatus.notSet => 'ЛИМИТ НЕ ЗАДАН',
      BudgetStatus.incomplete => 'ЧАСТИЧНАЯ ОЦЕНКА',
      BudgetStatus.withinBudget => 'В ПРЕДЕЛАХ БЮДЖЕТА',
      BudgetStatus.overBudget => 'ПРЕВЫШЕНИЕ ЛИМИТА',
    };
    return PixelPanel(
      color: pixel.raisedSurface,
      padding: EdgeInsets.all(pixel.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: pixel.accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: pixel.space8),
          Text(
            hasAnyCost
                ? formatMoneyMinor(summary.knownSubtotalMinor)
                : 'Добавьте оценки',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (hasAnyCost) ...[
            SizedBox(height: pixel.space4),
            Text(
              '${formatMoneyMinor(summary.perPersonMinor)} на участника'
              '${incomplete ? ' · по введённым суммам' : ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: pixel.space8),
            const ProvenanceBadge(kind: ProvenanceKind.estimate),
          ],
          if (budget != null) ...[
            SizedBox(height: pixel.space12),
            PixelBudgetMeter(
              fraction: budget == 0
                  ? (summary.knownSubtotalMinor == 0 ? 0 : 1)
                  : summary.knownSubtotalMinor / budget,
              label:
                  '${formatMoneyMinor(summary.knownSubtotalMinor)} из '
                  '${formatMoneyMinor(budget)}',
            ),
            SizedBox(height: pixel.space8),
            if (assessment.status == BudgetStatus.withinBudget)
              Text(
                'Остаток: ${formatMoneyMinor(remaining!)}',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else if (assessment.status == BudgetStatus.overBudget)
              Text(
                'Известная часть выше лимита на '
                '${formatMoneyMinor(-remaining!)}'
                '${incomplete ? '. Полная сумма может быть выше' : ''}.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: pixel.danger),
              )
            else if (incomplete)
              Text(
                'Не хватает данных по ${assessment.missingCosts} '
                '${_pluralCosts(assessment.missingCosts)}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ] else
            Text(
              'Задайте лимит, чтобы видеть остаток и проверять план.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (suggestion != null) ...[
            SizedBox(height: pixel.space12),
            Text(
              'Можно убрать ${suggestion!.placeIdsToRemove.length} '
              '${_pluralPlaces(suggestion!.placeIdsToRemove.length)}: '
              'известная сумма станет '
              '${formatMoneyMinor(suggestion!.remainingMinor)}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: pixel.space8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onApplySuggestion,
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Применить вариант'),
              ),
            ),
          ],
          if (summary.missingVisitCosts > 0) ...[
            SizedBox(height: pixel.space8),
            Text(
              'Без оценки: ${summary.missingVisitCosts} '
              '${_pluralPlaces(summary.missingVisitCosts)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (!transportCostKnown && hasStops) ...[
            SizedBox(height: pixel.space4),
            Text(
              'Проезд не включён — данных нет',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          SizedBox(height: pixel.space12),
          if (budget == null)
            const PixelBudgetMeter(
              fraction: null,
              label: 'Лимит бюджета не задан',
            ),
        ],
      ),
    );
  }
}

String _pluralCosts(int count) {
  return count == 1 ? 'позиции' : 'позициям';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: pixel.mutedText,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(trailing!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _moneyFieldValue(int amountMinor) {
  final whole = amountMinor ~/ 100;
  final fraction = (amountMinor % 100).abs();
  return fraction == 0
      ? '$whole'
      : '$whole.${fraction.toString().padLeft(2, '0')}';
}

String _pluralStops(int count) {
  if (count % 10 == 1 && count % 100 != 11) return 'точка';
  if (count % 10 >= 2 &&
      count % 10 <= 4 &&
      (count % 100 < 12 || count % 100 > 14)) {
    return 'точки';
  }
  return 'точек';
}

String _pluralPlaces(int count) => count == 1 ? 'место' : 'мест';
