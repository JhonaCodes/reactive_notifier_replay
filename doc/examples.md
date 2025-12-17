# Examples

Practical code examples for ReactiveNotifier Replay.

## Table of Contents

1. [Counter with Undo/Redo](#counter-with-undoredo)
2. [Text Editor with Debounce](#text-editor-with-debounce)
3. [Todo List with Undo Delete](#todo-list-with-undo-delete)
4. [Form with History](#form-with-history)
5. [Reactive Undo Buttons](#reactive-undo-buttons)
6. [History Timeline Visualization](#history-timeline-visualization)
7. [Keyboard Shortcuts](#keyboard-shortcuts)
8. [Game State with History](#game-state-with-history)

---

## Counter with Undo/Redo

Simple counter demonstrating basic undo/redo functionality.

```dart
import 'package:flutter/material.dart';
import 'package:reactive_notifier_replay/reactive_notifier_replay.dart';

// Service
mixin CounterService {
  static final counter = ReplayReactiveNotifier<int>(
    create: () => 0,
    historyLimit: 50,
  );

  static void increment() => counter.updateState(counter.notifier + 1);
  static void decrement() => counter.updateState(counter.notifier - 1);
  static void reset() => counter.updateState(0);
}

// Widget
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Counter with History'),
        actions: [
          IconButton(
            onPressed: CounterService.counter.canUndo
              ? CounterService.counter.undo
              : null,
            icon: Icon(Icons.undo),
            tooltip: 'Undo',
          ),
          IconButton(
            onPressed: CounterService.counter.canRedo
              ? CounterService.counter.redo
              : null,
            icon: Icon(Icons.redo),
            tooltip: 'Redo',
          ),
        ],
      ),
      body: ReactiveBuilder<int>(
        notifier: CounterService.counter,
        build: (value, notifier, keep) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'History: ${CounterService.counter.currentHistoryIndex + 1}/'
                  '${CounterService.counter.historyLength}',
                ),
                SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: 'decrement',
                      onPressed: CounterService.decrement,
                      child: Icon(Icons.remove),
                    ),
                    SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: 'increment',
                      onPressed: CounterService.increment,
                      child: Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

---

## Text Editor with Debounce

Text editor that groups rapid typing into single history entries.

```dart
// State model
class DocumentState {
  final String content;
  final bool isDirty;
  final DateTime? lastModified;

  const DocumentState({
    this.content = '',
    this.isDirty = false,
    this.lastModified,
  });

  DocumentState copyWith({
    String? content,
    bool? isDirty,
    DateTime? lastModified,
  }) {
    return DocumentState(
      content: content ?? this.content,
      isDirty: isDirty ?? this.isDirty,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

// ViewModel
class DocumentViewModel extends ReplayViewModel<DocumentState> {
  DocumentViewModel() : super(
    const DocumentState(),
    historyLimit: 100,
    debounceHistory: Duration(milliseconds: 500), // Group typing
  );

  @override
  void init() {}

  void updateContent(String content) {
    transformState((state) => state.copyWith(
      content: content,
      isDirty: true,
      lastModified: DateTime.now(),
    ));
  }

  Future<void> save() async {
    // Save logic here
    transformState((state) => state.copyWith(isDirty: false));
    clearHistory(); // Fresh start after save
  }
}

// Service
mixin DocumentService {
  static final document = ReactiveNotifier<DocumentViewModel>(
    () => DocumentViewModel(),
  );
}

// Widget
class TextEditorPage extends StatelessWidget {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Text Editor'),
        actions: [
          ReactiveViewModelBuilder<DocumentViewModel, DocumentState>(
            viewmodel: DocumentService.document.notifier,
            build: (state, vm, keep) => Row(
              children: [
                IconButton(
                  onPressed: vm.canUndo ? vm.undo : null,
                  icon: Icon(Icons.undo),
                ),
                IconButton(
                  onPressed: vm.canRedo ? vm.redo : null,
                  icon: Icon(Icons.redo),
                ),
                if (state.isDirty)
                  IconButton(
                    onPressed: vm.save,
                    icon: Icon(Icons.save),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<DocumentViewModel, DocumentState>(
        viewmodel: DocumentService.document.notifier,
        build: (state, viewModel, keep) {
          // Sync controller if text changed externally (undo/redo)
          if (_controller.text != state.content) {
            _controller.text = state.content;
            _controller.selection = TextSelection.collapsed(
              offset: state.content.length,
            );
          }

          return Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: viewModel.updateContent,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: 'Start typing...',
                border: OutlineInputBorder(),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

---

## Todo List with Undo Delete

Async todo list where users can undo deletions.

```dart
// Model
class TodoItem {
  final String id;
  final String title;
  final bool completed;

  TodoItem({
    required this.id,
    required this.title,
    this.completed = false,
  });

  TodoItem copyWith({String? title, bool? completed}) => TodoItem(
    id: id,
    title: title ?? this.title,
    completed: completed ?? this.completed,
  );
}

// ViewModel
class TodoListViewModel extends ReplayAsyncViewModelImpl<List<TodoItem>> {
  TodoListViewModel() : super(
    AsyncState.initial(),
    historyLimit: 30,
  );

  @override
  Future<List<TodoItem>> init() async {
    // Simulate API call
    await Future.delayed(Duration(seconds: 1));
    return [
      TodoItem(id: '1', title: 'Learn Flutter'),
      TodoItem(id: '2', title: 'Build app'),
      TodoItem(id: '3', title: 'Deploy'),
    ];
  }

  void addTodo(String title) {
    transformDataState((items) => [
      ...?items,
      TodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
      ),
    ]);
  }

  void toggleTodo(String id) {
    transformDataState((items) => items?.map((item) {
      if (item.id == id) {
        return item.copyWith(completed: !item.completed);
      }
      return item;
    }).toList());
  }

  void deleteTodo(String id) {
    transformDataState((items) =>
      items?.where((item) => item.id != id).toList()
    );
  }
}

// Service
mixin TodoService {
  static final todos = ReactiveNotifier<TodoListViewModel>(
    () => TodoListViewModel(),
  );
}

// Widget
class TodoListPage extends StatelessWidget {
  final _inputController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Todo List'),
        actions: [
          ReactiveAsyncBuilder<TodoListViewModel, List<TodoItem>>(
            notifier: TodoService.todos.notifier,
            onLoading: () => SizedBox(),
            onError: (e, s) => SizedBox(),
            onData: (items, vm, keep) => Row(
              children: [
                IconButton(
                  onPressed: vm.canUndo ? vm.undo : null,
                  icon: Icon(Icons.undo),
                  tooltip: 'Undo',
                ),
                Text('${vm.currentHistoryIndex + 1}/${vm.historyLength}'),
                IconButton(
                  onPressed: vm.canRedo ? vm.redo : null,
                  icon: Icon(Icons.redo),
                  tooltip: 'Redo',
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Add todo input
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'Add new todo...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    if (_inputController.text.isNotEmpty) {
                      TodoService.todos.notifier.addTodo(_inputController.text);
                      _inputController.clear();
                    }
                  },
                  icon: Icon(Icons.add),
                ),
              ],
            ),
          ),
          // Todo list
          Expanded(
            child: ReactiveAsyncBuilder<TodoListViewModel, List<TodoItem>>(
              notifier: TodoService.todos.notifier,
              onLoading: () => Center(child: CircularProgressIndicator()),
              onError: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: $error'),
                    ElevatedButton(
                      onPressed: TodoService.todos.notifier.reload,
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
              onData: (items, viewModel, keep) {
                if (items.isEmpty) {
                  return Center(child: Text('No todos yet'));
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final todo = items[index];
                    return Dismissible(
                      key: Key(todo.id),
                      onDismissed: (_) => viewModel.deleteTodo(todo.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: todo.completed,
                          onChanged: (_) => viewModel.toggleTodo(todo.id),
                        ),
                        title: Text(
                          todo.title,
                          style: TextStyle(
                            decoration: todo.completed
                              ? TextDecoration.lineThrough
                              : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline),
                          onPressed: () => viewModel.deleteTodo(todo.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Form with History

Form state with undo/redo support.

```dart
class FormState {
  final String name;
  final String email;
  final String phone;

  const FormState({
    this.name = '',
    this.email = '',
    this.phone = '',
  });

  FormState copyWith({String? name, String? email, String? phone}) => FormState(
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
  );
}

class FormViewModel extends ReplayViewModel<FormState> {
  FormViewModel() : super(
    const FormState(),
    historyLimit: 50,
    debounceHistory: Duration(milliseconds: 300),
  );

  @override
  void init() {}

  void setName(String name) => transformState((s) => s.copyWith(name: name));
  void setEmail(String email) => transformState((s) => s.copyWith(email: email));
  void setPhone(String phone) => transformState((s) => s.copyWith(phone: phone));

  void clear() {
    transformState((_) => const FormState());
    clearHistory();
  }
}

// Service
mixin FormService {
  static final form = ReactiveNotifier<FormViewModel>(
    () => FormViewModel(),
  );
}
```

---

## Reactive Undo Buttons

Using callbacks to reactively update button states.

```dart
class EditorPage extends StatefulWidget {
  @override
  _EditorPageState createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  bool _canUndo = false;
  bool _canRedo = false;
  late final ReplayReactiveNotifier<String> _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ReplayReactiveNotifier<String>(
      create: () => '',
      historyLimit: 100,
      onCanUndoChanged: (canUndo) => setState(() => _canUndo = canUndo),
      onCanRedoChanged: (canRedo) => setState(() => _canRedo = canRedo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          // These buttons update reactively via callbacks
          IconButton(
            onPressed: _canUndo ? _notifier.undo : null,
            icon: Icon(Icons.undo),
          ),
          IconButton(
            onPressed: _canRedo ? _notifier.redo : null,
            icon: Icon(Icons.redo),
          ),
        ],
      ),
      body: ReactiveBuilder<String>(
        notifier: _notifier,
        build: (text, notifier, keep) => TextField(
          controller: TextEditingController(text: text),
          onChanged: (value) => _notifier.updateState(value),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }
}
```

---

## History Timeline Visualization

Visual timeline showing all history states.

```dart
Widget buildHistoryTimeline<T>(ReplayReactiveNotifier<T> notifier) {
  return ReactiveBuilder<T>(
    notifier: notifier,
    build: (state, _, keep) {
      return Container(
        height: 60,
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              onPressed: notifier.canUndo ? notifier.undo : null,
              icon: Icon(Icons.chevron_left),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: notifier.historyLength,
                itemBuilder: (context, index) {
                  final isCurrent = index == notifier.currentHistoryIndex;
                  final isFuture = index > notifier.currentHistoryIndex;

                  return GestureDetector(
                    onTap: () => notifier.jumpToHistory(index),
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent
                          ? Theme.of(context).primaryColor
                          : isFuture
                            ? Colors.grey.shade300
                            : Colors.grey.shade600,
                        border: isCurrent
                          ? Border.all(
                              color: Theme.of(context).primaryColorDark,
                              width: 3,
                            )
                          : null,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCurrent || !isFuture
                              ? Colors.white
                              : Colors.grey.shade700,
                            fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            IconButton(
              onPressed: notifier.canRedo ? notifier.redo : null,
              icon: Icon(Icons.chevron_right),
            ),
          ],
        ),
      );
    },
  );
}
```

---

## Keyboard Shortcuts

Desktop app with Ctrl+Z/Ctrl+Y support.

```dart
class DesktopEditor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // Windows/Linux
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
          const UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY):
          const RedoIntent(),
        // Mac
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
          const UndoIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyZ,
        ): const RedoIntent(),
      },
      child: Actions(
        actions: {
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) {
              if (DocumentService.document.notifier.canUndo) {
                DocumentService.document.notifier.undo();
              }
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) {
              if (DocumentService.document.notifier.canRedo) {
                DocumentService.document.notifier.redo();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: DocumentEditorWidget(),
        ),
      ),
    );
  }
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}
```

---

## Game State with History

Turn-based game with move history.

```dart
class GameState {
  final List<List<int>> board;
  final int currentPlayer;
  final int? winner;

  const GameState({
    required this.board,
    this.currentPlayer = 1,
    this.winner,
  });

  GameState copyWith({
    List<List<int>>? board,
    int? currentPlayer,
    int? winner,
  }) => GameState(
    board: board ?? this.board,
    currentPlayer: currentPlayer ?? this.currentPlayer,
    winner: winner ?? this.winner,
  );

  factory GameState.initial() => GameState(
    board: List.generate(3, (_) => List.filled(3, 0)),
  );
}

class GameViewModel extends ReplayViewModel<GameState> {
  GameViewModel() : super(
    GameState.initial(),
    historyLimit: 20, // Max 20 moves in history
  );

  @override
  void init() {}

  void makeMove(int row, int col) {
    if (data.board[row][col] != 0 || data.winner != null) return;

    final newBoard = data.board.map((r) => [...r]).toList();
    newBoard[row][col] = data.currentPlayer;

    final winner = _checkWinner(newBoard);

    transformState((state) => state.copyWith(
      board: newBoard,
      currentPlayer: state.currentPlayer == 1 ? 2 : 1,
      winner: winner,
    ));
  }

  void restart() {
    transformState((_) => GameState.initial());
    clearHistory();
  }

  int? _checkWinner(List<List<int>> board) {
    // Check rows, columns, diagonals
    // ... winner checking logic
    return null;
  }
}

// Service
mixin GameService {
  static final game = ReactiveNotifier<GameViewModel>(
    () => GameViewModel(),
  );
}
```
