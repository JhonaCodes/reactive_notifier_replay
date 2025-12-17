import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

/// Configuration for replay history functionality.
///
/// This class holds the parameters needed to configure history tracking
/// in replay-enabled components.
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

/// A mixin that provides undo/redo history tracking functionality.
///
/// This mixin encapsulates all the shared logic for managing state history
/// with undo/redo capabilities. It can be used with any class that manages
/// state of type [T].
///
/// ## Usage
///
/// Classes using this mixin must:
/// 1. Call [initializeHistory] during construction to set up the config
/// 2. Call [recordInitialState] with the initial state value
/// 3. Call [handleStateChangeForHistory] when state changes (unless during undo/redo)
/// 4. Implement actual state updates when [undo]/[redo] needs to apply a historical state
/// 5. Call [disposeHistory] during disposal to clean up timers
///
/// ## Example
///
/// ```dart
/// class MyReplayClass with ReplayHistoryMixin<MyState> {
///   MyReplayClass({
///     int historyLimit = 100,
///     Duration? debounceHistory,
///     void Function(bool)? onCanUndoChanged,
///     void Function(bool)? onCanRedoChanged,
///   }) {
///     initializeHistory(ReplayHistoryConfig(
///       historyLimit: historyLimit,
///       debounceHistory: debounceHistory,
///       onCanUndoChanged: onCanUndoChanged,
///       onCanRedoChanged: onCanRedoChanged,
///     ));
///     recordInitialState(initialState);
///   }
///
///   void onStateChanged(MyState newState) {
///     if (!isPerformingUndoRedo) {
///       handleStateChangeForHistory(newState);
///     }
///   }
///
///   @override
///   void applyHistoricalState(MyState state) {
///     // Apply the state to your actual state holder
///     _internalState = state;
///     notifyListeners();
///   }
///
///   @override
///   void dispose() {
///     disposeHistory();
///     super.dispose();
///   }
/// }
/// ```
mixin ReplayHistoryMixin<T> {
  // Configuration
  late final ReplayHistoryConfig _historyConfig;

  // Internal state
  final List<T> _history = [];
  int _currentIndex = -1;
  bool _isUndoRedo = false;
  Timer? _debounceTimer;

  /// The name used in debug logs.
  String get historyLogName => 'ReplayHistoryMixin';

  /// Whether undo is available.
  bool get canUndo => _currentIndex > 0;

  /// Whether redo is available.
  bool get canRedo => _currentIndex < _history.length - 1;

  /// Current number of states in history.
  int get historyLength => _history.length;

  /// Current position in history (0-indexed).
  int get currentHistoryIndex => _currentIndex;

  /// Whether an undo/redo operation is currently in progress.
  ///
  /// This can be checked to prevent recording state changes during undo/redo.
  bool get isPerformingUndoRedo => _isUndoRedo;

  /// Maximum number of states to keep in history.
  int get historyLimit => _historyConfig.historyLimit;

  /// Optional debounce duration for grouping rapid state changes.
  Duration? get debounceHistory => _historyConfig.debounceHistory;

  /// Callback when undo availability changes.
  void Function(bool canUndo)? get onCanUndoChanged =>
      _historyConfig.onCanUndoChanged;

  /// Callback when redo availability changes.
  void Function(bool canRedo)? get onCanRedoChanged =>
      _historyConfig.onCanRedoChanged;

  /// Initializes the history tracking with the given configuration.
  ///
  /// Must be called during construction before using any history features.
  @protected
  void initializeHistory(ReplayHistoryConfig config) {
    _historyConfig = config;

    assert(() {
      log(
        '$historyLogName<$T>: Initialized with historyLimit=${config.historyLimit}',
        name: historyLogName,
      );
      return true;
    }());
  }

  /// Records the initial state in history.
  ///
  /// Should be called once during construction with the initial state value.
  @protected
  void recordInitialState(T state) {
    _recordHistory(state);
  }

  /// Handles a state change with optional debouncing.
  ///
  /// Should be called when state changes (but not during undo/redo operations).
  /// Use [isPerformingUndoRedo] to check if you should skip calling this.
  @protected
  void handleStateChangeForHistory(T newState) {
    if (_historyConfig.debounceHistory != null) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_historyConfig.debounceHistory!, () {
        _recordHistory(newState);
      });
    } else {
      _recordHistory(newState);
    }
  }

  /// Records a state in history.
  void _recordHistory(T state) {
    final previousCanUndo = canUndo;
    final previousCanRedo = canRedo;

    // Clear redo history when new state is added
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    _history.add(state);
    _currentIndex++;

    // Enforce history limit
    if (_history.length > _historyConfig.historyLimit) {
      _history.removeAt(0);
      _currentIndex--;
    }

    // Notify availability changes
    _notifyAvailabilityChanges(previousCanUndo, previousCanRedo);

    assert(() {
      log(
        '$historyLogName<$T>: Recorded state at index $_currentIndex (total: ${_history.length})',
        name: historyLogName,
      );
      return true;
    }());
  }

  /// Notifies callbacks if undo/redo availability changed.
  void _notifyAvailabilityChanges(bool previousCanUndo, bool previousCanRedo) {
    if (canUndo != previousCanUndo) {
      _historyConfig.onCanUndoChanged?.call(canUndo);
    }
    if (canRedo != previousCanRedo) {
      _historyConfig.onCanRedoChanged?.call(canRedo);
    }
  }

  /// Undoes the last state change.
  ///
  /// Does nothing if [canUndo] is false.
  /// Calls [applyHistoricalState] with the previous state.
  void undo() {
    if (!canUndo) return;

    final previousCanUndo = canUndo;
    final previousCanRedo = canRedo;

    _isUndoRedo = true;
    _currentIndex--;
    applyHistoricalState(_history[_currentIndex]);
    _isUndoRedo = false;

    _notifyAvailabilityChanges(previousCanUndo, previousCanRedo);

    assert(() {
      log(
        '$historyLogName<$T>: Undo to index $_currentIndex',
        name: historyLogName,
      );
      return true;
    }());
  }

  /// Redoes the previously undone state change.
  ///
  /// Does nothing if [canRedo] is false.
  /// Calls [applyHistoricalState] with the next state.
  void redo() {
    if (!canRedo) return;

    final previousCanUndo = canUndo;
    final previousCanRedo = canRedo;

    _isUndoRedo = true;
    _currentIndex++;
    applyHistoricalState(_history[_currentIndex]);
    _isUndoRedo = false;

    _notifyAvailabilityChanges(previousCanUndo, previousCanRedo);

    assert(() {
      log(
        '$historyLogName<$T>: Redo to index $_currentIndex',
        name: historyLogName,
      );
      return true;
    }());
  }

  /// Clears all history.
  ///
  /// Keeps the given current state as the only entry in history.
  /// If [currentState] is null, history is completely cleared.
  void clearHistory([T? currentState]) {
    final previousCanUndo = canUndo;
    final previousCanRedo = canRedo;

    _history.clear();
    if (currentState != null) {
      _history.add(currentState);
      _currentIndex = 0;
    } else {
      _currentIndex = -1;
    }

    _notifyAvailabilityChanges(previousCanUndo, previousCanRedo);

    assert(() {
      log('$historyLogName<$T>: History cleared', name: historyLogName);
      return true;
    }());
  }

  /// Jumps to a specific index in history.
  ///
  /// Does nothing if index is out of bounds.
  /// Calls [applyHistoricalState] with the state at the given index.
  void jumpToHistory(int index) {
    if (index < 0 || index >= _history.length || index == _currentIndex) return;

    final previousCanUndo = canUndo;
    final previousCanRedo = canRedo;

    _isUndoRedo = true;
    _currentIndex = index;
    applyHistoricalState(_history[_currentIndex]);
    _isUndoRedo = false;

    _notifyAvailabilityChanges(previousCanUndo, previousCanRedo);

    assert(() {
      log('$historyLogName<$T>: Jumped to index $index', name: historyLogName);
      return true;
    }());
  }

  /// Gets the state at a specific history index without changing current state.
  T? peekHistory(int index) {
    if (index < 0 || index >= _history.length) return null;
    return _history[index];
  }

  /// Applies a historical state from undo/redo/jump operations.
  ///
  /// Subclasses must implement this to actually update the state in their
  /// underlying state holder (e.g., calling updateState on a ReactiveNotifier).
  @protected
  void applyHistoricalState(T state);

  /// Cleans up history resources.
  ///
  /// Should be called during disposal.
  @protected
  void disposeHistory() {
    _debounceTimer?.cancel();
  }
}
