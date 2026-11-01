import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/advice_controller.dart';
import '../models/advice.dart';

class AdviceHome extends StatefulWidget {
  const AdviceHome({super.key, required this.controller});
  final AdviceController controller;

  @override
  State<AdviceHome> createState() => _AdviceHomeState();
}

class _AdviceHomeState extends State<AdviceHome> {
  final _search = TextEditingController();
  int _tab = 0;
  bool _newestFirst = true;
  AdviceController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (!controller.initialized) unawaited(controller.initialize());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      _search.clear();
      _newestFirst = true;
    });
  }

  Future<void> _copy(Advice advice) async {
    try {
      await Clipboard.setData(ClipboardData(text: advice.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Совет скопирован')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось скопировать совет')),
      );
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Избранные советы останутся в твоей коллекции'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Оставить'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearHistory();
  }

  void _openAdvice(Advice advice) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Мысль для тебя',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              SelectableText(
                advice.text,
                style: const TextStyle(fontSize: 26, height: 1.3),
              ),
              const SizedBox(height: 20),
              Text('API Ninjas · ${formatDate(advice.receivedAt)}'),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => controller.toggleFavorite(advice),
                    icon: Icon(
                      controller.isFavorite(advice)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                    label: Text(
                      controller.isFavorite(advice)
                          ? 'В избранном'
                          : 'Сохранить',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _copy(advice),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Копировать'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          titleSpacing: 24,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: colors.primary),
              const SizedBox(width: 10),
              const Text(
                'кстати',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          actions: [
            IconButton.filledTonal(
              tooltip: controller.darkMode ? 'Светлая тема' : 'Тёмная тема',
              onPressed: controller.initialized ? controller.toggleTheme : null,
              icon: Icon(
                controller.darkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_outlined,
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: !controller.initialized
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        if (controller.storageError != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: _Message(
                              text: controller.storageError!,
                              icon: Icons.save_outlined,
                            ),
                          ),
                        Expanded(
                          child: _tab == 0
                              ? _buildDiscover()
                              : _buildCollection(),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: 'Для тебя',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Избранное',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              label: 'История',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscover() {
    final colors = Theme.of(context).colorScheme;
    final advice = controller.current;
    final recent = controller.history
        .where((item) => item.text != advice?.text)
        .take(2);
    return RefreshIndicator(
      onRefresh: controller.fetch,
      child: ListView(
        key: const PageStorageKey('discover'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            'Маленький совет\nБольшой смысл',
            style: TextStyle(
              fontSize: 36,
              height: 1.08,
              letterSpacing: -1.5,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Новая мысль, чтобы посмотреть на день иначе',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(36),
                topRight: Radius.circular(36),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 42,
                      color: colors.onPrimaryContainer,
                    ),
                    _Pill(
                      text: controller.loading
                          ? 'Ищем вдохновение'
                          : controller.fromStorage
                          ? 'Из твоей истории'
                          : advice != null
                          ? 'Мысль на сейчас'
                          : 'Место для новой мысли',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  alignment: Alignment.topLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: advice != null
                        ? Align(
                            key: ValueKey(advice.text),
                            alignment: Alignment.centerLeft,
                            child: SelectableText(
                              advice.text,
                              style: TextStyle(
                                fontSize: advice.text.length > 180 ? 25 : 30,
                                height: 1.22,
                                letterSpacing: -0.6,
                                fontWeight: FontWeight.w600,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          )
                        : Padding(
                            key: ValueKey(controller.loading),
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: Text(
                              controller.loading
                                  ? 'Хорошая мысль\nуже в пути'
                                  : 'Вдохновение\nчуть задержалось',
                              style: TextStyle(
                                fontSize: 30,
                                height: 1.2,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                if (controller.loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                if (advice != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'API Ninjas · EN',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Копировать совет',
                        onPressed: () => _copy(advice),
                        icon: const Icon(Icons.copy_rounded, size: 20),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        tooltip: controller.isFavorite(advice)
                            ? 'Убрать из избранного'
                            : 'Добавить в избранное',
                        isSelected: controller.isFavorite(advice),
                        onPressed: () => controller.toggleFavorite(advice),
                        icon: const Icon(
                          Icons.favorite_border_rounded,
                          size: 21,
                        ),
                        selectedIcon: const Icon(
                          Icons.favorite_rounded,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (controller.error != null) ...[
            _Message(text: controller.error!, icon: Icons.wifi_off_rounded),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: controller.loading ? null : controller.fetch,
            icon: Icon(
              controller.error != null
                  ? Icons.refresh_rounded
                  : Icons.shuffle_rounded,
            ),
            label: Text(
              controller.loading
                  ? 'Ловим новую мысль'
                  : controller.error != null
                  ? 'Попробовать ещё'
                  : 'Ещё немного вдохновения',
            ),
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CollectionTile(
                  count: controller.favorites.length,
                  title: 'Близко к сердцу',
                  icon: Icons.favorite_rounded,
                  background: colors.tertiaryContainer,
                  foreground: colors.onTertiaryContainer,
                  onTap: () => _selectTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CollectionTile(
                  count: controller.history.length,
                  title: 'В твоей истории',
                  icon: Icons.history_rounded,
                  background: colors.secondaryContainer,
                  foreground: colors.onSecondaryContainer,
                  onTap: () => _selectTab(2),
                ),
              ),
            ],
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Недавние мысли',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final item in recent) ...[
              _adviceTile(item),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCollection() {
    final colors = Theme.of(context).colorScheme;
    final favorites = _tab == 1;
    final source = favorites ? controller.favorites : controller.history;
    final query = _search.text.trim().toLowerCase();
    final filtered = source
        .where((item) => item.text.toLowerCase().contains(query))
        .toList();
    if (!_newestFirst) {
      if (favorites) {
        filtered.sort(
          (a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()),
        );
      } else {
        filtered.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
      }
    }
    return ListView(
      key: ValueKey(_tab),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          favorites ? 'Близко\nк сердцу' : 'Твоя история',
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -1.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          favorites
              ? 'Мысли, к которым хочется возвращаться'
              : 'Последние 100 советов, которые ты открыл',
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        SearchBar(
          controller: _search,
          hintText: 'Найти совет в коллекции',
          leading: const Icon(Icons.search_rounded),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16),
          ),
          onChanged: (_) => setState(() {}),
          trailing: [
            if (_search.text.isNotEmpty)
              IconButton(
                tooltip: 'Очистить поиск',
                onPressed: () => setState(_search.clear),
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(text: 'Найдено ${filtered.length}'),
            TextButton.icon(
              onPressed: source.isEmpty
                  ? null
                  : () => setState(() => _newestFirst = !_newestFirst),
              icon: const Icon(Icons.sort_rounded, size: 18),
              label: Text(
                _newestFirst
                    ? 'Сначала новые'
                    : favorites
                    ? 'По алфавиту'
                    : 'Сначала старые',
              ),
            ),
            if (!favorites && source.isNotEmpty)
              IconButton(
                tooltip: 'Очистить историю',
                onPressed: _clearHistory,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              children: [
                Icon(
                  query.isNotEmpty
                      ? Icons.search_off_rounded
                      : favorites
                      ? Icons.favorite_border_rounded
                      : Icons.history_rounded,
                  size: 56,
                  color: colors.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  query.isNotEmpty
                      ? 'Таких мыслей пока нет'
                      : favorites
                      ? 'Сохрани то, что откликается'
                      : 'Всё начинается с одной мысли',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  query.isNotEmpty
                      ? 'Попробуй другое слово на английском'
                      : favorites
                      ? 'Нажми на сердечко рядом с советом, и он появится здесь'
                      : 'Открой совет на главном экране, и он попадёт в историю',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5, color: colors.onSurfaceVariant),
                ),
                if (query.isEmpty) ...[
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: () => _selectTab(0),
                    child: const Text('За вдохновением'),
                  ),
                ],
              ],
            ),
          ),
        for (final advice in filtered) ...[
          _adviceTile(advice),
          const SizedBox(height: 12),
        ],
        if (source.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Сохранено на устройстве, доступно без интернета',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _adviceTile(Advice advice) {
    final colors = Theme.of(context).colorScheme;
    final favorite = controller.isFavorite(advice);
    return Card(
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openAdvice(advice),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                advice.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDate(advice.receivedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Копировать совет',
                    onPressed: () => _copy(advice),
                    icon: const Icon(Icons.copy_rounded, size: 19),
                  ),
                  IconButton(
                    tooltip: favorite
                        ? 'Убрать из избранного'
                        : 'Добавить в избранное',
                    onPressed: () => controller.toggleFavorite(advice),
                    icon: Icon(
                      favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: favorite
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatDate(DateTime value) {
  final date = value.toLocal();
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${pad(date.day)} ${pad(date.month)} ${date.year} · ${pad(date.hour)}:${pad(date.minute)}';
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.onErrorContainer, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.count,
    required this.title,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });
  final int count;
  final String title;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 25),
              const SizedBox(height: 16),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 36,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
