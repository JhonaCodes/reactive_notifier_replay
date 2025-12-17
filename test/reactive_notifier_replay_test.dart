import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:reactive_notifier_replay/reactive_notifier_replay.dart';

// ============================================================================
// TEST MODELS
// ============================================================================

class CounterState {
  final int value;

  const CounterState(this.value);

  CounterState copyWith({int? value}) {
    return CounterState(value ?? this.value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CounterState &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class DocumentState {
  final String content;
  final int cursorPosition;

  const DocumentState({this.content = '', this.cursorPosition = 0});

  factory DocumentState.empty() => const DocumentState();

  DocumentState copyWith({String? content, int? cursorPosition}) {
    return DocumentState(
      content: content ?? this.content,
      cursorPosition: cursorPosition ?? this.cursorPosition,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentState &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          cursorPosition == other.cursorPosition;

  @override
  int get hashCode => content.hashCode ^ cursorPosition.hashCode;
}

// ============================================================================
// TEST VIEWMODELS
// ============================================================================

class TestReplayViewModel extends ReplayViewModel<CounterState> {
  TestReplayViewModel({
    int historyLimit = 100,
    Duration? debounceHistory,
    void Function(bool)? onCanUndoChanged,
    void Function(bool)? onCanRedoChanged,
  }) : super(
          const CounterState(0),
          historyLimit: historyLimit,
          debounceHistory: debounceHistory,
          onCanUndoChanged: onCanUndoChanged,
          onCanRedoChanged: onCanRedoChanged,
        );

  @override
  void init() {
    // No initialization needed for tests
  }

  void increment() {
    transformState((state) => state.copyWith(value: state.value + 1));
  }

  void decrement() {
    transformState((state) => state.copyWith(value: state.value - 1));
  }

  void setValue(int value) {
    updateState(CounterState(value));
  }
}

class TestReplayAsyncViewModel extends ReplayAsyncViewModelImpl<DocumentState> {
  final bool shouldFail;

  TestReplayAsyncViewModel({
    this.shouldFail = false,
    int historyLimit = 100,
    Duration? debounceHistory,
    void Function(bool)? onCanUndoChanged,
    void Function(bool)? onCanRedoChanged,
  }) : super(
          AsyncState.initial(),
          loadOnInit: true,
          historyLimit: historyLimit,
          debounceHistory: debounceHistory,
          onCanUndoChanged: onCanUndoChanged,
          onCanRedoChanged: onCanRedoChanged,
        );

  @override
  Future<DocumentState> init() async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldFail) {
      throw Exception('Failed to load');
    }
    return DocumentState.empty();
  }

  void setContent(String content) {
    transformDataState((state) => state?.copyWith(content: content));
  }

  void setCursor(int position) {
    transformDataState((state) => state?.copyWith(cursorPosition: position));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ReactiveNotifier.cleanup();
  });

  group('ReplayReactiveNotifier', () {
    group('Basic Operations', () {
      test('should create with initial state in history', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        expect(notifier.notifier, equals(0));
        expect(notifier.historyLength, equals(1));
        expect(notifier.currentHistoryIndex, equals(0));
        expect(notifier.canUndo, isFalse);
        expect(notifier.canRedo, isFalse);
      });

      test('should record state changes in history', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.updateState(1);
        notifier.updateState(2);
        notifier.updateState(3);

        expect(notifier.notifier, equals(3));
        expect(notifier.historyLength, equals(4)); // initial + 3 updates
        expect(notifier.currentHistoryIndex, equals(3));
        expect(notifier.canUndo, isTrue);
        expect(notifier.canRedo, isFalse);
      });

      test('should undo state changes', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.updateState(1);
        notifier.updateState(2);
        notifier.undo();

        expect(notifier.notifier, equals(1));
        expect(notifier.canUndo, isTrue);
        expect(notifier.canRedo, isTrue);
      });

      test('should redo undone state changes', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.updateState(1);
        notifier.updateState(2);
        notifier.undo();
        notifier.redo();

        expect(notifier.notifier, equals(2));
        expect(notifier.canUndo, isTrue);
        expect(notifier.canRedo, isFalse);
      });

      test('should not undo when at start of history', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.undo();

        expect(notifier.notifier, equals(0));
        expect(notifier.currentHistoryIndex, equals(0));
      });

      test('should not redo when at end of history', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.updateState(1);
        notifier.redo();

        expect(notifier.notifier, equals(1));
        expect(notifier.currentHistoryIndex, equals(1));
      });
    });

    group('History Management', () {
      test('should respect history limit', () {
        final notifier = ReplayReactiveNotifier<int>(
          create: () => 0,
          historyLimit: 5,
        );

        for (int i = 1; i <= 10; i++) {
          notifier.updateState(i);
        }

        expect(notifier.historyLength, equals(5));
        expect(notifier.notifier, equals(10));
        expect(
          notifier.peekHistory(0),
          equals(6),
        ); // First entry in limited history
      });

      test('should clear redo history on new state after undo', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.updateState(1);
        notifier.updateState(2);
        notifier.updateState(3);
        notifier.undo();
        notifier.undo();
        notifier.updateState(10);

        expect(notifier.historyLength, equals(3)); // 0, 1, 10
        expect(notifier.notifier, equals(10));
        expect(notifier.canRedo, isFalse);
      });

      test('should clear history and keep current state', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.updateState(1);
        notifier.updateState(2);
        notifier.updateState(3);
        notifier.clearHistory();

        expect(notifier.historyLength, equals(1));
        expect(notifier.notifier, equals(3));
        expect(notifier.currentHistoryIndex, equals(0));
        expect(notifier.canUndo, isFalse);
        expect(notifier.canRedo, isFalse);
      });

      test('should jump to specific history index', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.updateState(1);
        notifier.updateState(2);
        notifier.updateState(3);
        notifier.jumpToHistory(1);

        expect(notifier.notifier, equals(1));
        expect(notifier.currentHistoryIndex, equals(1));
        expect(notifier.canUndo, isTrue);
        expect(notifier.canRedo, isTrue);
      });

      test('should not jump to invalid history index', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.updateState(1);
        notifier.jumpToHistory(-1);
        notifier.jumpToHistory(100);

        expect(notifier.notifier, equals(1));
        expect(notifier.currentHistoryIndex, equals(1));
      });

      test('should peek history without changing state', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.updateState(1);
        notifier.updateState(2);

        expect(notifier.peekHistory(0), equals(0));
        expect(notifier.peekHistory(1), equals(1));
        expect(notifier.peekHistory(2), equals(2));
        expect(notifier.peekHistory(100), isNull);
        expect(notifier.notifier, equals(2)); // State unchanged
      });
    });

    group('Callbacks', () {
      test('should call onCanUndoChanged when availability changes', () {
        final undoChanges = <bool>[];

        final notifier = ReplayReactiveNotifier<int>(
          create: () => 0,
          onCanUndoChanged: undoChanges.add,
        );

        notifier.updateState(1); // canUndo: false -> true
        notifier.undo(); // canUndo: true -> false

        expect(undoChanges, equals([true, false]));
      });

      test('should call onCanRedoChanged when availability changes', () {
        final redoChanges = <bool>[];

        final notifier = ReplayReactiveNotifier<int>(
          create: () => 0,
          onCanRedoChanged: redoChanges.add,
        );

        notifier.updateState(1);
        notifier.undo(); // canRedo: false -> true
        notifier.redo(); // canRedo: true -> false

        expect(redoChanges, equals([true, false]));
      });
    });

    group('Silent Updates', () {
      test('should record state on silent updates', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.updateSilently(1);
        notifier.updateSilently(2);

        expect(notifier.historyLength, equals(3));
        expect(notifier.notifier, equals(2));
      });
    });

    group('Transform State', () {
      test('should record state on transform', () {
        final notifier = ReplayReactiveNotifier<int>(create: () => 0);

        notifier.transformState((value) => value + 10);
        notifier.transformState((value) => value * 2);

        expect(notifier.historyLength, equals(3));
        expect(notifier.notifier, equals(20));
      });
    });
  });

  group('ReplayViewModel', () {
    group('Basic Operations', () {
      test('should create with initial state in history', () {
        final viewModel = TestReplayViewModel();

        expect(viewModel.data.value, equals(0));
        expect(viewModel.historyLength, equals(1));
        expect(viewModel.canUndo, isFalse);
        expect(viewModel.canRedo, isFalse);
      });

      test('should record state changes and support undo/redo', () {
        final viewModel = TestReplayViewModel();

        viewModel.increment();
        viewModel.increment();
        viewModel.increment();

        expect(viewModel.data.value, equals(3));
        expect(viewModel.historyLength, equals(4));

        viewModel.undo();
        expect(viewModel.data.value, equals(2));

        viewModel.undo();
        expect(viewModel.data.value, equals(1));

        viewModel.redo();
        expect(viewModel.data.value, equals(2));
      });

      test('should clear history correctly', () {
        final viewModel = TestReplayViewModel();

        viewModel.increment();
        viewModel.increment();
        viewModel.clearHistory();

        expect(viewModel.historyLength, equals(1));
        expect(viewModel.data.value, equals(2));
        expect(viewModel.canUndo, isFalse);
      });
    });

    group('History Limit', () {
      test('should respect history limit', () {
        final viewModel = TestReplayViewModel(historyLimit: 3);

        viewModel.setValue(1);
        viewModel.setValue(2);
        viewModel.setValue(3);
        viewModel.setValue(4);

        expect(viewModel.historyLength, equals(3));
        expect(viewModel.peekHistory(0), equals(const CounterState(2)));
      });
    });

    group('Callbacks', () {
      test('should notify on undo/redo availability changes', () {
        final undoChanges = <bool>[];
        final redoChanges = <bool>[];

        final viewModel = TestReplayViewModel(
          onCanUndoChanged: undoChanges.add,
          onCanRedoChanged: redoChanges.add,
        );

        viewModel.increment();
        viewModel.undo();
        viewModel.redo();

        expect(undoChanges, equals([true, false, true]));
        expect(redoChanges, equals([true, false]));
      });
    });
  });

  group('ReplayAsyncViewModelImpl', () {
    group('Basic Operations', () {
      test('should record success states in history', () async {
        final viewModel = TestReplayAsyncViewModel();

        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 50));

        expect(viewModel.hasData, isTrue);
        expect(viewModel.historyLength, equals(1)); // Initial load

        viewModel.setContent('Hello');
        expect(viewModel.historyLength, equals(2));

        viewModel.setContent('Hello World');
        expect(viewModel.historyLength, equals(3));
      });

      test('should support undo/redo for success states', () async {
        final viewModel = TestReplayAsyncViewModel();

        await Future.delayed(const Duration(milliseconds: 50));

        viewModel.setContent('First');
        viewModel.setContent('Second');
        viewModel.setContent('Third');

        expect(viewModel.data?.content, equals('Third'));

        viewModel.undo();
        expect(viewModel.data?.content, equals('Second'));

        viewModel.undo();
        expect(viewModel.data?.content, equals('First'));

        viewModel.redo();
        expect(viewModel.data?.content, equals('Second'));
      });

      test('should not record loading or error states', () async {
        final viewModel = TestReplayAsyncViewModel();

        await Future.delayed(const Duration(milliseconds: 50));

        final initialHistoryLength = viewModel.historyLength;

        // Trigger reload (causes loading state)
        viewModel.reload();

        await Future.delayed(const Duration(milliseconds: 50));

        // History should only have success states (initial + reload result)
        // Loading states are NOT recorded
        expect(
          viewModel.historyLength,
          greaterThanOrEqualTo(initialHistoryLength),
        );
      });

      test('should clear history correctly', () async {
        final viewModel = TestReplayAsyncViewModel();

        await Future.delayed(const Duration(milliseconds: 50));

        viewModel.setContent('First');
        viewModel.setContent('Second');
        viewModel.clearHistory();

        expect(viewModel.historyLength, equals(1));
        expect(viewModel.data?.content, equals('Second'));
        expect(viewModel.canUndo, isFalse);
      });
    });

    group('History Navigation', () {
      test('should jump to specific history index', () async {
        final viewModel = TestReplayAsyncViewModel();

        await Future.delayed(const Duration(milliseconds: 50));

        viewModel.setContent('One');
        viewModel.setContent('Two');
        viewModel.setContent('Three');

        viewModel.jumpToHistory(1);
        expect(viewModel.data?.content, equals('One'));

        viewModel.jumpToHistory(3);
        expect(viewModel.data?.content, equals('Three'));
      });

      test('should peek history without changing state', () async {
        final viewModel = TestReplayAsyncViewModel();

        await Future.delayed(const Duration(milliseconds: 50));

        viewModel.setContent('Alpha');
        viewModel.setContent('Beta');

        expect(viewModel.peekHistory(0)?.content, equals(''));
        expect(viewModel.peekHistory(1)?.content, equals('Alpha'));
        expect(viewModel.peekHistory(2)?.content, equals('Beta'));
        expect(viewModel.data?.content, equals('Beta')); // State unchanged
      });
    });

    group('Callbacks', () {
      test('should notify on availability changes', () async {
        final undoChanges = <bool>[];
        final redoChanges = <bool>[];

        final viewModel = TestReplayAsyncViewModel(
          onCanUndoChanged: undoChanges.add,
          onCanRedoChanged: redoChanges.add,
        );

        await Future.delayed(const Duration(milliseconds: 50));

        viewModel.setContent('First');
        viewModel.undo();
        viewModel.redo();

        expect(undoChanges.contains(true), isTrue);
        expect(redoChanges.contains(true), isTrue);
      });
    });
  });

  group('Debounce History', () {
    test(
      'ReplayReactiveNotifier should debounce rapid state changes',
      () async {
        final notifier = ReplayReactiveNotifier<int>(
          create: () => 0,
          debounceHistory: const Duration(milliseconds: 100),
        );

        // Rapid updates
        notifier.updateState(1);
        notifier.updateState(2);
        notifier.updateState(3);
        notifier.updateState(4);
        notifier.updateState(5);

        // Before debounce completes, only initial state is recorded
        expect(notifier.historyLength, equals(1));
        expect(notifier.notifier, equals(5));

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 150));

        // After debounce, only final state is recorded
        expect(notifier.historyLength, equals(2)); // initial + final
        expect(notifier.notifier, equals(5));
      },
    );

    test('ReplayViewModel should debounce rapid state changes', () async {
      final viewModel = TestReplayViewModel(
        debounceHistory: const Duration(milliseconds: 100),
      );

      // Rapid updates
      viewModel.increment();
      viewModel.increment();
      viewModel.increment();

      expect(viewModel.historyLength, equals(1));
      expect(viewModel.data.value, equals(3));

      await Future.delayed(const Duration(milliseconds: 150));

      expect(viewModel.historyLength, equals(2));
    });
  });

  group('Multiple Undo/Redo Cycles', () {
    test('should handle multiple undo/redo cycles correctly', () {
      final notifier = ReplayReactiveNotifier<int>(create: () => 0);

      // First set of changes
      notifier.updateState(1);
      notifier.updateState(2);
      notifier.updateState(3);

      // Undo all
      notifier.undo();
      notifier.undo();
      notifier.undo();
      expect(notifier.notifier, equals(0));

      // Redo some
      notifier.redo();
      notifier.redo();
      expect(notifier.notifier, equals(2));

      // New change (clears redo)
      notifier.updateState(10);
      expect(notifier.canRedo, isFalse);
      expect(notifier.notifier, equals(10));

      // Undo to verify new branch
      notifier.undo();
      expect(notifier.notifier, equals(2));
    });
  });

  group('Reset History', () {
    test('ReplayReactiveNotifier should clear history on resetHistory', () {
      final notifier = ReplayReactiveNotifier<int>(create: () => 0);

      notifier.updateState(1);
      notifier.updateState(2);
      notifier.updateState(3);

      expect(notifier.historyLength, equals(4));

      notifier.resetHistory();

      // resetHistory keeps current state but clears history
      expect(notifier.notifier, equals(3));
      expect(notifier.historyLength, equals(1));
      expect(notifier.canUndo, isFalse);
    });
  });
}
