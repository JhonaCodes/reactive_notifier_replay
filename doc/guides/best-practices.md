# Best Practices

Recommended patterns and practices for using ReactiveNotifier Replay effectively.

## 1. Set Appropriate History Limits

Choose history limits based on the use case and memory considerations.

### Text Editor (many changes expected)
```dart
ReplayViewModel<TextState>(
  historyLimit: 200,  // Many changes
  ...
)
```

### Settings (few changes expected)
```dart
ReplayReactiveNotifier<Settings>(
  create: () => Settings(),
  historyLimit: 20,  // Few changes
)
```

### Game State (moderate changes)
```dart
ReplayViewModel<GameState>(
  historyLimit: 50,  // One per move
  ...
)
```

### Memory Calculation

Each history entry stores a copy of the state. Consider:
- State object size
- Maximum history limit
- Total memory = (state size) x (history limit)

```dart
// Example: Document with ~1KB text
// 100 history entries = ~100KB maximum
ReplayViewModel<DocumentState>(historyLimit: 100, ...)
```

---

## 2. Use Debounce for Text Input

Prevent every keystroke from creating a history entry.

### Recommended Debounce Values

| Use Case | Debounce Duration |
|----------|-------------------|
| Fast typing | 300-500ms |
| Slow editing | 500-1000ms |
| Form fields | 200-300ms |

```dart
class TextEditorViewModel extends ReplayViewModel<TextState> {
  TextEditorViewModel() : super(
    TextState.empty(),
    historyLimit: 100,
    debounceHistory: Duration(milliseconds: 300), // Group rapid typing
  );

  @override
  void init() {}

  void onTextChanged(String text) {
    // Each keystroke calls this, but history only records after 300ms pause
    transformState((state) => state.copyWith(text: text));
  }
}
```

---

## 3. Clear History on Significant Events

Start fresh after important events to keep history relevant.

### After Save
```dart
Future<void> saveDocument() async {
  await repository.save(data);
  transformState((state) => state.copyWith(isDirty: false));
  clearHistory(); // Start fresh after save
}
```

### After Logout
```dart
void logout() {
  clearHistory(); // Clear sensitive data from history
  transformState((_) => AuthState.loggedOut());
}
```

### After Navigation
```dart
void onScreenExit() {
  clearHistory(); // Keep history small across screens
}
```

---

## 4. Follow the Mixin Service Pattern

Always use mixins for services, never global variables.

### Correct
```dart
mixin EditorService {
  static final document = ReactiveNotifier<DocumentViewModel>(
    () => DocumentViewModel(),
  );
}
```

### Incorrect
```dart
// NEVER use global variables
final document = ReactiveNotifier<DocumentViewModel>(
  () => DocumentViewModel(),
);
```

---

## 5. Handle Silent Updates Appropriately

Use silent updates for changes that shouldn't clutter history.

### Cursor Position (don't record)
```dart
void setCursorPosition(int position) {
  // Use silent update - cursor moves shouldn't fill history
  transformStateSilently((state) => state.copyWith(
    cursorPosition: position,
  ));
}
```

### Content Changes (record)
```dart
void updateContent(String content) {
  // Use regular update - content changes should be undoable
  transformState((state) => state.copyWith(
    content: content,
    isDirty: true,
  ));
}
```

### Selection State (don't record)
```dart
void setSelection(int start, int end) {
  // Selection changes happen frequently, don't record
  transformStateSilently((state) => state.copyWith(
    selectionStart: start,
    selectionEnd: end,
  ));
}
```

---

## 6. Handle Async States Carefully

Remember: only success states are tracked in `ReplayAsyncViewModelImpl`.

### What Gets Recorded
```dart
class DataViewModel extends ReplayAsyncViewModelImpl<List<Item>> {
  void deleteItem(String id) {
    transformDataState((items) => items?.where((i) => i.id != id).toList());
    // This IS recorded - user can undo!
  }

  Future<void> reload() async {
    // Loading state is NOT recorded
    // New success state IS recorded
    await super.reload();
  }
}
```

### Error Recovery Pattern
```dart
class DataViewModel extends ReplayAsyncViewModelImpl<List<Item>> {
  Future<void> saveAndReload() async {
    try {
      await api.save(data);
      await reload();
    } catch (e) {
      // Error state NOT recorded
      // Previous success state still in history for undo
      errorState(e);
    }
  }
}
```

---

## 7. Use Availability Callbacks for UI Updates

Update UI button states reactively using callbacks.

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
      onCanUndoChanged: (canUndo) => setState(() => _canUndo = canUndo),
      onCanRedoChanged: (canRedo) => setState(() => _canRedo = canRedo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: _canUndo ? _notifier.undo : null, // Reactive!
          icon: Icon(Icons.undo),
        ),
        IconButton(
          onPressed: _canRedo ? _notifier.redo : null, // Reactive!
          icon: Icon(Icons.redo),
        ),
      ],
    );
  }
}
```

---

## 8. Consider Performance for Large States

### Immutable State with copyWith
```dart
class LargeState {
  final List<Item> items;
  final Map<String, dynamic> metadata;

  // Use copyWith for immutability
  LargeState copyWith({
    List<Item>? items,
    Map<String, dynamic>? metadata,
  }) => LargeState(
    items: items ?? this.items,
    metadata: metadata ?? this.metadata,
  );
}
```

### Avoid Deep Copies in History
```dart
// If state contains large immutable objects, history shares references
// This is memory-efficient because unchanged parts aren't duplicated
transformState((state) => state.copyWith(
  // Only changed field is copied
  selectedIndex: newIndex,
));
```

### Consider Snapshot-Based History
For very large states, consider storing only changes (diffs):
```dart
// For advanced use cases, implement custom history with diffs
class DiffBasedHistory<T> {
  final T initialState;
  final List<Map<String, dynamic>> diffs;

  T applyDiffs(int upToIndex) {
    // Apply diffs to reconstruct state
  }
}
```

---

## 9. Test History Behavior

### Basic Tests
```dart
test('should support undo/redo', () {
  final notifier = ReplayReactiveNotifier<int>(create: () => 0);

  notifier.updateState(1);
  notifier.updateState(2);
  notifier.updateState(3);

  expect(notifier.notifier, equals(3));
  expect(notifier.canUndo, isTrue);
  expect(notifier.historyLength, equals(4)); // initial + 3

  notifier.undo();
  expect(notifier.notifier, equals(2));
  expect(notifier.canRedo, isTrue);
});
```

### History Limit Tests
```dart
test('should respect history limit', () {
  final notifier = ReplayReactiveNotifier<int>(
    create: () => 0,
    historyLimit: 5,
  );

  for (int i = 1; i <= 10; i++) {
    notifier.updateState(i);
  }

  expect(notifier.historyLength, equals(5)); // Capped at limit
});
```

### Cleanup in Tests
```dart
setUp(() {
  ReactiveNotifier.cleanup(); // Clear all states between tests
});
```

---

## 10. Document History Behavior

Document which operations are undoable for users.

```dart
/// Updates the document content.
///
/// This operation is recorded in history and can be undone with [undo].
void updateContent(String content) {
  transformState((state) => state.copyWith(content: content));
}

/// Sets the cursor position.
///
/// This operation is NOT recorded in history (silent update).
void setCursorPosition(int position) {
  transformStateSilently((state) => state.copyWith(cursor: position));
}

/// Deletes an item from the list.
///
/// This operation can be undone. The item will be restored
/// to its previous position when [undo] is called.
void deleteItem(String id) {
  transformDataState((items) => items?.where((i) => i.id != id).toList());
}
```

---

## Summary

| Practice | Why |
|----------|-----|
| Set appropriate limits | Memory management |
| Use debounce for text | Avoid cluttered history |
| Clear history on save | Keep history relevant |
| Use mixin services | Clean architecture |
| Handle silent updates | Separate undo-worthy changes |
| Understand async tracking | Only success states recorded |
| Use availability callbacks | Reactive UI updates |
| Consider performance | Large states need care |
| Test history behavior | Ensure correctness |
| Document behavior | Clear user expectations |
