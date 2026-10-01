import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFFBBC04);
    return MaterialApp(
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
    );
  }
}

class Note {
  Note(this.text) : updatedAt = DateTime.now();

  String text;
  DateTime updatedAt;
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final List<Note> _notes = [];

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
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _notes.insert(0, Note(text)));
    _controller.clear();
    _focusNode.unfocus();
  }

  void _deleteNote(Note note) {
    final index = _notes.indexOf(note);
    if (index == -1) return;
    setState(() => _notes.removeAt(index));

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Заметка удалена'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () => setState(
            () => _notes.insert(index.clamp(0, _notes.length), note),
          ),
        ),
      ),
    );
  }

  Future<void> _editNote(Note note) async {
    final result = await Navigator.of(context).push<_EditResult>(
      MaterialPageRoute(builder: (_) => EditNotePage(note: note)),
    );
    if (result == null) return;

    if (result.delete) {
      _deleteNote(note);
    } else if (result.text != null && result.text != note.text) {
      setState(() {
        note
          ..text = result.text!
          ..updatedAt = DateTime.now();
        _notes
          ..remove(note)
          ..insert(0, note);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
            Expanded(
              child: _notes.isEmpty ? _buildEmpty(scheme) : _buildList(),
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

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _notes.length,
      itemBuilder: (context, i) {
        final note = _notes[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: ObjectKey(note),
            onDismissed: (_) => _deleteNote(note),
            background: _dismissBackground(Alignment.centerLeft),
            secondaryBackground: _dismissBackground(Alignment.centerRight),
            child: NoteCard(
              note: note,
              onTap: () => _editNote(note),
              onDelete: () => _deleteNote(note),
            ),
          ),
        );
      },
    );
  }

  Widget _dismissBackground(Alignment alignment) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.text,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(note.updatedAt),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
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

class _EditResult {
  const _EditResult.text(this.text) : delete = false;
  const _EditResult.delete()
      : text = null,
        delete = true;

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
    Navigator.of(context).pop(
      text.isEmpty ? const _EditResult.delete() : _EditResult.text(text),
    );
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
