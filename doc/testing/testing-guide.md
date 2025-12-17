# Testing Guide

Complete testing patterns for ReactiveNotifier Replay.

## Setup

### Test Dependencies

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
```

### Basic Test Setup

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:reactive_notifier_replay/reactive_notifier_replay.dart';

void main() {
  setUp(() {
    // Clear all states between tests
    ReactiveNotifier.cleanup();
  });

  // Your tests here
}
```

---

## Testing ReplayReactiveNotifier

### Basic Undo/Redo

```dart
group('ReplayReactiveNotifier', () {
  test('should support basic undo/redo', () {
    final notifier = ReplayReactiveNotifier<int>(create: () => 0);

    // Initial state
    expect(notifier.notifier, equals(0));
    expect(notifier.canUndo, isFalse);
    expect(notifier.canRedo, isFalse);
    expect(notifier.historyLength, equals(1));

    // Make changes
    notifier.updateState(1);
    notifier.updateState(2);
    notifier.updateState(3);

    expect(notifier.notifier, equals(3));
    expect(notifier.canUndo, isTrue);
    expect(notifier.canRedo, isFalse);
    expect(notifier.historyLength, equals(4));

    // Undo
    notifier.undo();
    expect(notifier.notifier, equals(2));
    expect(notifier.canUndo, isTrue);
    expect(notifier.canRedo, isTrue);

    notifier.undo();
    expect(notifier.notifier, equals(1));

    notifier.undo();
    expect(notifier.notifier, equals(0));
    expect(notifier.canUndo, isFalse);

    // Redo
    notifier.redo();
    expect(notifier.notifier, equals(1));

    notifier.redo();
    expect(notifier.notifier, equals(2));
  });

  test('should clear redo history on new state after undo', () {
    final notifier = ReplayReactiveNotifier<int>(create: () => 0);

    notifier.updateState(1);
    notifier.updateState(2);
    notifier.undo();

    expect(notifier.canRedo, isTrue);

    // New state should clear redo
    notifier.updateState(10);

    expect(notifier.canRedo, isFalse);
    expect(notifier.historyLength, equals(3)); // 0, 1, 10
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
    expect(notifier.notifier, equals(10));
  });

  test('should call availability callbacks', () {
    bool? lastCanUndo;
    bool? lastCanRedo;

    final notifier = ReplayReactiveNotifier<int>(
      create: () => 0,
      onCanUndoChanged: (canUndo) => lastCanUndo = canUndo,
      onCanRedoChanged: (canRedo) => lastCanRedo = canRedo,
    );

    expect(lastCanUndo, isNull); // Not called yet

    notifier.updateState(1);
    expect(lastCanUndo, isTrue); // Now can undo

    notifier.undo();
    expect(lastCanUndo, isFalse); // Can't undo anymore
    expect(lastCanRedo, isTrue); // Now can redo

    notifier.redo();
    expect(lastCanRedo, isFalse); // Can't redo anymore
  });
});
```

### Transform and Silent Updates

```dart
group('Transform and Silent Updates', () {
  test('transformState should record history', () {
    final notifier = ReplayReactiveNotifier<int>(create: () => 0);

    notifier.transformState((value) => value + 10);

    expect(notifier.notifier, equals(10));
    expect(notifier.historyLength, equals(2));
    expect(notifier.canUndo, isTrue);
  });

  test('updateSilently should record history but not notify', () {
    final notifier = ReplayReactiveNotifier<int>(create: () => 0);
    int notifyCount = 0;
    notifier.addListener(() => notifyCount++);

    notifier.updateSilently(5);

    expect(notifier.notifier, equals(5));
    expect(notifyCount, equals(0)); // No notification
    expect(notifier.historyLength, equals(2)); // But history recorded
  });

  test('transformStateSilently should record history but not notify', () {
    final notifier = ReplayReactiveNotifier<int>(create: () => 0);
    int notifyCount = 0;
    notifier.addListener(() => notifyCount++);

    notifier.transformStateSilently((v) => v + 5);

    expect(notifier.notifier, equals(5));
    expect(notifyCount, equals(0));
    expect(notifier.historyLength, equals(2));
  });
});
```

### Jump and Peek

```dart
group('Jump and Peek', () {
  test('jumpToHistory should navigate to specific index', () {
    final notifier = ReplayReactiveNotifier<int>(create: () => 0);

    notifier.updateState(1);
    notifier.updateState(2);
    notifier.updateState(3);
    notifier.updateState(4);

    notifier.jumpToHistory(1); // Jump to state "1"

    expect(notifier.notifier, equals(1));
    expect(notifier.currentHistoryIndex, equals(1));
    expect(notifier.canUndo, isTrue);
    expect(notifier.canRedo, isTrue);
  });

  test('peekHistory should not change current state', () {
    final notifier = ReplayReactiveNotifier<int>(create: () => 0);

    notifier.updateState(1);
    notifier.updateState(2);

    final peekedValue = notifier.peekHistory(0);

    expect(peekedValue, equals(0)); // Initial state
    expect(notifier.notifier, equals(2)); // Current unchanged
    expect(notifier.currentHistoryIndex, equals(2)); // Index unchanged
  });

  test('peekHistory should return null for invalid index', () {
    final notifier = ReplayReactiveNotifier<int>(create: () => 0);

    expect(notifier.peekHistory(-1), isNull);
    expect(notifier.peekHistory(100), isNull);
  });
});
```

### Clear History

```dart
group('Clear History', () {
  test('clearHistory should reset history with current state', () {
    final notifier = ReplayReactiveNotifier<int>(create: () => 0);

    notifier.updateState(1);
    notifier.updateState(2);
    notifier.updateState(3);

    notifier.clearHistory();

    expect(notifier.notifier, equals(3)); // Current state preserved
    expect(notifier.historyLength, equals(1)); // Only current
    expect(notifier.canUndo, isFalse);
    expect(notifier.canRedo, isFalse);
  });

  test('clearHistory with state should use provided state', () {
    final notifier = ReplayReactiveNotifier<int>(create: () => 0);

    notifier.updateState(1);
    notifier.updateState(2);

    notifier.clearHistory(100);

    expect(notifier.notifier, equals(2)); // Notifier unchanged (clearHistory doesn't update state)
    expect(notifier.historyLength, equals(1));
    expect(notifier.peekHistory(0), equals(100)); // History has provided value
  });
});
```

---

## Testing ReplayViewModel

```dart
// Test ViewModel
class TestCounterViewModel extends ReplayViewModel<CounterState> {
  TestCounterViewModel() : super(CounterState(0));

  @override
  void init() {}

  void increment() {
    transformState((s) => CounterState(s.value + 1));
  }

  void decrement() {
    transformState((s) => CounterState(s.value - 1));
  }
}

class CounterState {
  final int value;
  CounterState(this.value);
}

group('ReplayViewModel', () {
  test('should track state changes via hook', () {
    final viewModel = TestCounterViewModel();

    viewModel.increment();
    viewModel.increment();
    viewModel.increment();

    expect(viewModel.data.value, equals(3));
    expect(viewModel.historyLength, equals(4)); // initial + 3

    viewModel.undo();
    expect(viewModel.data.value, equals(2));

    viewModel.undo();
    expect(viewModel.data.value, equals(1));

    viewModel.redo();
    expect(viewModel.data.value, equals(2));
  });

  test('should work with transformStateSilently', () {
    final viewModel = TestCounterViewModel();
    int notifyCount = 0;
    viewModel.addListener(() => notifyCount++);

    viewModel.transformStateSilently((s) => CounterState(10));

    expect(viewModel.data.value, equals(10));
    expect(notifyCount, equals(0)); // No notification
    expect(viewModel.historyLength, equals(2)); // But recorded
  });
});
```

---

## Testing ReplayAsyncViewModelImpl

```dart
// Test AsyncViewModel
class TestAsyncViewModel extends ReplayAsyncViewModelImpl<List<String>> {
  TestAsyncViewModel() : super(AsyncState.initial());

  @override
  Future<List<String>> init() async {
    await Future.delayed(Duration(milliseconds: 10));
    return ['Initial'];
  }

  void addItem(String item) {
    transformDataState((items) => [...?items, item]);
  }

  void removeItem(String item) {
    transformDataState((items) => items?.where((i) => i != item).toList());
  }
}

group('ReplayAsyncViewModelImpl', () {
  test('should only track success states', () async {
    final viewModel = TestAsyncViewModel();

    // Wait for init to complete
    await Future.delayed(Duration(milliseconds: 50));

    expect(viewModel.hasData, isTrue);
    expect(viewModel.historyLength, equals(1)); // Only initial success

    viewModel.addItem('Item 1');
    viewModel.addItem('Item 2');

    expect(viewModel.historyLength, equals(3));

    viewModel.undo();
    expect(viewModel.data, equals(['Initial', 'Item 1']));

    viewModel.undo();
    expect(viewModel.data, equals(['Initial']));
  });

  test('loading state should not be recorded', () async {
    final viewModel = TestAsyncViewModel();

    // Initially loading
    expect(viewModel.isLoading, isTrue);

    // Wait for completion
    await Future.delayed(Duration(milliseconds: 50));

    // History should only have success state
    expect(viewModel.historyLength, equals(1));
    expect(viewModel.hasData, isTrue);
  });

  test('error state should not be recorded', () async {
    final viewModel = TestAsyncViewModel();

    await Future.delayed(Duration(milliseconds: 50));
    final initialHistory = viewModel.historyLength;

    viewModel.addItem('Item');
    expect(viewModel.historyLength, equals(initialHistory + 1));

    viewModel.errorState(Exception('Test error'));
    // Error should not add to history
    expect(viewModel.historyLength, equals(initialHistory + 1));
  });
});
```

---

## Testing with Debounce

```dart
group('Debounce', () {
  test('should debounce rapid updates', () async {
    final notifier = ReplayReactiveNotifier<int>(
      create: () => 0,
      debounceHistory: Duration(milliseconds: 100),
    );

    // Rapid updates
    notifier.updateState(1);
    notifier.updateState(2);
    notifier.updateState(3);
    notifier.updateState(4);
    notifier.updateState(5);

    // Before debounce completes, only initial should be recorded
    expect(notifier.historyLength, equals(1));

    // Wait for debounce
    await Future.delayed(Duration(milliseconds: 150));

    // Now final value should be recorded
    expect(notifier.historyLength, equals(2)); // initial + final
    expect(notifier.notifier, equals(5));
  });

  test('separate updates after debounce should be separate entries', () async {
    final notifier = ReplayReactiveNotifier<int>(
      create: () => 0,
      debounceHistory: Duration(milliseconds: 50),
    );

    notifier.updateState(1);
    await Future.delayed(Duration(milliseconds: 100)); // Wait for debounce

    notifier.updateState(2);
    await Future.delayed(Duration(milliseconds: 100)); // Wait for debounce

    expect(notifier.historyLength, equals(3)); // initial, 1, 2
  });
});
```

---

## Testing Service Pattern

```dart
mixin TestService {
  static final counter = ReplayReactiveNotifier<int>(create: () => 0);
}

group('Service Pattern', () {
  setUp(() {
    ReactiveNotifier.cleanup();
  });

  test('should work with mixin service pattern', () {
    TestService.counter.updateState(5);
    TestService.counter.updateState(10);

    expect(TestService.counter.notifier, equals(10));
    expect(TestService.counter.canUndo, isTrue);

    TestService.counter.undo();
    expect(TestService.counter.notifier, equals(5));
  });

  test('cleanup should reset service state', () {
    TestService.counter.updateState(100);

    ReactiveNotifier.cleanup();

    // After cleanup, accessing the service creates new instance
    expect(TestService.counter.notifier, equals(0));
    expect(TestService.counter.historyLength, equals(1));
  });
});
```

---

## Widget Testing

```dart
testWidgets('should update UI on undo/redo', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReactiveBuilder<int>(
        notifier: CounterService.counter,
        build: (value, notifier, keep) => Text('$value'),
      ),
    ),
  );

  expect(find.text('0'), findsOneWidget);

  CounterService.counter.updateState(5);
  await tester.pump();
  expect(find.text('5'), findsOneWidget);

  CounterService.counter.undo();
  await tester.pump();
  expect(find.text('0'), findsOneWidget);

  CounterService.counter.redo();
  await tester.pump();
  expect(find.text('5'), findsOneWidget);
});
```

---

## Test Utilities

### Custom Matcher for History State

```dart
Matcher hasHistoryLength(int expected) {
  return predicate<ReplayReactiveNotifier>(
    (notifier) => notifier.historyLength == expected,
    'has history length of $expected',
  );
}

// Usage
expect(notifier, hasHistoryLength(5));
```

### Test Helper Extension

```dart
extension ReplayTestExtensions<T> on ReplayReactiveNotifier<T> {
  List<T> get allHistory {
    return List.generate(
      historyLength,
      (i) => peekHistory(i)!,
    );
  }
}

// Usage
expect(notifier.allHistory, equals([0, 1, 2, 3]));
```
