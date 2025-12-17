# reactive_notifier_replay - AI/Development Context Guide

## Quick Context

- **Version**: 1.0.0
- **Pattern**: Extension of ReactiveNotifier with undo/redo history tracking
- **Architecture**: Wrapper and extension pattern with shared mixin functionality
- **Core Concept**: Time-travel debugging for state management
- **Dependency**: Requires reactive_notifier ^2.16.0
- **Key Feature**: Leverages onStateChanged/onAsyncStateChanged hooks for automatic history tracking

## Core Components

### ReplayReactiveNotifier<T>

**Purpose**: Wrapper around ReactiveNotifier that adds undo/redo functionality
**When to use**: Simple state values that need history tracking
**Key methods**: `undo()`, `redo()`, `clearHistory()`, `jumpToHistory()`, `peekHistory()`
**Properties**: `canUndo`, `canRedo`, `historyLength`, `currentHistoryIndex`, `isPerformingUndoRedo`

```dart
// Basic pattern - wrapper approach
mixin ServiceName {
  static final ReplayReactiveNotifier<Type> stateName = ReplayReactiveNotifier<Type>(
    create: () => initialValue,
    historyLimit: 100,
    debounceHistory: Duration(milliseconds: 300), // Optional
  );
}
```

### ReplayViewModel<T> (extends ViewModel<T>)

**Purpose**: Complex state with business logic and automatic history tracking
**When to use**: State that requires validation, complex operations, AND undo/redo support
**Key methods**: All ViewModel methods plus history methods from ReplayHistoryMixin
**Integration**: Uses `onStateChanged` hook automatically - no manual recording needed

```dart
class MyReplayViewModel extends ReplayViewModel<MyModel> {
  MyReplayViewModel() : super(
    MyModel.initial(),
    historyLimit: 100,
    debounceHistory: Duration(milliseconds: 300),
  );

  @override
  void init() {
    // Called once when created (MUST be synchronous)
    // History recording happens automatically via onStateChanged hook
  }
}
```

### ReplayAsyncViewModelImpl<T> (extends AsyncViewModelImpl<T>)

**Purpose**: Async operations with history tracking for SUCCESS STATES ONLY
**When to use**: API calls, database operations that need undo/redo on data changes
**Key methods**: All AsyncViewModelImpl methods plus history methods
**Important**: Loading, error, and initial states are NOT tracked - only success states
**States**: Uses `AsyncState.initial()`, `loading()`, `success(data)`, `error(error)`

```dart
class DataViewModel extends ReplayAsyncViewModelImpl<List<Item>> {
  DataViewModel() : super(
    AsyncState.initial(),
    historyLimit: 50,
    loadOnInit: true,
  );

  @override
  Future<List<Item>> init() async {
    // Called once when created (MUST be asynchronous)
    return await repository.getData();
  }
}
```

### ReplayHistoryMixin<T>

**Purpose**: Shared history tracking functionality for custom implementations
**When to use**: Building custom replay-enabled classes or integrating with existing architecture
**Configuration**: Uses `ReplayHistoryConfig` for all settings

```dart
class ReplayHistoryConfig {
  final int historyLimit;           // Maximum states to keep (default: 100)
  final Duration? debounceHistory;  // Group rapid changes (default: null)
  final void Function(bool)? onCanUndoChanged;  // Callback for UI updates
  final void Function(bool)? onCanRedoChanged;  // Callback for UI updates
}
```

## Builder Components (Compatible with ReactiveNotifier)

### ReactiveBuilder<T>

**Use case**: ReplayReactiveNotifier with simple state

```dart
ReactiveBuilder<int>(
  notifier: CounterService.counter,
  build: (value, notifier, keep) => Text('$value'),
)
```

### ReactiveViewModelBuilder<VM, T>

**Use case**: ReplayViewModel with complex state

```dart
ReactiveViewModelBuilder<DocumentViewModel, DocumentState>(
  viewmodel: DocumentService.document.notifier,
  build: (state, viewmodel, keep) => Text(state.content),
)
```

### ReactiveAsyncBuilder<VM, T>

**Use case**: ReplayAsyncViewModelImpl with loading/error states

```dart
ReactiveAsyncBuilder<DataViewModel, List<Item>>(
  notifier: DataService.items.notifier,
  onData: (items, viewModel, keep) => ListView(...),
  onLoading: () => CircularProgressIndicator(),
  onError: (error, stack) => Text('Error: $error'),
)
```

## Decision Tree

### Choose ReplayReactiveNotifier<T> when

- Simple state values (int, bool, String, enums)
- Settings with undo support
- Game scores or counters
- State doesn't require initialization logic
- Need a direct wrapper with minimal boilerplate

### Choose ReplayViewModel<T> when

- Complex state objects with business logic
- Text editors with debounced history
- Form state with validation
- State requires synchronous initialization
- Need full ViewModel lifecycle with history

### Choose ReplayAsyncViewModelImpl<T> when

- Loading data from external sources
- Need loading/error state handling
- API calls or database operations
- When only SUCCESS states should be tracked
- CRUD operations where users can undo deletions

### Choose ReplayHistoryMixin<T> when

- Custom state management implementations
- Integrating with existing classes
- Need maximum flexibility
- Building your own replay-enabled components

## Mandatory Patterns

### 1. Mixin Organization (Same as ReactiveNotifier)

```dart
// ALWAYS use mixins for services
mixin EditorService {
  static final document = ReactiveNotifier<DocumentViewModel>(
    () => DocumentViewModel(),
  );

  static void undo() => document.notifier.undo();
  static void redo() => document.notifier.redo();
  static bool get canUndo => document.notifier.canUndo;
  static bool get canRedo => document.notifier.canRedo;
}

// NEVER use global variables
// final document = ReactiveNotifier<DocumentViewModel>(...); // Wrong!
```

### 2. History Recording (All Available Methods)

```dart
// For ReplayReactiveNotifier<T>
notifier.updateState(newValue);              // Records in history + notifies
notifier.updateSilently(newValue);           // Records in history (no notify)
notifier.transformState((v) => transform(v)); // Records in history + notifies
notifier.transformStateSilently((v) => transform(v)); // Records in history (no notify)

// For ReplayViewModel<T> - uses onStateChanged hook
viewModel.updateState(newState);             // Records via hook + notifies
viewModel.updateSilently(newState);          // Records via hook (no notify)
viewModel.transformState((s) => s.copyWith(...)); // Records via hook + notifies
viewModel.transformStateSilently((s) => s.copyWith(...)); // Records via hook (no notify)

// For ReplayAsyncViewModelImpl<T> - uses onAsyncStateChanged hook
asyncVM.updateState(data);                   // Records SUCCESS state + notifies
asyncVM.transformDataState((d) => modified); // Records SUCCESS state + notifies
asyncVM.loadingState();                      // NOT recorded (not success state)
asyncVM.errorState('Error');                 // NOT recorded (not success state)
```

### 3. History Navigation Methods

```dart
// Available on all replay-enabled classes
notifier.undo();                    // Go to previous state
notifier.redo();                    // Go to next state
notifier.clearHistory();            // Clear all history, keep current
notifier.clearHistory(specificState); // Clear history, set specific state
notifier.jumpToHistory(index);      // Jump to any point in history
notifier.peekHistory(index);        // View state without changing current
```

### 4. History State Properties

```dart
// Available on all replay-enabled classes
notifier.canUndo;              // bool - true if undo is available
notifier.canRedo;              // bool - true if redo is available
notifier.historyLength;        // int - total states in history
notifier.currentHistoryIndex;  // int - current position (0-indexed)
notifier.isPerformingUndoRedo; // bool - true during undo/redo operation
notifier.historyLimit;         // int - configured maximum history size
notifier.debounceHistory;      // Duration? - configured debounce
```

### 5. Debounce for Text Editors

```dart
class TextEditorViewModel extends ReplayViewModel<TextState> {
  TextEditorViewModel() : super(
    TextState.empty(),
    historyLimit: 100,
    debounceHistory: Duration(milliseconds: 300), // 300ms pause triggers save
  );

  void onTextChanged(String text) {
    // Each keystroke calls this
    // History only records after 300ms pause in typing
    transformState((state) => state.copyWith(text: text));
  }
}
```

### 6. Reactive UI Updates with Callbacks

```dart
final notifier = ReplayReactiveNotifier<MyState>(
  create: () => MyState.initial(),
  onCanUndoChanged: (canUndo) {
    // Update undo button state reactively
    setState(() => _canUndo = canUndo);
  },
  onCanRedoChanged: (canRedo) {
    // Update redo button state reactively
    setState(() => _canRedo = canRedo);
  },
);
```

### 7. Testing Pattern

```dart
setUp(() {
  ReactiveNotifier.cleanup(); // Clear all states between tests
});

test('should support undo/redo', () {
  final notifier = ReplayReactiveNotifier<int>(create: () => 0);

  notifier.updateState(1);
  notifier.updateState(2);

  expect(notifier.notifier, equals(2));
  expect(notifier.canUndo, isTrue);

  notifier.undo();
  expect(notifier.notifier, equals(1));
  expect(notifier.canRedo, isTrue);
});
```

## Anti-Patterns (Never Do)

### 1. Creating instances in widgets

```dart
// NEVER - Creates new instance with empty history every build
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notifier = ReplayReactiveNotifier<int>(create: () => 0);
    return Text('${notifier.notifier}');
  }
}
```

### 2. Forgetting history limit leads to memory issues

```dart
// RISKY - No history limit can cause memory problems
ReplayReactiveNotifier<LargeState>(
  create: () => LargeState(),
  // historyLimit defaults to 100, but for large states consider lower
)

// BETTER - Set appropriate limit based on state size
ReplayReactiveNotifier<LargeState>(
  create: () => LargeState(),
  historyLimit: 20, // Fewer states for larger objects
)
```

### 3. Not clearing history on significant events

```dart
// WRONG - History may contain sensitive data after logout
void logout() {
  UserService.user.notifier.updateState(User.guest());
  // History still contains previous user data!
}

// CORRECT - Clear history on logout
void logout() {
  UserService.user.notifier.updateState(User.guest());
  UserService.user.notifier.clearHistory();
}
```

### 4. Expecting loading/error states to be tracked in async

```dart
// WRONG - These states are NOT in history
class DataViewModel extends ReplayAsyncViewModelImpl<Data> {
  void onError() {
    // User cannot undo to get back to error state
    // Only SUCCESS states are tracked
  }
}
```

### 5. Complex logic in builders (same as ReactiveNotifier)

```dart
// NEVER put business logic in builders
ReactiveBuilder<DocumentState>(
  notifier: DocumentService.document,
  build: (state, notifier, keep) {
    // History calculations here - WRONG
    final canSafelyUndo = notifier.canUndo && !state.isDirty;
    return Widget();
  },
)

// PUT logic in ViewModel
class DocumentViewModel extends ReplayViewModel<DocumentState> {
  bool get canSafelyUndo => canUndo && !data.isDirty;
}
```

## Performance Optimization

### Memory Management via History Limits

```dart
// Text editor - many changes expected, small states
ReplayViewModel<TextState>(historyLimit: 200, ...)

// Image editor - fewer changes, large states
ReplayViewModel<ImageState>(historyLimit: 20, ...)

// Game state - moderate changes
ReplayViewModel<GameState>(historyLimit: 50, ...)
```

### Debounce for Rapid Changes

```dart
// Group rapid typing into single history entries
ReplayViewModel<DocumentState>(
  debounceHistory: Duration(milliseconds: 300),
  ...
)

// More aggressive debounce for slider values
ReplayReactiveNotifier<double>(
  debounceHistory: Duration(milliseconds: 500),
  ...
)
```

### Use keep() for Expensive Widgets

```dart
ReactiveBuilder<DocumentState>(
  notifier: DocumentService.document,
  build: (state, notifier, keep) {
    return Column(
      children: [
        // Undo/Redo toolbar - updates frequently
        Row(
          children: [
            IconButton(onPressed: notifier.canUndo ? notifier.undo : null, ...),
            IconButton(onPressed: notifier.canRedo ? notifier.redo : null, ...),
          ],
        ),
        // Heavy editor widget - preserved
        keep(ExpensiveEditorWidget()),
      ],
    );
  },
)
```

## Critical Implementation Details

### How ReplayReactiveNotifier Works

1. Wraps an internal `ReactiveNotifier<T>`
2. Sets up listener on internal notifier for state changes
3. Records state changes in history (respecting debounce)
4. On undo/redo, sets `isPerformingUndoRedo = true` to prevent re-recording
5. Applies historical state via internal notifier's `updateState()`
6. Forwards notifications to external listeners

### How ReplayViewModel Works

1. Extends `ViewModel<T>` with `ReplayHistoryMixin<T>`
2. Overrides `onStateChanged(previous, next)` hook
3. Hook automatically records state changes (when not performing undo/redo)
4. On undo/redo, calls `updateState()` which triggers hook but recording is skipped

### How ReplayAsyncViewModelImpl Works

1. Extends `AsyncViewModelImpl<T>` with `ReplayHistoryMixin<T>`
2. Overrides `onAsyncStateChanged(previous, next)` hook
3. Hook only records when `next.isSuccess && next.data != null`
4. Loading and error states are intentionally NOT recorded
5. Perfect for data lists where users can undo deletions

### History Branch Behavior

```dart
// When user undoes then makes new change, redo history is cleared
notifier.updateState(1);  // History: [0, 1]
notifier.updateState(2);  // History: [0, 1, 2]
notifier.updateState(3);  // History: [0, 1, 2, 3]
notifier.undo();          // History: [0, 1, 2, 3], index at 2
notifier.undo();          // History: [0, 1, 2, 3], index at 1
notifier.updateState(10); // History: [0, 1, 10] - redo history (2, 3) cleared!
```

## Common Use Cases

### Text Editor with Undo/Redo

```dart
class TextEditorViewModel extends ReplayViewModel<TextEditorState> {
  TextEditorViewModel() : super(
    TextEditorState.empty(),
    historyLimit: 100,
    debounceHistory: Duration(milliseconds: 300),
  );

  @override
  void init() {}

  void updateText(String text) {
    transformState((s) => s.copyWith(text: text, isDirty: true));
  }

  void save() {
    // Save to storage...
    transformState((s) => s.copyWith(isDirty: false));
    clearHistory(); // Fresh start after save
  }
}
```

### Form with Undo

```dart
class FormViewModel extends ReplayViewModel<FormState> {
  FormViewModel() : super(FormState.empty(), historyLimit: 50);

  @override
  void init() {}

  void updateField(String field, String value) {
    transformState((s) => s.copyWithField(field, value));
  }

  void resetForm() {
    updateState(FormState.empty());
    clearHistory();
  }
}
```

### Todo List with Undoable Deletions

```dart
class TodoListViewModel extends ReplayAsyncViewModelImpl<List<Todo>> {
  final TodoRepository _repository;

  TodoListViewModel(this._repository) : super(
    AsyncState.initial(),
    historyLimit: 20,
  );

  @override
  Future<List<Todo>> init() async {
    return await _repository.loadTodos();
  }

  void deleteTodo(String id) {
    transformDataState((todos) => todos?.where((t) => t.id != id).toList());
    // User can undo() to restore the deleted todo!
  }
}
```

### Game State with History

```dart
class GameViewModel extends ReplayViewModel<GameState> {
  GameViewModel() : super(GameState.initial(), historyLimit: 100);

  @override
  void init() {}

  void makeMove(Move move) {
    transformState((s) => s.applyMove(move));
  }

  void undoMove() {
    if (canUndo) undo();
  }

  void newGame() {
    updateState(GameState.initial());
    clearHistory();
  }
}
```

## Integration with Desktop Shortcuts

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
        // macOS
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
          const UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyZ):
          const RedoIntent(),
      },
      child: Actions(
        actions: {
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) => EditorService.undo(),
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) => EditorService.redo(),
          ),
        },
        child: Focus(autofocus: true, child: EditorWidget()),
      ),
    );
  }
}
```

## Mixin Implementation Guide

For custom implementations using `ReplayHistoryMixin`:

```dart
class MyCustomReplayClass with ReplayHistoryMixin<MyState> {
  MyState _state;

  MyCustomReplayClass(MyState initialState) : _state = initialState {
    // Step 1: Initialize configuration
    initializeHistory(ReplayHistoryConfig(
      historyLimit: 100,
      debounceHistory: Duration(milliseconds: 300),
      onCanUndoChanged: (canUndo) => notifyListeners(),
      onCanRedoChanged: (canRedo) => notifyListeners(),
    ));

    // Step 2: Record initial state
    recordInitialState(_state);
  }

  MyState get state => _state;

  void updateState(MyState newState) {
    _state = newState;

    // Step 3: Record changes (when not undoing/redoing)
    if (!isPerformingUndoRedo) {
      handleStateChangeForHistory(newState);
    }

    notifyListeners();
  }

  // Step 4: Implement how to apply historical state
  @override
  void applyHistoricalState(MyState state) {
    _state = state;
    notifyListeners();
  }

  // Step 5: Clean up on dispose
  void dispose() {
    disposeHistory();
  }
}
```

This guide covers the API and patterns of reactive_notifier_replay v1.0.0. The package extends ReactiveNotifier's philosophy with time-travel debugging capabilities while maintaining full compatibility with existing builders and patterns.
