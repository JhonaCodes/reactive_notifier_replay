# ReplayReactiveNotifier<T>

A wrapper around `ReactiveNotifier` that provides undo/redo functionality for simple state values.

## Overview

`ReplayReactiveNotifier<T>` wraps a standard `ReactiveNotifier<T>` and adds automatic state history tracking with undo/redo capabilities. It is ideal for simple state values that need history tracking.

## When to Use

| Scenario | Use ReplayReactiveNotifier<T> |
|----------|-------------------------------|
| Simple state values (int, bool, String) | Yes |
| Settings with undo support | Yes |
| Game scores or counters | Yes |
| State without initialization logic | Yes |
| Complex business logic needed | No (use ReplayViewModel) |
| Async data loading | No (use ReplayAsyncViewModelImpl) |

## Basic Usage

```dart
// Define service with replay-enabled notifier
mixin EditorService {
  static final textState = ReplayReactiveNotifier<TextState>(
    create: () => TextState.empty(),
    historyLimit: 50,
  );
}

// Update state (automatically recorded in history)
EditorService.textState.updateState(TextState(text: 'Hello'));

// Undo/Redo
EditorService.textState.undo();
EditorService.textState.redo();
```

## Constructor Parameters

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

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `notifier` | `T` | Current state value |
| `keyNotifier` | `Key` | The key used by the inner ReactiveNotifier |
| `canUndo` | `bool` | Whether undo is available |
| `canRedo` | `bool` | Whether redo is available |
| `historyLength` | `int` | Current number of states in history |
| `currentHistoryIndex` | `int` | Current position in history (0-indexed) |
| `isPerformingUndoRedo` | `bool` | Whether an undo/redo operation is in progress |
| `historyLimit` | `int` | Maximum number of states to keep |
| `debounceHistory` | `Duration?` | Debounce duration for history |

## Methods

### History Methods

| Method | Return | Description |
|--------|--------|-------------|
| `undo()` | `void` | Undoes the last state change |
| `redo()` | `void` | Redoes the previously undone change |
| `clearHistory([T? currentState])` | `void` | Clears history, keeping current or specified state |
| `jumpToHistory(int index)` | `void` | Jumps to specific index in history |
| `peekHistory(int index)` | `T?` | Gets state at index without changing current state |

### State Management Methods

| Method | Notifies | Records History | Description |
|--------|----------|-----------------|-------------|
| `updateState(T newState)` | Yes | Yes | Updates state with notification |
| `updateSilently(T newState)` | No | Yes | Updates without notification |
| `transformState(T Function(T) transform)` | Yes | Yes | Transforms state with notification |
| `transformStateSilently(T Function(T) transform)` | No | Yes | Transforms without notification |
| `recreate()` | Yes | Clears | Recreates state using factory, clears history |

### Listener Methods

| Method | Return | Description |
|--------|--------|-------------|
| `listen(void Function(T) callback)` | `T` | Listens to state changes |
| `stopListening()` | `void` | Stops listening for changes |

### Reference Management

| Method | Description |
|--------|-------------|
| `addReference(String referenceId)` | Adds reference for auto-dispose |
| `removeReference(String referenceId)` | Removes reference |

## Examples

### With Debounce (for text editors)

```dart
final textState = ReplayReactiveNotifier<TextState>(
  create: () => TextState.empty(),
  historyLimit: 100,
  debounceHistory: Duration(milliseconds: 300), // Group rapid changes
);
```

### With Availability Callbacks

```dart
final state = ReplayReactiveNotifier<int>(
  create: () => 0,
  historyLimit: 50,
  onCanUndoChanged: (canUndo) {
    print('Can undo: $canUndo');
    // Update UI button state
  },
  onCanRedoChanged: (canRedo) {
    print('Can redo: $canRedo');
    // Update UI button state
  },
);
```

### UI Integration

```dart
ReactiveBuilder<TextState>(
  notifier: EditorService.textState,
  build: (state, notifier, keep) => Column(
    children: [
      Text(state.text),
      Row(
        children: [
          IconButton(
            onPressed: EditorService.textState.canUndo
              ? EditorService.textState.undo
              : null,
            icon: Icon(Icons.undo),
          ),
          IconButton(
            onPressed: EditorService.textState.canRedo
              ? EditorService.textState.redo
              : null,
            icon: Icon(Icons.redo),
          ),
        ],
      ),
    ],
  ),
)
```

### History Timeline

```dart
Widget buildTimeline<T>(ReplayReactiveNotifier<T> notifier) {
  return ListView.builder(
    scrollDirection: Axis.horizontal,
    itemCount: notifier.historyLength,
    itemBuilder: (context, index) {
      final isCurrentState = index == notifier.currentHistoryIndex;
      return GestureDetector(
        onTap: () => notifier.jumpToHistory(index),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrentState ? Colors.blue : Colors.grey,
          ),
        ),
      );
    },
  );
}
```

## History Behavior

### Recording

1. Initial state is recorded when created
2. Each `updateState` or `transformState` call records a new entry
3. Silent updates (`updateSilently`, `transformStateSilently`) also record
4. Debounce groups rapid changes into single entries

### Undo/Redo

1. `undo()` moves back in history (decrements index)
2. `redo()` moves forward in history (increments index)
3. New state after undo clears redo history (creates new branch)
4. History limit enforces maximum entries (oldest removed first)

```
History: [A, B, C, D, E]
                    ^
                 current (index 4)

After undo():
History: [A, B, C, D, E]
               ^
            current (index 3)

After new state F:
History: [A, B, C, D, F]  // E removed, F added
                    ^
                 current (index 4)
```

## Related Documentation

- [ReplayViewModel](replay-viewmodel.md) - For complex state with business logic
- [ReplayAsyncViewModelImpl](replay-async-viewmodel.md) - For async operations
- [ReplayHistoryMixin](replay-history-mixin.md) - For custom implementations
- [Best Practices](../guides/best-practices.md) - Recommended patterns
