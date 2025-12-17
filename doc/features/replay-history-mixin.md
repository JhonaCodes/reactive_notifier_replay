# ReplayHistoryMixin<T>

A mixin that provides reusable undo/redo history tracking functionality for custom implementations.

## Overview

`ReplayHistoryMixin<T>` encapsulates all shared logic for managing state history with undo/redo capabilities. It can be used with any class that manages state of type `T`.

## When to Use

| Scenario | Use ReplayHistoryMixin<T> |
|----------|---------------------------|
| Custom state management classes | Yes |
| Integrating with existing classes | Yes |
| Maximum flexibility needed | Yes |
| Building your own replay components | Yes |
| Standard use cases | No (use built-in components) |

## Configuration Class

```dart
class ReplayHistoryConfig {
  /// Maximum number of states to keep in history.
  final int historyLimit;

  /// Optional debounce duration for grouping rapid state changes.
  final Duration? debounceHistory;

  /// Callback when undo availability changes.
  final void Function(bool canUndo)? onCanUndoChanged;

  /// Callback when redo availability changes.
  final void Function(bool canRedo)? onCanRedoChanged;

  const ReplayHistoryConfig({
    this.historyLimit = 100,
    this.debounceHistory,
    this.onCanUndoChanged,
    this.onCanRedoChanged,
  });
}
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `canUndo` | `bool` | Whether undo is available |
| `canRedo` | `bool` | Whether redo is available |
| `historyLength` | `int` | Current number of states in history |
| `currentHistoryIndex` | `int` | Current position in history (0-indexed) |
| `isPerformingUndoRedo` | `bool` | Whether undo/redo operation is in progress |
| `historyLimit` | `int` | Maximum number of states to keep |
| `debounceHistory` | `Duration?` | Debounce duration |
| `historyLogName` | `String` | Name used in debug logs (override for custom name) |

## Protected Methods (for implementers)

| Method | Description |
|--------|-------------|
| `initializeHistory(config)` | Initialize with configuration (call in constructor) |
| `recordInitialState(state)` | Record initial state (call in constructor) |
| `handleStateChangeForHistory(state)` | Handle state change with debouncing |
| `applyHistoricalState(state)` | Abstract - implement to apply state |
| `disposeHistory()` | Clean up timers (call in dispose) |

## Public Methods

| Method | Return | Description |
|--------|--------|-------------|
| `undo()` | `void` | Undoes the last state change |
| `redo()` | `void` | Redoes the previously undone change |
| `clearHistory([T? currentState])` | `void` | Clears history |
| `jumpToHistory(int index)` | `void` | Jumps to specific index |
| `peekHistory(int index)` | `T?` | Gets state at index without changing |

## Implementation Guide

### Step 1: Create Class with Mixin

```dart
class MyReplayClass with ReplayHistoryMixin<MyState> {
  MyState _internalState;

  @override
  String get historyLogName => 'MyReplayClass';

  MyReplayClass({
    required MyState initialState,
    int historyLimit = 100,
    Duration? debounceHistory,
    void Function(bool)? onCanUndoChanged,
    void Function(bool)? onCanRedoChanged,
  }) : _internalState = initialState {
    // Step 2: Initialize history configuration
    initializeHistory(ReplayHistoryConfig(
      historyLimit: historyLimit,
      debounceHistory: debounceHistory,
      onCanUndoChanged: onCanUndoChanged,
      onCanRedoChanged: onCanRedoChanged,
    ));

    // Step 3: Record initial state
    recordInitialState(initialState);
  }

  // Current state getter
  MyState get state => _internalState;

  // Step 4: Call handleStateChangeForHistory on state changes
  void updateState(MyState newState) {
    if (!isPerformingUndoRedo) {
      _internalState = newState;
      handleStateChangeForHistory(newState);
      // notifyListeners() if using ChangeNotifier
    }
  }

  // Step 5: Implement applyHistoricalState
  @override
  void applyHistoricalState(MyState state) {
    _internalState = state;
    // notifyListeners() if using ChangeNotifier
  }

  // Step 6: Clean up in dispose
  void dispose() {
    disposeHistory();
    // super.dispose() if extending another class
  }
}
```

### Step 2: Handle State Changes

```dart
void onMyStateChanged(MyState newState) {
  // Always check isPerformingUndoRedo to prevent double recording
  if (!isPerformingUndoRedo) {
    handleStateChangeForHistory(newState);
  }
}
```

### Step 3: Implement applyHistoricalState

```dart
@override
void applyHistoricalState(MyState state) {
  // This is called by undo(), redo(), and jumpToHistory()
  // Apply the state to your actual state holder
  _internalState = state;

  // Notify listeners if needed
  notifyListeners();
}
```

## Complete Example

```dart
import 'package:flutter/foundation.dart';
import 'package:reactive_notifier_replay/reactive_notifier_replay.dart';

class CustomEditorState {
  final String text;
  final int cursorPosition;

  const CustomEditorState({this.text = '', this.cursorPosition = 0});

  CustomEditorState copyWith({String? text, int? cursorPosition}) {
    return CustomEditorState(
      text: text ?? this.text,
      cursorPosition: cursorPosition ?? this.cursorPosition,
    );
  }
}

class CustomEditorController extends ChangeNotifier
    with ReplayHistoryMixin<CustomEditorState> {
  CustomEditorState _state;

  @override
  String get historyLogName => 'CustomEditorController';

  CustomEditorController({
    CustomEditorState? initialState,
    int historyLimit = 100,
    Duration? debounceHistory,
  }) : _state = initialState ?? const CustomEditorState() {
    // Initialize history
    initializeHistory(ReplayHistoryConfig(
      historyLimit: historyLimit,
      debounceHistory: debounceHistory,
      onCanUndoChanged: (canUndo) {
        notifyListeners(); // Trigger rebuild for undo button state
      },
      onCanRedoChanged: (canRedo) {
        notifyListeners(); // Trigger rebuild for redo button state
      },
    ));

    // Record initial state
    recordInitialState(_state);
  }

  CustomEditorState get state => _state;

  void setText(String text) {
    _state = _state.copyWith(text: text);

    // Record in history (with debounce if configured)
    if (!isPerformingUndoRedo) {
      handleStateChangeForHistory(_state);
    }

    notifyListeners();
  }

  void setCursorPosition(int position) {
    // Don't record cursor position in history
    _state = _state.copyWith(cursorPosition: position);
    notifyListeners();
  }

  @override
  @protected
  void applyHistoricalState(CustomEditorState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    disposeHistory();
    super.dispose();
  }
}

// Usage
void main() {
  final controller = CustomEditorController(
    historyLimit: 50,
    debounceHistory: Duration(milliseconds: 300),
  );

  controller.setText('Hello');
  controller.setText('Hello World');

  print(controller.canUndo); // true
  print(controller.historyLength); // 3 (initial + 2 changes, or less with debounce)

  controller.undo();
  print(controller.state.text); // 'Hello' (or initial if debounced)

  controller.redo();
  print(controller.state.text); // 'Hello World'

  controller.dispose();
}
```

## Integration with Existing Classes

### With ChangeNotifier

```dart
class MyNotifier extends ChangeNotifier with ReplayHistoryMixin<MyState> {
  MyState _state;

  MyNotifier(this._state) {
    initializeHistory(ReplayHistoryConfig(historyLimit: 100));
    recordInitialState(_state);
  }

  MyState get state => _state;

  void updateState(MyState newState) {
    _state = newState;
    if (!isPerformingUndoRedo) {
      handleStateChangeForHistory(newState);
    }
    notifyListeners();
  }

  @override
  void applyHistoricalState(MyState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    disposeHistory();
    super.dispose();
  }
}
```

### With ValueNotifier

```dart
class ReplayValueNotifier<T> extends ValueNotifier<T>
    with ReplayHistoryMixin<T> {

  ReplayValueNotifier(T value, {int historyLimit = 100}) : super(value) {
    initializeHistory(ReplayHistoryConfig(historyLimit: historyLimit));
    recordInitialState(value);
  }

  @override
  set value(T newValue) {
    super.value = newValue;
    if (!isPerformingUndoRedo) {
      handleStateChangeForHistory(newValue);
    }
  }

  @override
  void applyHistoricalState(T state) {
    super.value = state;
  }

  @override
  void dispose() {
    disposeHistory();
    super.dispose();
  }
}
```

## How the Mixin Works Internally

### History Recording

```dart
void _recordHistory(T state) {
  // Track previous availability
  final previousCanUndo = canUndo;
  final previousCanRedo = canRedo;

  // Clear redo history when new state is added (branching)
  if (_currentIndex < _history.length - 1) {
    _history.removeRange(_currentIndex + 1, _history.length);
  }

  // Add new state
  _history.add(state);
  _currentIndex++;

  // Enforce history limit
  if (_history.length > historyLimit) {
    _history.removeAt(0);
    _currentIndex--;
  }

  // Notify if availability changed
  if (canUndo != previousCanUndo) {
    onCanUndoChanged?.call(canUndo);
  }
  if (canRedo != previousCanRedo) {
    onCanRedoChanged?.call(canRedo);
  }
}
```

### Undo/Redo Operation

```dart
void undo() {
  if (!canUndo) return;

  _isUndoRedo = true;           // Prevent recording
  _currentIndex--;              // Move back
  applyHistoricalState(_history[_currentIndex]); // Apply state
  _isUndoRedo = false;          // Re-enable recording

  // Notify availability changes
}
```

## Related Documentation

- [ReplayReactiveNotifier](replay-reactive-notifier.md) - Pre-built simple state
- [ReplayViewModel](replay-viewmodel.md) - Pre-built complex state
- [ReplayAsyncViewModelImpl](replay-async-viewmodel.md) - Pre-built async state
- [Best Practices](../guides/best-practices.md) - Recommended patterns
