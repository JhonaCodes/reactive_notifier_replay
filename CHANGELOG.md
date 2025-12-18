# 2.16.1
## Version Sync & Documentation

### Updates
- Synchronized version with reactive_notifier ecosystem (2.16.1)
- Updated Dart SDK requirement to ^3.10.0
- Updated dependency to reactive_notifier ^2.16.1
- Fixed GitHub username references in documentation

### Documentation
- Updated README examples and version references
- Enhanced CLAUDE.md with complete API patterns

---

# 2.16.0
## Initial Release - Undo/Redo for ReactiveNotifier

### New Features

#### ReplayReactiveNotifier<T>
Wrapper around ReactiveNotifier with history tracking:
```dart
mixin CounterService {
  static final counter = ReplayReactiveNotifier<int>(
    create: () => 0,
    historyLimit: 50,
    onCanUndoChanged: (canUndo) => print('Can undo: $canUndo'),
    onCanRedoChanged: (canRedo) => print('Can redo: $canRedo'),
  );

  static void increment() => counter.updateState(counter.notifier + 1);
  static void undo() => counter.undo();
  static void redo() => counter.redo();
}
```

#### ReplayViewModel<T>
ViewModel extension with automatic state history:
```dart
class DocumentViewModel extends ReplayViewModel<DocumentState> {
  DocumentViewModel() : super(
    DocumentState.empty(),
    historyLimit: 100,
    debounceHistory: Duration(milliseconds: 500),
  );

  void updateContent(String content) {
    transformState((state) => state.copyWith(content: content));
  }
}
```

#### ReplayAsyncViewModelImpl<T>
AsyncViewModelImpl extension that tracks only success states:
```dart
class TodoListViewModel extends ReplayAsyncViewModelImpl<List<Todo>> {
  TodoListViewModel() : super(AsyncState.initial(), historyLimit: 20);

  @override
  Future<List<Todo>> init() async => await repository.loadTodos();

  void deleteTodo(String id) {
    transformDataState((todos) => todos?.where((t) => t.id != id).toList());
    // User can undo() to restore deleted todo!
  }
}
```

#### ReplayHistoryMixin<T>
Shared mixin for custom implementations with configurable options:
- `historyLimit`: Maximum states to keep (default: 100)
- `debounceHistory`: Group rapid changes (ideal for text editors)
- `onCanUndoChanged`: Callback for UI updates
- `onCanRedoChanged`: Callback for UI updates

### Core Capabilities
- **Undo/Redo Navigation**: Navigate through state history with `undo()` and `redo()`
- **Jump to History**: Navigate directly to any point with `jumpToHistory(index)`
- **Peek History**: View historical states without changing current with `peekHistory(index)`
- **Clear History**: Reset history with `clearHistory()` or `clearHistory(specificState)`
- **History Properties**: `canUndo`, `canRedo`, `historyLength`, `currentHistoryIndex`

### Integration
- Fully compatible with ReactiveNotifier 2.16.0+
- Uses `onStateChanged`/`onAsyncStateChanged` hooks automatically
- Works with all ReactiveNotifier builders (ReactiveBuilder, ReactiveViewModelBuilder, ReactiveAsyncBuilder)
- Follows ReactiveNotifier patterns and conventions

### Dependencies
- Requires `reactive_notifier: ^2.16.0`
- Dart SDK: ^3.5.4
- Flutter SDK: >=1.17.0
