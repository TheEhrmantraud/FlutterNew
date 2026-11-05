import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFFBBC04);
    return ChangeNotifierProvider(
      create: (_) => NotesProvider(),
      child: MaterialApp(
        title: 'Заметки',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ),
        ),
        home: const NotesPage(),
      ),
    );
  }
}

class Note {
  Note(this.text) : updatedAt = DateTime.now();

  String text;
  DateTime updatedAt;
  bool isImportant = false;
}

class NotesProvider extends ChangeNotifier {
  final List<Note> _notes = [];

  List<Note> get notes => List.unmodifiable(_notes);

  void addNote(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _notes.insert(0, Note(trimmed));
    notifyListeners();
  }

  void deleteNote(Note note) {
    final index = _notes.indexOf(note);
    if (index == -1) return;
    _notes.removeAt(index);
    notifyListeners();
  }

  void restoreNote(Note note, int index) {
    _notes.insert(index.clamp(0, _notes.length), note);
    notifyListeners();
  }

  void updateNote(Note note, String newText) {
    final trimmed = newText.trim();
    if (trimmed.isEmpty || trimmed == note.text) return;
    note
      ..text = trimmed
      ..updatedAt = DateTime.now();
    _notes
      ..remove(note)
      ..insert(0, note);
    notifyListeners();
  }

  void setImportant(Note note, bool isImportant) {
    if (!_notes.contains(note) || note.isImportant == isImportant) return;
    note.isImportant = isImportant;
    notifyListeners();
  }
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveNote() {
    context.read<NotesProvider>().addNote(_controller.text);
    _controller.clear();
    _focusNode.unfocus();
  }

  void _deleteNote(Note note) {
    final provider = context.read<NotesProvider>();
    final index = provider.notes.indexOf(note);
    if (index == -1) return;

    provider.deleteNote(note);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Заметка удалена'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () => provider.restoreNote(note, index),
        ),
      ),
    );
  }

  Future<void> _editNote(Note note) async {
    final result = await Navigator.of(context).push<_EditResult>(
      MaterialPageRoute(builder: (_) => EditNotePage(note: note)),
    );
    if (result == null || !mounted) return;

    final provider = context.read<NotesProvider>();
    if (result.delete) {
      _deleteNote(note);
    } else if (result.text != null && result.text != note.text) {
      provider.updateNote(note, result.text!);
    }
  }

  void _viewNote(Note note) {
    _focusNode.unfocus();
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => ViewNotePage(note: note)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notes = context.watch<NotesProvider>().notes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
        centerTitle: false,
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(Icons.lightbulb_outline),
        ),
      ),
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            _buildInput(scheme),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Нажатие — просмотр · Двойное — важная\n'
                'Удержание — редактирование\n'
                '← Удалить · Снять важность →',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: notes.isEmpty ? _buildEmpty(scheme) : _buildList(notes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(ColorScheme scheme) {
    final canSave = _controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Заметка...',
                  border: InputBorder.none,
                ),
              ),
              FilledButton.icon(
                onPressed: canSave ? _saveNote : null,
                icon: const Icon(Icons.check),
                label: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, size: 96, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Здесь будут ваши заметки',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Note> notes) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: notes.length,
      itemBuilder: (context, i) {
        final note = notes[i];
        return Padding(
          key: ObjectKey(note),
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: ObjectKey(note),
            direction: DismissDirection.horizontal,
            // Свайп вправо меняет статус и возвращает карточку на место.
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                context.read<NotesProvider>().setImportant(note, false);
                return false;
              }
              return true;
            },
            onDismissed: (_) => _deleteNote(note),
            background: _dismissBackground(isDelete: false),
            secondaryBackground: _dismissBackground(isDelete: true),
            child: NoteCard(
              note: note,
              onTap: () => _viewNote(note),
              onDoubleTap: () =>
                  context.read<NotesProvider>().setImportant(note, true),
              onLongPress: () => _editNote(note),
              onDelete: () => _deleteNote(note),
            ),
          ),
        );
      },
    );
  }

  Widget _dismissBackground({required bool isDelete}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: isDelete ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDelete ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isDelete ? Icons.delete_outline : Icons.star_border,
        color: isDelete ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        semanticLabel: isDelete ? 'Удалить' : 'Снять важность',
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card.outlined(
      color: note.isImportant ? scheme.primaryContainer : null,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.isImportant)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.star, color: scheme.onPrimaryContainer),
                            const SizedBox(width: 6),
                            Text(
                              'Важная',
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      note.text,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(note.updatedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Удалить',
                icon: const Icon(Icons.delete_outline),
                color: scheme.onSurfaceVariant,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ViewNotePage extends StatelessWidget {
  const ViewNotePage({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Просмотр заметки')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.isImportant) ...[
              const Row(
                children: [
                  Icon(Icons.star),
                  SizedBox(width: 6),
                  Text('Важная заметка'),
                ],
              ),
              const SizedBox(height: 16),
            ],
            SelectableText(note.text, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            Text(_formatDate(note.updatedAt), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _EditResult {
  const _EditResult.text(this.text) : delete = false;
  const _EditResult.delete() : text = null, delete = true;

  final String? text;
  final bool delete;
}

class EditNotePage extends StatefulWidget {
  const EditNotePage({super.key, required this.note});

  final Note note;

  @override
  State<EditNotePage> createState() => _EditNotePageState();
}

class _EditNotePageState extends State<EditNotePage> {
  late final _controller = TextEditingController(text: widget.note.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    Navigator.of(
      context,
    ).pop(text.isEmpty ? const _EditResult.delete() : _EditResult.text(text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Редактирование заметки'),
          leading: IconButton(
            tooltip: 'Назад',
            icon: const Icon(Icons.arrow_back),
            onPressed: _save,
          ),
          actions: [
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  Navigator.of(context).pop(const _EditResult.delete()),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Заметка',
              border: InputBorder.none,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Text('Сохранить'),
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Изменено ${two(d.day)}.${two(d.month)}.${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}
