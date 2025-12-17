# Migration Guide

Migrating from manual history tracking to ReactiveNotifier Replay.

## From Manual History Tracking

### Before: Manual Implementation

```dart
class ManualHistoryViewModel extends ChangeNotifier {
  final List<DocumentState> _history = [];
  int _currentIndex = -1;
  DocumentState _state;

  ManualHistoryViewModel(this._state) {
    _recordHistory(_state);
  }

  DocumentState get state => _state;
  bool get canUndo => _currentIndex > 0;
  bool get canRedo => _currentIndex < _history.length - 1;

  void _recordHistory(DocumentState state) {
    // Clear redo history
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }
    _history.add(state);
    _currentIndex++;

    // Enforce limit
    if (_history.length > 100) {
      _history.removeAt(0);
      _currentIndex--;
    }
  }

  void updateContent(String content) {
    _state = _state.copyWith(content: content);
    _recordHistory(_state);
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _currentIndex--;
    _state = _history[_currentIndex];
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _currentIndex++;
    _state = _history[_currentIndex];
    notifyListeners();
  }
}
```

### After: ReplayViewModel

```dart
class DocumentViewModel extends ReplayViewModel<DocumentState> {
  DocumentViewModel() : super(
    DocumentState.empty(),
    historyLimit: 100,
  );

  @override
  void init() {}

  void updateContent(String content) {
    transformState((state) => state.copyWith(content: content));
    // History automatically recorded via onStateChanged hook
  }

  // undo() and redo() are inherited from ReplayHistoryMixin
}
```

### Migration Steps

1. **Extend ReplayViewModel** instead of ChangeNotifier
2. **Remove manual history fields**: `_history`, `_currentIndex`
3. **Remove manual `_recordHistory` method**
4. **Remove manual `undo()` and `redo()` implementations**
5. **Replace state updates** with `transformState()`
6. **Add `init()` override** for initialization logic
7. **Configure constructor** with `historyLimit`

---

## From Custom ChangeNotifier

### Before: Custom ChangeNotifier with History

```dart
class EditorNotifier extends ChangeNotifier {
  final int maxHistory;
  final List<String> _history;
  int _historyIndex;
  String _content;

  EditorNotifier({
    this.maxHistory = 50,
    String initialContent = '',
  }) : _content = initialContent,
       _history = [initialContent],
       _historyIndex = 0;

  String get content => _content;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  void setContent(String value) {
    if (value == _content) return;

    // Remove future history
    while (_history.length > _historyIndex + 1) {
      _history.removeLast();
    }

    _history.add(value);
    _historyIndex = _history.length - 1;

    // Enforce limit
    while (_history.length > maxHistory) {
      _history.removeAt(0);
      _historyIndex--;
    }

    _content = value;
    notifyListeners();
  }

  void undo() {
    if (canUndo) {
      _historyIndex--;
      _content = _history[_historyIndex];
      notifyListeners();
    }
  }

  void redo() {
    if (canRedo) {
      _historyIndex++;
      _content = _history[_historyIndex];
      notifyListeners();
    }
  }
}
```

### After: ReplayReactiveNotifier

```dart
mixin EditorService {
  static final content = ReplayReactiveNotifier<String>(
    create: () => '',
    historyLimit: 50,
  );

  static void setContent(String value) {
    content.updateState(value);
  }
}
```

Or for more control:

```dart
class EditorViewModel extends ReplayViewModel<EditorState> {
  EditorViewModel() : super(
    EditorState.empty(),
    historyLimit: 50,
  );

  @override
  void init() {}

  void setContent(String value) {
    if (value == data.content) return;
    transformState((state) => state.copyWith(content: value));
  }
}
```

---

## From BLoC/Cubit with replay_bloc

### Before: replay_bloc

```dart
class CounterCubit extends ReplayCubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}

// Usage
BlocBuilder<CounterCubit, int>(
  builder: (context, state) {
    return Column(
      children: [
        Text('$state'),
        IconButton(
          onPressed: context.read<CounterCubit>().canUndo
            ? context.read<CounterCubit>().undo
            : null,
          icon: Icon(Icons.undo),
        ),
      ],
    );
  },
)
```

### After: ReplayReactiveNotifier

```dart
mixin CounterService {
  static final counter = ReplayReactiveNotifier<int>(
    create: () => 0,
    historyLimit: 100,
  );

  static void increment() => counter.updateState(counter.notifier + 1);
  static void decrement() => counter.updateState(counter.notifier - 1);
}

// Usage
ReactiveBuilder<int>(
  notifier: CounterService.counter,
  build: (state, notifier, keep) {
    return Column(
      children: [
        Text('$state'),
        IconButton(
          onPressed: CounterService.counter.canUndo
            ? CounterService.counter.undo
            : null,
          icon: Icon(Icons.undo),
        ),
      ],
    );
  },
)
```

### Key Differences

| replay_bloc | ReactiveNotifier Replay |
|-------------|------------------------|
| `emit(state)` | `updateState(state)` |
| `context.read<Cubit>()` | `Service.notifier` |
| `BlocBuilder` | `ReactiveBuilder` |
| `ReplayCubit` | `ReplayReactiveNotifier` / `ReplayViewModel` |
| Scoped to widget tree | Singleton pattern |

---

## From Provider with Manual History

### Before: Provider + History

```dart
class HistoryProvider extends ChangeNotifier {
  final List<AppState> _history = [];
  int _index = -1;
  AppState _state;

  HistoryProvider() : _state = AppState.initial() {
    _record(_state);
  }

  AppState get state => _state;
  bool get canUndo => _index > 0;
  bool get canRedo => _index < _history.length - 1;

  void _record(AppState s) { /* ... */ }
  void update(AppState s) { /* ... */ }
  void undo() { /* ... */ }
  void redo() { /* ... */ }
}

// Usage
ChangeNotifierProvider(
  create: (_) => HistoryProvider(),
  child: Consumer<HistoryProvider>(
    builder: (context, provider, child) {
      return Text('${provider.state}');
    },
  ),
)
```

### After: ReplayViewModel

```dart
class AppViewModel extends ReplayViewModel<AppState> {
  AppViewModel() : super(AppState.initial());

  @override
  void init() {}

  void update(AppState newState) {
    updateState(newState);
  }
}

mixin AppService {
  static final app = ReactiveNotifier<AppViewModel>(
    () => AppViewModel(),
  );
}

// Usage - no provider wrapper needed
ReactiveViewModelBuilder<AppViewModel, AppState>(
  viewmodel: AppService.app.notifier,
  build: (state, viewModel, keep) {
    return Text('$state');
  },
)
```

---

## Feature Comparison

| Feature | Manual | replay_bloc | ReactiveNotifier Replay |
|---------|--------|-------------|------------------------|
| History limit | Manual | Yes | Yes |
| Debounce | Manual | No | Yes (built-in) |
| Jump to history | Manual | No | Yes |
| Peek history | Manual | No | Yes |
| Availability callbacks | Manual | Yes | Yes |
| Async support | Manual | Events | Success states only |
| Service pattern | N/A | BlocProvider | Mixin singletons |
| Boilerplate | High | Medium | Low |

---

## Gradual Migration Strategy

### Step 1: Add Package
```yaml
dependencies:
  reactive_notifier_replay: ^1.0.0
```

### Step 2: Create Parallel Implementation
```dart
// Keep old implementation
class OldDocumentViewModel { /* ... */ }

// Create new implementation
class NewDocumentViewModel extends ReplayViewModel<DocumentState> {
  NewDocumentViewModel() : super(DocumentState.empty());
  @override
  void init() {}
}
```

### Step 3: Test New Implementation
```dart
test('new implementation matches old behavior', () {
  final oldVM = OldDocumentViewModel();
  final newVM = NewDocumentViewModel();

  oldVM.updateContent('Hello');
  newVM.transformState((s) => s.copyWith(content: 'Hello'));

  expect(oldVM.canUndo, equals(newVM.canUndo));

  oldVM.undo();
  newVM.undo();

  expect(oldVM.state.content, equals(newVM.data.content));
});
```

### Step 4: Migrate Screens One at a Time
```dart
// Old screen
class OldEditorScreen extends StatelessWidget {
  Widget build(context) {
    return Consumer<OldDocumentViewModel>(/* ... */);
  }
}

// New screen
class NewEditorScreen extends StatelessWidget {
  Widget build(context) {
    return ReactiveViewModelBuilder<NewDocumentViewModel, DocumentState>(
      viewmodel: DocumentService.document.notifier,
      build: (state, viewModel, keep) { /* ... */ },
    );
  }
}
```

### Step 5: Remove Old Implementation
Once all screens are migrated, remove the old implementation.

---

## Common Migration Issues

### Issue: Different Notification Timing

**Old code** might notify at different times.

**Solution**: Ensure `notifyListeners()` equivalent happens at same points:
- `updateState()` notifies automatically
- `updateSilently()` does not notify
- `transformState()` notifies automatically
- `transformStateSilently()` does not notify

### Issue: History Recorded Differently

**Old code** might record history on different events.

**Solution**: Use `onStateChanged` hook behavior:
- All state changes via `updateState`/`transformState` record history
- Use silent methods to skip recording

### Issue: Missing Features

**Old code** might have features not in the library.

**Solution**: Use `ReplayHistoryMixin` to create custom implementation:
```dart
class CustomReplayClass with ReplayHistoryMixin<MyState> {
  // Custom behavior
}
```
