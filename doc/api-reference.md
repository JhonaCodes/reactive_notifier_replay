# API Reference

Complete API documentation for ReactiveNotifier Replay.

## Classes

### ReplayReactiveNotifier<T>

A wrapper around `ReactiveNotifier` that provides undo/redo functionality.

```dart
class ReplayReactiveNotifier<T> extends ChangeNotifier
    with ReplayHistoryMixin<T>
```

#### Constructor

```dart
ReplayReactiveNotifier({
  required T Function() create,
  int historyLimit = 100,
  Duration? debounceHistory,
  void Function(bool canUndo)? onCanUndoChanged,
  void Function(bool canRedo)? onCanRedoChanged,
  List<ReactiveNotifier>? related,
  Key? key,
  bool autoDispose = false,
})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `notifier` | `T` | Current state value |
| `keyNotifier` | `Key` | The key used by the inner ReactiveNotifier |
| `canUndo` | `bool` | Whether undo is available |
| `canRedo` | `bool` | Whether redo is available |
| `historyLength` | `int` | Number of states in history |
| `currentHistoryIndex` | `int` | Current position (0-indexed) |
| `isPerformingUndoRedo` | `bool` | Whether undo/redo in progress |
| `historyLimit` | `int` | Maximum states to keep |
| `debounceHistory` | `Duration?` | Debounce duration |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `undo()` | `void` | Undo last change |
| `redo()` | `void` | Redo undone change |
| `clearHistory([T? currentState])` | `void` | Clear history |
| `jumpToHistory(int index)` | `void` | Jump to index |
| `peekHistory(int index)` | `T?` | Get state at index |
| `updateState(T newState)` | `void` | Update with notification |
| `updateSilently(T newState)` | `void` | Update without notification |
| `transformState(T Function(T) transform)` | `void` | Transform with notification |
| `transformStateSilently(T Function(T) transform)` | `void` | Transform without notification |
| `listen(void Function(T) callback)` | `T` | Listen to changes |
| `stopListening()` | `void` | Stop listening |
| `recreate()` | `T` | Recreate with factory |
| `addReference(String referenceId)` | `void` | Add reference |
| `removeReference(String referenceId)` | `void` | Remove reference |
| `dispose()` | `void` | Dispose resources |

---

### ReplayViewModel<T>

An abstract `ViewModel` with automatic history tracking.

```dart
abstract class ReplayViewModel<T> extends ViewModel<T>
    with ReplayHistoryMixin<T>
```

#### Constructor

```dart
ReplayViewModel(
  T initialState, {
  int historyLimit = 100,
  Duration? debounceHistory,
  void Function(bool canUndo)? onCanUndoChanged,
  void Function(bool canRedo)? onCanRedoChanged,
})
```

#### Required Override

```dart
@override
void init() {
  // Synchronous initialization
}
```

#### Properties (inherited + mixin)

| Property | Type | Description |
|----------|------|-------------|
| `data` | `T` | Current state |
| `isDisposed` | `bool` | Disposal status |
| `hasInitializedListenerExecution` | `bool` | Init complete |
| `activeListenerCount` | `int` | Active listeners |
| `canUndo` | `bool` | Undo available |
| `canRedo` | `bool` | Redo available |
| `historyLength` | `int` | History size |
| `currentHistoryIndex` | `int` | Current index |
| `isPerformingUndoRedo` | `bool` | Undo/redo in progress |

#### Methods

All methods from `ViewModel<T>` plus:

| Method | Return | Description |
|--------|--------|-------------|
| `undo()` | `void` | Undo last change |
| `redo()` | `void` | Redo undone change |
| `clearHistory([T? currentState])` | `void` | Clear history |
| `jumpToHistory(int index)` | `void` | Jump to index |
| `peekHistory(int index)` | `T?` | Get state at index |

---

### ReplayAsyncViewModelImpl<T>

An abstract `AsyncViewModelImpl` with history for success states only.

```dart
abstract class ReplayAsyncViewModelImpl<T> extends AsyncViewModelImpl<T>
    with ReplayHistoryMixin<T>
```

#### Constructor

```dart
ReplayAsyncViewModelImpl(
  AsyncState<T> initialState, {
  int historyLimit = 100,
  Duration? debounceHistory,
  void Function(bool canUndo)? onCanUndoChanged,
  void Function(bool canRedo)? onCanRedoChanged,
  bool loadOnInit = true,
  bool waitForContext = false,
})
```

#### Required Override

```dart
@override
Future<T> init() async {
  // Asynchronous initialization
  return await loadData();
}
```

#### Properties (inherited + mixin)

| Property | Type | Description |
|----------|------|-------------|
| `isLoading` | `bool` | Loading state |
| `hasData` | `bool` | Has data |
| `error` | `Object?` | Current error |
| `stackTrace` | `StackTrace?` | Error stack trace |
| `data` | `T` | Current data |
| `canUndo` | `bool` | Undo available |
| `canRedo` | `bool` | Redo available |
| `historyLength` | `int` | History size |
| `currentHistoryIndex` | `int` | Current index |
| `isPerformingUndoRedo` | `bool` | Undo/redo in progress |

#### Methods

All methods from `AsyncViewModelImpl<T>` plus:

| Method | Return | Description |
|--------|--------|-------------|
| `undo()` | `void` | Undo last success state |
| `redo()` | `void` | Redo undone success state |
| `clearHistory([T? currentState])` | `void` | Clear history |
| `jumpToHistory(int index)` | `void` | Jump to index |
| `peekHistory(int index)` | `T?` | Get data at index |

---

### ReplayHistoryMixin<T>

A mixin providing reusable history tracking.

```dart
mixin ReplayHistoryMixin<T>
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `canUndo` | `bool` | Index > 0 |
| `canRedo` | `bool` | Index < length - 1 |
| `historyLength` | `int` | `_history.length` |
| `currentHistoryIndex` | `int` | `_currentIndex` |
| `isPerformingUndoRedo` | `bool` | `_isUndoRedo` |
| `historyLimit` | `int` | From config |
| `debounceHistory` | `Duration?` | From config |
| `historyLogName` | `String` | Log name (override) |

#### Protected Methods

| Method | Description |
|--------|-------------|
| `initializeHistory(config)` | Initialize config |
| `recordInitialState(state)` | Record initial state |
| `handleStateChangeForHistory(state)` | Handle change with debounce |
| `applyHistoricalState(state)` | **Abstract** - apply state |
| `disposeHistory()` | Clean up timers |

#### Public Methods

| Method | Return | Description |
|--------|--------|-------------|
| `undo()` | `void` | Go back in history |
| `redo()` | `void` | Go forward in history |
| `clearHistory([T? currentState])` | `void` | Clear history |
| `jumpToHistory(int index)` | `void` | Jump to index |
| `peekHistory(int index)` | `T?` | Peek at index |

---

### ReplayHistoryConfig

Configuration for history tracking.

```dart
class ReplayHistoryConfig {
  final int historyLimit;
  final Duration? debounceHistory;
  final void Function(bool canUndo)? onCanUndoChanged;
  final void Function(bool canRedo)? onCanRedoChanged;

  const ReplayHistoryConfig({
    this.historyLimit = 100,
    this.debounceHistory,
    this.onCanUndoChanged,
    this.onCanRedoChanged,
  });
}
```

---

## Type Definitions

### Factory Function

```dart
typedef T Function() create
```

### Transform Function

```dart
typedef T Function(T data) transform
```

### Availability Callback

```dart
typedef void Function(bool available) onCanUndoChanged
typedef void Function(bool available) onCanRedoChanged
```

---

## Constants

### Default Values

| Constant | Value | Description |
|----------|-------|-------------|
| Default `historyLimit` | `100` | Maximum states |
| Default `debounceHistory` | `null` | No debounce |
| Default `autoDispose` | `false` | No auto-dispose |
| Default `loadOnInit` | `true` | Auto-load async |
| Default `waitForContext` | `false` | Don't wait |

---

## Exceptions

### StateError

Thrown when accessing disposed components or invalid operations.

```dart
// Example: Accessing after dispose
notifier.dispose();
notifier.updateState(newValue); // Throws StateError
```

---

## Debug Logging

All components log operations in debug mode using `dart:developer`:

```dart
// Logs for ReplayReactiveNotifier
'ReplayReactiveNotifier<T>: Created with historyLimit=100'
'ReplayReactiveNotifier<T>: Recorded state at index 5 (total: 6)'
'ReplayReactiveNotifier<T>: Undo to index 4'
'ReplayReactiveNotifier<T>: Redo to index 5'
'ReplayReactiveNotifier<T>: History cleared'
'ReplayReactiveNotifier<T>: Jumped to index 2'
```

Logging only occurs in debug mode (inside `assert(() {...}())`).
