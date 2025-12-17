# ReplayViewModel<T>

A `ViewModel` that provides undo/redo functionality with automatic state history tracking.

## Overview

`ReplayViewModel<T>` extends `ViewModel<T>` to add automatic state history tracking with undo/redo capabilities. It uses the `onStateChanged` hook to automatically record state changes.

## When to Use

| Scenario | Use ReplayViewModel<T> |
|----------|------------------------|
| Complex state objects with business logic | Yes |
| Text editors with debounced history | Yes |
| Form state with validation | Yes |
| State requiring synchronous initialization | Yes |
| Simple primitives | No (use ReplayReactiveNotifier) |
| Async data loading | No (use ReplayAsyncViewModelImpl) |

## Basic Usage

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
    DocumentState(),
    historyLimit: 100,
    debounceHistory: Duration(milliseconds: 300),
  );

  @override
  void init() {
    // Synchronous initialization (MUST be synchronous)
  }

  void updateContent(String content) {
    transformState((state) => state.copyWith(
      content: content,
      isDirty: true,
    ));
  }

  void setCursorPosition(int position) {
    // Use silent update to avoid cluttering history
    transformStateSilently((state) => state.copyWith(
      cursorPosition: position,
    ));
  }
}

// Define service
mixin DocumentService {
  static final document = ReactiveNotifier<DocumentViewModel>(
    () => DocumentViewModel(),
  );

  static void undo() => document.notifier.undo();
  static void redo() => document.notifier.redo();
}
```

## Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `initialState` | `T` | required | Initial state value |
| `historyLimit` | `int` | 100 | Maximum number of states to keep |
| `debounceHistory` | `Duration?` | null | Debounce for grouping rapid changes |
| `onCanUndoChanged` | `void Function(bool)?` | null | Callback when undo availability changes |
| `onCanRedoChanged` | `void Function(bool)?` | null | Callback when redo availability changes |

## Properties

### Inherited from ViewModel<T>

| Property | Type | Description |
|----------|------|-------------|
| `data` | `T` | Current state |
| `isDisposed` | `bool` | Disposal status |
| `hasInitializedListenerExecution` | `bool` | Init cycle complete |
| `activeListenerCount` | `int` | Active listeners count |

### From ReplayHistoryMixin<T>

| Property | Type | Description |
|----------|------|-------------|
| `canUndo` | `bool` | Whether undo is available |
| `canRedo` | `bool` | Whether redo is available |
| `historyLength` | `int` | Current number of states in history |
| `currentHistoryIndex` | `int` | Current position in history (0-indexed) |
| `isPerformingUndoRedo` | `bool` | Whether undo/redo operation is in progress |
| `historyLimit` | `int` | Maximum number of states to keep |
| `debounceHistory` | `Duration?` | Debounce duration |

## Methods

### Lifecycle Methods (from ViewModel)

| Method | Description |
|--------|-------------|
| `init()` | Synchronous initialization (MUST override) |
| `dispose()` | Cleanup and disposal |
| `reload()` | Reinitialize ViewModel |
| `onResume(data)` | Post-initialization hook |
| `setupListeners()` | Register external listeners |
| `removeListeners()` | Remove external listeners |

### State Update Methods

| Method | Notifies | Records History | Description |
|--------|----------|-----------------|-------------|
| `updateState(newState)` | Yes | Yes | Updates state with notification |
| `updateSilently(newState)` | No | Yes | Updates without notification |
| `transformState(fn)` | Yes | Yes | Transforms with notification |
| `transformStateSilently(fn)` | No | Yes | Transforms without notification |
| `cleanState()` | Yes | Yes | Resets to initial state |

### History Methods

| Method | Return | Description |
|--------|--------|-------------|
| `undo()` | `void` | Undoes the last state change |
| `redo()` | `void` | Redoes the previously undone change |
| `clearHistory([T? currentState])` | `void` | Clears history, keeping current or specified state |
| `jumpToHistory(int index)` | `void` | Jumps to specific index in history |
| `peekHistory(int index)` | `T?` | Gets state at index without changing current state |

### Communication Methods (from ViewModel)

| Method | Description |
|--------|-------------|
| `listenVM(callback, callOnInit)` | Cross-VM communication |
| `stopListeningVM()` | Stop all listeners |
| `stopSpecificListener(key)` | Stop specific listener |

## Lifecycle Diagram

```
+----------------------------------------------------------+
|                 ReplayViewModel Lifecycle                  |
+----------------------------------------------------------+
|                                                            |
|  Constructor --> init() --> setupListeners() --> onResume()|
|       |            |              |                |       |
|       v            v              v                v       |
|   Create with   Sync init     Register        Post-init   |
|   initial state + record     listeners        tasks       |
|                  history                                   |
|                                                            |
+----------------------------------------------------------+
|                                                            |
|  State Updates: updateState / transformState               |
|       |                                                    |
|       v                                                    |
|  onStateChanged(previous, next) --> recordHistory()        |
|       |                                                    |
|       v                                                    |
|  notifyListeners() (if not silent)                        |
|                                                            |
+----------------------------------------------------------+
|                                                            |
|  undo() / redo() / jumpToHistory()                        |
|       |                                                    |
|       v                                                    |
|  applyHistoricalState() --> updateState()                 |
|  (isPerformingUndoRedo = true, so history not recorded)   |
|                                                            |
+----------------------------------------------------------+
|                                                            |
|  dispose() --> disposeHistory() --> cleanup               |
|                                                            |
+----------------------------------------------------------+
```

## Important Notes

### History Recording

- History is recorded automatically via the `onStateChanged` hook
- Both `updateState()` and `updateSilently()` record to history
- Both `transformState()` and `transformStateSilently()` record to history
- During undo/redo, `isPerformingUndoRedo` is true, preventing double recording

### Debounce Behavior

When `debounceHistory` is set:
- Rapid state changes are grouped into single history entries
- Only the final state after the debounce period is recorded
- Useful for text editors to avoid recording every keystroke

```dart
// Rapid typing "Hello" with 300ms debounce
// Instead of: ['', 'H', 'He', 'Hel', 'Hell', 'Hello']
// Records:    ['', 'Hello'] (after 300ms pause)
```

## Examples

### Text Editor with Debounce

```dart
class TextEditorViewModel extends ReplayViewModel<TextState> {
  TextEditorViewModel() : super(
    TextState.empty(),
    historyLimit: 200,
    debounceHistory: Duration(milliseconds: 500),
  );

  @override
  void init() {}

  void onTextChanged(String text) {
    transformState((state) => state.copyWith(text: text));
  }
}
```

### With Availability Callbacks

```dart
class EditorViewModel extends ReplayViewModel<EditorState> {
  final Function(bool)? onUndoAvailable;
  final Function(bool)? onRedoAvailable;

  EditorViewModel({
    this.onUndoAvailable,
    this.onRedoAvailable,
  }) : super(
    EditorState.empty(),
    historyLimit: 100,
    onCanUndoChanged: onUndoAvailable,
    onCanRedoChanged: onRedoAvailable,
  );

  @override
  void init() {}
}
```

### Cross-ViewModel Communication

```dart
class EditorViewModel extends ReplayViewModel<EditorState> {
  UserModel? currentUser;

  EditorViewModel() : super(EditorState.empty());

  @override
  void init() {
    // Listen to user changes
    UserService.userState.notifier.listenVM((userData) {
      currentUser = userData;
      // React to user changes
    });
  }
}
```

### Clear History on Save

```dart
class DocumentViewModel extends ReplayViewModel<DocumentState> {
  DocumentViewModel() : super(DocumentState());

  @override
  void init() {}

  Future<void> save() async {
    await repository.save(data);
    transformState((state) => state.copyWith(isDirty: false));
    clearHistory(); // Start fresh after save
  }
}
```

## Related Documentation

- [ReplayReactiveNotifier](replay-reactive-notifier.md) - For simple state
- [ReplayAsyncViewModelImpl](replay-async-viewmodel.md) - For async operations
- [ReplayHistoryMixin](replay-history-mixin.md) - For custom implementations
- [Best Practices](../guides/best-practices.md) - Recommended patterns
