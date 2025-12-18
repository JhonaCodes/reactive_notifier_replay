# reactive_notifier_replay

**Undo/Redo Extension for ReactiveNotifier** - Add time-travel debugging and state history tracking to your ReactiveNotifier state management. Navigate through state changes with undo/redo, visualize history timelines, and group rapid changes with debounce support.

[![Dart SDK Version](https://img.shields.io/badge/Dart-SDK%20%3E%3D%203.10.1-0175C2?logo=dart)](https://dart.dev)
[![Flutter Platform](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![pub package](https://img.shields.io/pub/v/reactive_notifier_replay.svg)](https://pub.dev/packages/reactive_notifier_replay)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Key Features

- **History Tracking** - Automatic recording of state changes with configurable limits
- **Undo/Redo** - Navigate through state history with simple API
- **Debounce Support** - Group rapid changes into single history entries (ideal for text editors)
- **Jump to History** - Navigate directly to any point in history
- **Peek History** - View historical states without changing current state
- **Availability Callbacks** - React to undo/redo availability changes for UI updates
- **Full Compatibility** - Works seamlessly with existing ReactiveNotifier patterns and builders
- **Shared Mixin** - Reusable `ReplayHistoryMixin` for custom implementations

---

## Installation

```yaml
dependencies:
  reactive_notifier_replay: ^2.16.1
```

Then run:

```bash
flutter pub get
```

---

## Architecture

reactive_notifier_replay extends ReactiveNotifier's singleton pattern with history tracking:

- **Wrapper Pattern** - ReplayReactiveNotifier wraps ReactiveNotifier adding history
- **Extension Pattern** - ReplayViewModel and ReplayAsyncViewModelImpl extend base classes
- **Shared Logic** - ReplayHistoryMixin provides reusable history functionality
- **Hook Integration** - Uses onStateChanged/onAsyncStateChanged hooks automatically
- **Memory Efficient** - Configurable history limits prevent unbounded growth

---

## Quick Start Guide

### 1. Simple State with ReplayReactiveNotifier

```dart
import 'package:reactive_notifier_replay/reactive_notifier_replay.dart';

// Define service with replay-enabled notifier
mixin CounterService {
  static final counter = ReplayReactiveNotifier<int>(
    create: () => 0,
    historyLimit: 50,
  );

  static void increment() => counter.updateState(counter.notifier + 1);
  static void decrement() => counter.updateState(counter.notifier - 1);
  static void undo() => counter.undo();
  static void redo() => counter.redo();
}

// Use in widgets - works with standard ReactiveBuilder
class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ReactiveBuilder<int>(
      notifier: CounterService.counter,
      build: (value, notifier, keep) {
        return Column(
          children: [
            Text('Count: $value'),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => CounterService.increment(),
                  child: Text('+'),
                ),
                ElevatedButton(
                  onPressed: () => CounterService.decrement(),
                  child: Text('-'),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: CounterService.counter.canUndo
                    ? CounterService.undo
                    : null,
                  icon: Icon(Icons.undo),
                ),
                IconButton(
                  onPressed: CounterService.counter.canRedo
                    ? CounterService.redo
                    : null,
                  icon: Icon(Icons.redo),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
```

### 2. Complex State with ReplayViewModel

```dart
// Define state model
class DocumentState {
  final String content;
  final int cursorPosition;
  final bool isDirty;

  const DocumentState({
    this.content = '',
    this.cursorPosition = 0,
    this.isDirty = false,
  });

  factory DocumentState.empty() => const DocumentState();

  DocumentState copyWith({
    String? content,
    int? cursorPosition,
    bool? isDirty,
  }) {
    return DocumentState(
      content: content ?? this.content,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

// Define ViewModel with history tracking
class DocumentViewModel extends ReplayViewModel<DocumentState> {
  DocumentViewModel() : super(
    DocumentState.empty(),
    historyLimit: 100,
    debounceHistory: Duration(milliseconds: 300), // Group rapid typing
  );

  @override
  void init() {
    // Synchronous initialization
  }

  void updateContent(String content) {
    transformState((state) => state.copyWith(
      content: content,
      isDirty: true,
    ));
  }

  void setCursorPosition(int position) {
    // Use silent update to avoid cluttering history with cursor moves
    transformStateSilently((state) => state.copyWith(
      cursorPosition: position,
    ));
  }

  void markSaved() {
    transformState((state) => state.copyWith(isDirty: false));
    clearHistory(); // Start fresh history after save
  }
}

// Define service
mixin DocumentService {
  static final document = ReactiveNotifier<DocumentViewModel>(
    () => DocumentViewModel(),
  );

  static void undo() => document.notifier.undo();
  static void redo() => document.notifier.redo();
  static bool get canUndo => document.notifier.canUndo;
  static bool get canRedo => document.notifier.canRedo;
}

// Use in widget
class DocumentEditorWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<DocumentViewModel, DocumentState>(
      viewmodel: DocumentService.document.notifier,
      build: (state, viewModel, keep) {
        return Column(
          children: [
            // Toolbar with undo/redo
            Row(
              children: [
                IconButton(
                  onPressed: viewModel.canUndo ? viewModel.undo : null,
                  icon: Icon(Icons.undo),
                  tooltip: 'Undo',
                ),
                IconButton(
                  onPressed: viewModel.canRedo ? viewModel.redo : null,
                  icon: Icon(Icons.redo),
                  tooltip: 'Redo',
                ),
                if (state.isDirty) Text('Unsaved changes'),
              ],
            ),
            // Editor
            Expanded(
              child: TextField(
                controller: TextEditingController(text: state.content),
                onChanged: viewModel.updateContent,
                maxLines: null,
                expands: true,
              ),
            ),
          ],
        );
      },
    );
  }
}
```

### 3. Async Operations with ReplayAsyncViewModelImpl

```dart
// Define model
class TodoItem {
  final String id;
  final String title;
  final bool completed;

  TodoItem({required this.id, required this.title, this.completed = false});

  TodoItem copyWith({String? title, bool? completed}) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }
}

// Define async ViewModel with history (only success states tracked)
class TodoListViewModel extends ReplayAsyncViewModelImpl<List<TodoItem>> {
  final TodoRepository _repository;

  TodoListViewModel(this._repository) : super(
    AsyncState.initial(),
    historyLimit: 50,
  );

  @override
  Future<List<TodoItem>> init() async {
    return await _repository.loadTodos();
  }

  void toggleTodo(String id) {
    transformDataState((items) {
      return items?.map((item) {
        if (item.id == id) {
          return item.copyWith(completed: !item.completed);
        }
        return item;
      }).toList();
    });
    // This change is recorded in history
  }

  void deleteTodo(String id) {
    transformDataState((items) {
      return items?.where((item) => item.id != id).toList();
    });
    // User can undo this deletion!
  }

  void addTodo(String title) {
    transformDataState((items) {
      final newTodo = TodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
      );
      return [...?items, newTodo];
    });
  }
}

// Define service
mixin TodoService {
  static final todos = ReactiveNotifier<TodoListViewModel>(
    () => TodoListViewModel(TodoRepository()),
  );
}

// Use in widget
class TodoListWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ReactiveAsyncBuilder<TodoListViewModel, List<TodoItem>>(
      notifier: TodoService.todos.notifier,
      onLoading: () => Center(child: CircularProgressIndicator()),
      onError: (error, stack) => Center(child: Text('Error: $error')),
      onData: (items, viewModel, keep) {
        return Column(
          children: [
            // Undo/Redo toolbar
            keep(Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: viewModel.canUndo ? viewModel.undo : null,
                  icon: Icon(Icons.undo),
                ),
                Text('${viewModel.currentHistoryIndex + 1}/${viewModel.historyLength}'),
                IconButton(
                  onPressed: viewModel.canRedo ? viewModel.redo : null,
                  icon: Icon(Icons.redo),
                ),
              ],
            )),
            // Todo list
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final todo = items[index];
                  return ListTile(
                    title: Text(
                      todo.title,
                      style: TextStyle(
                        decoration: todo.completed
                          ? TextDecoration.lineThrough
                          : null,
                      ),
                    ),
                    leading: Checkbox(
                      value: todo.completed,
                      onChanged: (_) => viewModel.toggleTodo(todo.id),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => viewModel.deleteTodo(todo.id),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
```

---

## API Reference

### ReplayReactiveNotifier<T>

A wrapper around `ReactiveNotifier` that provides undo/redo functionality for simple state values.

#### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `create` | `T Function()` | required | Factory function for initial state |
| `historyLimit` | `int` | 100 | Maximum number of states to keep in history |
| `debounceHistory` | `Duration?` | null | Debounce duration for grouping rapid changes |
| `onCanUndoChanged` | `void Function(bool)?` | null | Callback when undo availability changes |
| `onCanRedoChanged` | `void Function(bool)?` | null | Callback when redo availability changes |
| `related` | `List<ReactiveNotifier>?` | null | Related ReactiveNotifiers |
| `key` | `Key?` | null | Instance key |
| `autoDispose` | `bool` | false | Enable auto-dispose |

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `notifier` | `T` | Current state value |
| `canUndo` | `bool` | Whether undo is available |
| `canRedo` | `bool` | Whether redo is available |
| `historyLength` | `int` | Current number of states in history |
| `currentHistoryIndex` | `int` | Current position in history (0-indexed) |
| `isPerformingUndoRedo` | `bool` | Whether an undo/redo operation is in progress |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `undo()` | `void` | Undoes the last state change |
| `redo()` | `void` | Redoes the previously undone change |
| `clearHistory([T? currentState])` | `void` | Clears history, keeping current or specified state |
| `jumpToHistory(int index)` | `void` | Jumps to specific index in history |
| `peekHistory(int index)` | `T?` | Gets state at index without changing current state |
| `updateState(T newState)` | `void` | Updates state with notification (recorded in history) |
| `updateSilently(T newState)` | `void` | Updates without notification (still recorded in history) |
| `transformState(T Function(T) transform)` | `void` | Transforms state with notification |
| `transformStateSilently(T Function(T) transform)` | `void` | Transforms without notification |
| `recreate()` | `T` | Recreates state using factory, clears history |
| `listen(void Function(T) callback)` | `T` | Listens to state changes |

---

### ReplayViewModel<T>

An abstract class extending `ViewModel` with automatic history tracking.

#### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `initialState` | `T` | required | Initial state value |
| `historyLimit` | `int` | 100 | Maximum number of states to keep |
| `debounceHistory` | `Duration?` | null | Debounce for grouping rapid changes |
| `onCanUndoChanged` | `void Function(bool)?` | null | Callback when undo availability changes |
| `onCanRedoChanged` | `void Function(bool)?` | null | Callback when redo availability changes |

#### Required Overrides

```dart
@override
void init() {
  // Your synchronous initialization logic (MUST be synchronous)
}
```

#### Inherited Properties & Methods

All properties and methods from `ViewModel<T>` plus all history properties/methods from `ReplayHistoryMixin`.

#### Important Notes

- History is recorded automatically via the `onStateChanged` hook
- Both `updateState()` and `updateSilently()` record to history
- Use `transformStateSilently()` to skip history recording for cursor position changes, etc.

---

### ReplayAsyncViewModelImpl<T>

An abstract class extending `AsyncViewModelImpl` with history tracking for **success states only**.

#### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `initialState` | `AsyncState<T>` | required | Initial async state (typically `AsyncState.initial()`) |
| `historyLimit` | `int` | 100 | Maximum success states to keep |
| `debounceHistory` | `Duration?` | null | Debounce for grouping rapid changes |
| `onCanUndoChanged` | `void Function(bool)?` | null | Callback when undo availability changes |
| `onCanRedoChanged` | `void Function(bool)?` | null | Callback when redo availability changes |
| `loadOnInit` | `bool` | true | Whether to call init() automatically |
| `waitForContext` | `bool` | false | Whether to wait for BuildContext before init() |

#### Required Overrides

```dart
@override
Future<T> init() async {
  // Your async initialization logic (MUST be asynchronous)
  return await loadData();
}
```

#### Important Notes

- **Only success states** are recorded in history
- Loading, error, and initial states are **NOT** tracked
- Undo/Redo navigates between success states only
- Perfect for data lists where users can undo deletions/modifications

---

### ReplayHistoryMixin<T>

A mixin providing reusable history tracking functionality for custom implementations.

#### Configuration Class

```dart
class ReplayHistoryConfig {
  final int historyLimit;
  final Duration? debounceHistory;
  final void Function(bool canUndo)? onCanUndoChanged;
  final void Function(bool canRedo)? onCanRedoChanged;
}
```

#### Required Implementation

```dart
class MyCustomReplayClass with ReplayHistoryMixin<MyState> {
  MyCustomReplayClass() {
    // 1. Initialize configuration
    initializeHistory(ReplayHistoryConfig(
      historyLimit: 100,
      debounceHistory: Duration(milliseconds: 300),
    ));

    // 2. Record initial state
    recordInitialState(initialState);
  }

  // 3. Call on state changes (when not performing undo/redo)
  void onMyStateChanged(MyState newState) {
    if (!isPerformingUndoRedo) {
      handleStateChangeForHistory(newState);
    }
  }

  // 4. Implement how to apply historical state
  @override
  void applyHistoricalState(MyState state) {
    _internalState = state;
    notifyListeners();
  }

  // 5. Clean up on dispose
  void dispose() {
    disposeHistory();
  }
}
```

---

## Advanced Usage

### Debounce for Text Editors

Group rapid keystrokes into single history entries:

```dart
class TextEditorViewModel extends ReplayViewModel<TextState> {
  TextEditorViewModel() : super(
    TextState.empty(),
    historyLimit: 100,
    debounceHistory: Duration(milliseconds: 500), // 500ms pause triggers save
  );

  @override
  void init() {}

  void onTextChanged(String text) {
    // Each keystroke calls this, but history only records after 500ms pause
    transformState((state) => state.copyWith(text: text));
  }
}
```

### Reactive Undo/Redo Buttons with Callbacks

Use callbacks to reactively update button states:

```dart
class EditorPage extends StatefulWidget {
  @override
  _EditorPageState createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  bool _canUndo = false;
  bool _canRedo = false;

  late final ReplayReactiveNotifier<TextState> _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ReplayReactiveNotifier<TextState>(
      create: () => TextState.empty(),
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
      body: ReactiveBuilder<TextState>(
        notifier: _notifier,
        build: (state, notifier, keep) => TextField(
          controller: TextEditingController(text: state.text),
          onChanged: (text) => _notifier.updateState(state.copyWith(text: text)),
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

### History Timeline Visualization

Display a visual timeline allowing users to jump to any point:

```dart
Widget buildHistoryTimeline<T>(ReplayReactiveNotifier<T> notifier) {
  return ReactiveBuilder<T>(
    notifier: notifier,
    build: (state, _, keep) {
      return SizedBox(
        height: 60,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: notifier.historyLength,
          itemBuilder: (context, index) {
            final isCurrentState = index == notifier.currentHistoryIndex;
            final isFutureState = index > notifier.currentHistoryIndex;

            return GestureDetector(
              onTap: () => notifier.jumpToHistory(index),
              child: Container(
                width: 24,
                height: 24,
                margin: EdgeInsets.symmetric(horizontal: 4, vertical: 18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrentState
                    ? Colors.blue
                    : isFutureState
                      ? Colors.grey.shade300
                      : Colors.grey.shade600,
                  border: isCurrentState
                    ? Border.all(color: Colors.blue.shade900, width: 2)
                    : null,
                ),
                child: isCurrentState
                  ? Icon(Icons.circle, size: 12, color: Colors.white)
                  : null,
              ),
            );
          },
        ),
      );
    },
  );
}
```

### Keyboard Shortcuts for Desktop

Integrate with keyboard shortcuts for native undo/redo experience:

```dart
class DesktopEditor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
          const UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY):
          const RedoIntent(),
        // Mac support
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
          const UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyZ):
          const RedoIntent(),
      },
      child: Actions(
        actions: {
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) => DocumentService.undo(),
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) => DocumentService.redo(),
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

## When to Use Each Component

### ReplayReactiveNotifier<T>

- Simple state values (int, bool, String, enums)
- Settings with undo support
- Game scores or counters
- State doesn't require initialization logic
- When you need a direct wrapper with minimal boilerplate

### ReplayViewModel<T>

- Complex state objects with business logic
- Text editors with debounced history
- Form state with validation
- State that requires synchronous initialization
- When you need full ViewModel lifecycle

### ReplayAsyncViewModelImpl<T>

- Data lists loaded from API/database
- State where users can undo deletions
- Async data with loading/error states
- When only success states should be tracked
- Perfect for CRUD operations with undo

### ReplayHistoryMixin<T>

- Custom state management implementations
- Integrating with existing classes
- When you need maximum flexibility
- Building your own replay-enabled components

---

## Comparison with Similar Packages

| Feature | reactive_notifier_replay | replay_bloc | undo_redo |
|---------|-------------------------|-------------|-----------|
| State Management | ReactiveNotifier | BLoC | Provider |
| History Limit | Configurable | Configurable | Configurable |
| Debounce Support | Built-in | Manual | No |
| Async Support | Success states only | All events | No |
| Jump to History | Yes | No | No |
| Peek History | Yes | No | No |
| Availability Callbacks | Yes | Yes | No |
| Memory Efficient | Configurable limit | Configurable limit | Fixed |
| Service Pattern | Mixins (namespace) | Cubits/Blocs | ChangeNotifier |
| Mixin for Custom | Yes | No | No |

---

## Best Practices

### 1. Set Appropriate History Limits

```dart
// Text editor - many changes expected
ReplayViewModel<TextState>(historyLimit: 200, ...)

// Settings - few changes expected
ReplayReactiveNotifier<Settings>(create: () => Settings(), historyLimit: 20)

// Game state - moderate changes
ReplayViewModel<GameState>(historyLimit: 50, ...)
```

### 2. Use Debounce for Text Input

```dart
// Prevent every keystroke from creating history entry
ReplayViewModel<DocumentState>(
  debounceHistory: Duration(milliseconds: 300),
  ...
)
```

### 3. Clear History on Significant Events

```dart
void saveDocument() async {
  await repository.save(data);
  clearHistory(); // Start fresh after save
}

void logout() {
  clearHistory(); // Clear sensitive data from history
}
```

### 4. Follow the Mixin Service Pattern

```dart
// ALWAYS use mixins for services
mixin EditorService {
  static final document = ReactiveNotifier<DocumentViewModel>(
    () => DocumentViewModel(),
  );
}

// NEVER use global variables
// final document = ReactiveNotifier<DocumentViewModel>(...); // Wrong!
```

### 5. Handle Async States Carefully

```dart
// Remember: only success states are tracked
class DataViewModel extends ReplayAsyncViewModelImpl<List<Item>> {
  void deleteItem(String id) {
    transformDataState((items) => items?.where((i) => i.id != id).toList());
    // User can undo this!
  }

  Future<void> reload() async {
    // Loading state is NOT tracked
    // New success state IS tracked
    await super.reload();
  }
}
```

---

## Testing

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:reactive_notifier_replay/reactive_notifier_replay.dart';

void main() {
  setUp(() {
    ReactiveNotifier.cleanup(); // Clear all states between tests
  });

  group('ReplayReactiveNotifier', () {
    test('should support undo/redo', () {
      final notifier = ReplayReactiveNotifier<int>(create: () => 0);

      notifier.updateState(1);
      notifier.updateState(2);
      notifier.updateState(3);

      expect(notifier.notifier, equals(3));
      expect(notifier.canUndo, isTrue);
      expect(notifier.historyLength, equals(4)); // initial + 3 updates

      notifier.undo();
      expect(notifier.notifier, equals(2));
      expect(notifier.canRedo, isTrue);

      notifier.undo();
      expect(notifier.notifier, equals(1));

      notifier.redo();
      expect(notifier.notifier, equals(2));
    });

    test('should respect history limit', () {
      final notifier = ReplayReactiveNotifier<int>(
        create: () => 0,
        historyLimit: 5,
      );

      for (int i = 1; i <= 10; i++) {
        notifier.updateState(i);
      }

      expect(notifier.historyLength, equals(5));
      expect(notifier.peekHistory(0), equals(6)); // Oldest in limited history
    });

    test('should clear redo on new state after undo', () {
      final notifier = ReplayReactiveNotifier<int>(create: () => 0);

      notifier.updateState(1);
      notifier.updateState(2);
      notifier.undo();
      notifier.updateState(10); // New branch

      expect(notifier.canRedo, isFalse);
      expect(notifier.historyLength, equals(3)); // 0, 1, 10
    });
  });

  group('ReplayViewModel', () {
    test('should track state changes via hook', () {
      final viewModel = TestCounterViewModel();

      viewModel.increment();
      viewModel.increment();
      viewModel.increment();

      expect(viewModel.data.value, equals(3));
      expect(viewModel.historyLength, equals(4));

      viewModel.undo();
      expect(viewModel.data.value, equals(2));

      viewModel.redo();
      expect(viewModel.data.value, equals(3));
    });
  });

  group('ReplayAsyncViewModelImpl', () {
    test('should only track success states', () async {
      final viewModel = TestAsyncViewModel();

      // Wait for init to complete
      await Future.delayed(Duration(milliseconds: 50));

      expect(viewModel.hasData, isTrue);
      expect(viewModel.historyLength, equals(1));

      viewModel.setContent('First');
      viewModel.setContent('Second');

      expect(viewModel.historyLength, equals(3));

      viewModel.undo();
      expect(viewModel.data?.content, equals('First'));
    });
  });
}

// Test helpers
class TestCounterViewModel extends ReplayViewModel<CounterState> {
  TestCounterViewModel() : super(CounterState(0));

  @override
  void init() {}

  void increment() {
    transformState((s) => CounterState(s.value + 1));
  }
}

class CounterState {
  final int value;
  CounterState(this.value);
}

class TestAsyncViewModel extends ReplayAsyncViewModelImpl<DocumentState> {
  TestAsyncViewModel() : super(AsyncState.initial());

  @override
  Future<DocumentState> init() async {
    await Future.delayed(Duration(milliseconds: 10));
    return DocumentState.empty();
  }

  void setContent(String content) {
    transformDataState((s) => s?.copyWith(content: content));
  }
}

class DocumentState {
  final String content;
  DocumentState({this.content = ''});
  factory DocumentState.empty() => DocumentState();
  DocumentState copyWith({String? content}) => DocumentState(content: content ?? this.content);
}
```

---

## Documentation

For comprehensive documentation, see the [docs](./docs) folder:

- **[Getting Started](./docs/getting-started/quick-start.md)** - Installation and basic setup
- **[ReplayReactiveNotifier](./docs/features/replay-reactive-notifier.md)** - Simple state with history
- **[ReplayViewModel](./docs/features/replay-viewmodel.md)** - Complex state with business logic
- **[ReplayAsyncViewModelImpl](./docs/features/replay-async-viewmodel.md)** - Async operations with history
- **[ReplayHistoryMixin](./docs/features/replay-history-mixin.md)** - Custom implementations
- **[API Reference](./docs/api-reference.md)** - Complete API documentation
- **[Examples](./docs/examples.md)** - Practical use cases
- **[Best Practices](./docs/guides/best-practices.md)** - Recommended patterns
- **[Migration Guide](./docs/guides/migration.md)** - Migration from other solutions
- **[Testing Guide](./docs/testing/testing-guide.md)** - Testing patterns

---

## License

MIT License - see the [LICENSE](LICENSE) file for details.

---

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a pull request.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/JhonaCodes/reactive_notifier_replay.git

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run example app
cd example && flutter run
```

---

## Related Packages

- [reactive_notifier](https://pub.dev/packages/reactive_notifier) - The core state management library
- [reactive_notifier_hydrated](https://pub.dev/packages/reactive_notifier_hydrated) - Persistence extension for ReactiveNotifier

---

**Made with care by [@JhonaCodes](https://github.com/JhonaCodes)**

*reactive_notifier_replay - Time-travel debugging for ReactiveNotifier*
