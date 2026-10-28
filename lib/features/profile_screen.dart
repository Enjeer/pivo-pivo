import 'package:flutter/material.dart';

import '../local_store.dart';
import '../ui/pixel_components.dart';
import '../ui/pixel_theme.dart';
import 'plan_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pixel = context.pixel;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            tooltip: 'Открыть план вечера',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlanScreen(controller: controller),
              ),
            ),
            icon: const Icon(Icons.route_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.all(pixel.space16),
          children: [
            PixelPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.face_outlined, color: pixel.accent, size: 32),
                  SizedBox(height: pixel.space12),
                  Text(
                    'Пока без аккаунта',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: pixel.space8),
                  Text(
                    'Избранное, план и личные заметки хранятся на этом '
                    'устройстве. Синхронизации с сервером нет.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            SizedBox(height: pixel.space12),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => PixelPanel(
                color: pixel.raisedSurface,
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: pixel.accent),
                    SizedBox(width: pixel.space8),
                    Expanded(
                      child: Text(
                        'Личных заметок: ${controller.data.noteByPlace.length}. '
                        'Они не отправляются в каталог или внешние сервисы.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: pixel.space12),
            PixelPanel(
              child: Text(
                'Цены, адреса и часы работы для демо-точек не заданы. '
                'Мы не выдаём тестовые данные за реальные.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
