import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/main.dart';

Future<NotesProvider> openNotes(WidgetTester tester, List<String> texts) async {
  await tester.pumpWidget(const MainApp());
  final provider = tester.element(find.byType(NotesPage)).read<NotesProvider>();
  for (final text in texts.reversed) {
    provider.addNote(text);
  }
  await tester.pump();
  return provider;
}

Finder cardFor(Note note) => find.byKey(ObjectKey(note)).last;

Future<void> doubleTap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Можно добавить заметку и открыть полный текст нажатием', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());
    final text = List.generate(20, (i) => 'Строка ${i + 1}').join('\n');
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(text));
    // onTap ожидает завершения интервала распознавания двойного нажатия.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byType(ViewNotePage), findsOneWidget);
    expect(find.byType(EditNotePage), findsNothing);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      text,
    );
    expect(find.byType(TextField), findsNothing);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Двойное нажатие отмечает важность без открытия заметки', (
    tester,
  ) async {
    final provider = await openNotes(tester, ['Важная мысль']);
    final note = provider.notes.single;

    await doubleTap(tester, find.text(note.text));

    expect(note.isImportant, isTrue);
    expect(find.byIcon(Icons.star), findsOneWidget);
    final card = tester.widget<Card>(find.byType(Card).last);
    final scheme = Theme.of(tester.element(find.byType(NoteCard))).colorScheme;
    expect(card.color, scheme.primaryContainer);
    expect(find.byType(ViewNotePage), findsNothing);
    expect(find.byType(EditNotePage), findsNothing);

    await doubleTap(tester, find.text(note.text));
    expect(note.isImportant, isTrue);
  });

  testWidgets('Удержание редактирует выбранную заметку и сохраняет текст', (
    tester,
  ) async {
    final provider = await openNotes(tester, ['Первая', 'Редактируемая']);
    final note = provider.notes.last;
    provider.setImportant(note, true);
    await tester.pump();

    await tester.longPress(find.text(note.text));
    await tester.pumpAndSettle();
    expect(find.byType(EditNotePage), findsOneWidget);
    expect(find.byType(ViewNotePage), findsNothing);

    await tester.enterText(find.byType(TextField), 'Обновлённый текст');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(note.text, 'Обновлённый текст');
    expect(note.isImportant, isTrue);
    expect(provider.notes.first, same(note));
    expect(provider.notes.last.text, 'Первая');
    expect(find.text('Обновлённый текст'), findsOneWidget);
    expect(find.byType(EditNotePage), findsNothing);
  });

  testWidgets(
    'Свайп влево удаляет только выбранную заметку, отмена возвращает',
    (tester) async {
      final provider = await openNotes(tester, ['Одинаковая', 'Одинаковая']);
      final note = provider.notes.first;
      final other = provider.notes.last;
      provider.setImportant(note, true);
      await tester.pump();

      await tester.drag(cardFor(note), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(provider.notes, [other]);
      expect(find.byType(ViewNotePage), findsNothing);
      expect(find.byType(EditNotePage), findsNothing);
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect(provider.notes, [note, other]);
      expect(note.isImportant, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Свайп вправо снимает важность и оставляет заметку в списке', (
    tester,
  ) async {
    final provider = await openNotes(tester, ['Важная', 'Обычная']);
    final note = provider.notes.first;
    provider.setImportant(note, true);
    await tester.pump();

    await tester.drag(cardFor(note), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(note.isImportant, isFalse);
    expect(provider.notes.length, 2);
    expect(provider.notes.first, same(note));
    expect(find.byIcon(Icons.star), findsNothing);
    expect(tester.widget<Card>(find.byType(Card).at(1)).color, isNull);
    expect(find.byType(ViewNotePage), findsNothing);
    expect(find.byType(EditNotePage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Свайп вправо по обычной заметке не удаляет её', (tester) async {
    final provider = await openNotes(tester, ['Обычная']);
    final note = provider.notes.single;

    await tester.drag(cardFor(note), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(provider.notes.single, same(note));
    expect(note.isImportant, isFalse);
    expect(find.text(note.text), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Короткое движение не удаляет заметку и не снимает важность', (
    tester,
  ) async {
    final provider = await openNotes(tester, ['Заметка']);
    final note = provider.notes.single;
    provider.setImportant(note, true);
    await tester.pump();

    for (final dx in [-60.0, 60.0]) {
      await tester.timedDrag(
        cardFor(note),
        Offset(dx, 0),
        const Duration(milliseconds: 800),
      );
      await tester.pumpAndSettle();
      expect(provider.notes.single, same(note));
      expect(note.isImportant, isTrue);
    }
    expect(find.byType(ViewNotePage), findsNothing);
  });

  testWidgets('Вертикальная прокрутка не запускает действия карточки', (
    tester,
  ) async {
    final provider = await openNotes(
      tester,
      List.generate(20, (i) => 'Заметка $i'),
    );
    final note = provider.notes.first;
    provider.setImportant(note, true);
    await tester.pump();

    await tester.drag(cardFor(note), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(provider.notes.length, 20);
    expect(note.isImportant, isTrue);
    expect(find.byType(ViewNotePage), findsNothing);
    expect(find.byType(EditNotePage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
