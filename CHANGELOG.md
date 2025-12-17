# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.16.0] - 2024-12-11

### Initial Release - Undo/Redo for ReactiveNotifier

This is the initial release of `reactive_notifier_replay`, providing undo/redo functionality for ReactiveNotifier state management.

#### Features

- **ReplayReactiveNotifier**: Wrapper around ReactiveNotifier with history tracking
- **ReplayViewModel**: ViewModel extension with automatic state history
- **ReplayAsyncViewModelImpl**: AsyncViewModelImpl extension (tracks only success states)
- **ReplayHistoryMixin**: Shared mixin for custom implementations

#### Capabilities

- Undo/Redo navigation through state history
- Configurable history limit
- Debounce support for grouping rapid changes
- Availability callbacks (onCanUndoChanged, onCanRedoChanged)
- Jump to any point in history
- Peek historical states without changing current state

#### Integration

- Fully compatible with ReactiveNotifier 2.16.0
- Uses onStateChanged/onAsyncStateChanged hooks
- Follows ReactiveNotifier patterns and conventions

#### Usage Example

```dart
// Simple state with undo/redo
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

// Complex state with debouncing
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

### Dependencies

- Requires `reactive_notifier: ^2.16.0`
- Compatible with Flutter SDK >=1.17.0
