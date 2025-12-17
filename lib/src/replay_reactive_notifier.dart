import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'replay_history_mixin.dart';

/// A wrapper around [ReactiveNotifier] that provides undo/redo functionality.
///
/// [ReplayReactiveNotifier] wraps a standard [ReactiveNotifier] and adds
/// automatic state history tracking with undo/redo capabilities.
///
/// ## Basic Usage
///
/// ```dart
/// mixin EditorService {
///   static final textState = ReplayReactiveNotifier<TextState>(
///     create: () => TextState.empty(),
///     historyLimit: 50,
///   );
/// }
///
/// // Update state (automatically recorded in history)
/// EditorService.textState.updateState(TextState(text: 'Hello'));
///
/// // Undo/Redo
/// EditorService.textState.undo();
/// EditorService.textState.redo();
/// ```
///
/// ## With Debounce (for text editors)
///
/// ```dart
/// final textState = ReplayReactiveNotifier<TextState>(
///   create: () => TextState.empty(),
///   historyLimit: 100,
///   debounceHistory: Duration(milliseconds: 300), // Group rapid changes
/// );
/// ```
///
/// ## UI Integration
///
/// ```dart
/// ReactiveBuilder<TextState>(
///   notifier: EditorService.textState,
///   build: (state, notifier, keep) => Column(
///     children: [
///       Text(state.text),
///       Row(
///         children: [
///           IconButton(
///             onPressed: EditorService.textState.canUndo
///               ? EditorService.textState.undo
///               : null,
///             icon: Icon(Icons.undo),
///           ),
///           IconButton(
///             onPressed: EditorService.textState.canRedo
///               ? EditorService.textState.redo
///               : null,
///             icon: Icon(Icons.redo),
///           ),
///         ],
///       ),
///     ],
///   ),
/// )
/// ```
class ReplayReactiveNotifier<T> extends ChangeNotifier
    with ReplayHistoryMixin<T> {
  /// The underlying ReactiveNotifier that holds the state.
  final ReactiveNotifier<T> _inner;

  VoidCallback? _innerListener;

  @override
  String get historyLogName => 'ReplayReactiveNotifier';

  /// The key used by the inner ReactiveNotifier.
  Key get keyNotifier => _inner.keyNotifier;

  /// Creates a [ReplayReactiveNotifier] with undo/redo functionality.
  ///
  /// Parameters:
  /// - [create]: Factory function for initial state
  /// - [historyLimit]: Maximum number of states to keep (default: 100)
  /// - [debounceHistory]: Optional debounce for grouping rapid changes
  /// - [onCanUndoChanged]: Callback when undo availability changes
  /// - [onCanRedoChanged]: Callback when redo availability changes
  /// - [related]: Related ReactiveNotifiers
  /// - [key]: Instance key
  /// - [autoDispose]: Enable auto-dispose
  ReplayReactiveNotifier({
    required T Function() create,
    int historyLimit = 100,
    Duration? debounceHistory,
    void Function(bool canUndo)? onCanUndoChanged,
    void Function(bool canRedo)? onCanRedoChanged,
    List<ReactiveNotifier>? related,
    Key? key,
    bool autoDispose = false,
  }) : _inner = ReactiveNotifier<T>(
          create,
          related: related,
          key: key,
          autoDispose: autoDispose,
        ) {
    // Initialize the history mixin
    initializeHistory(
      ReplayHistoryConfig(
        historyLimit: historyLimit,
        debounceHistory: debounceHistory,
        onCanUndoChanged: onCanUndoChanged,
        onCanRedoChanged: onCanRedoChanged,
      ),
    );

    // Record initial state
    recordInitialState(_inner.notifier);

    // Set up listener for state changes
    _innerListener = () {
      notifyListeners(); // Forward notifications
      if (!isPerformingUndoRedo) {
        handleStateChangeForHistory(_inner.notifier);
      }
    };
    _inner.addListener(_innerListener!);

    assert(() {
      log(
        'ReplayReactiveNotifier<$T>: Created with historyLimit=$historyLimit',
        name: 'ReplayReactiveNotifier',
      );
      return true;
    }());
  }

  /// Gets the current state value.
  T get notifier => _inner.notifier;

  @override
  @protected
  void applyHistoricalState(T state) {
    _inner.updateState(state);
  }

  /// Clears all history.
  ///
  /// Keeps the current state as the only entry in history.
  @override
  void clearHistory([T? currentState]) {
    super.clearHistory(currentState ?? _inner.notifier);
  }

  // ===== State management methods =====

  /// Updates the state and notifies listeners.
  void updateState(T newState) {
    _inner.updateState(newState);
  }

  /// Updates the state without notifying listeners.
  void updateSilently(T newState) {
    _inner.updateSilently(newState);
    if (!isPerformingUndoRedo) {
      handleStateChangeForHistory(newState);
    }
  }

  /// Transforms the state using a function and notifies listeners.
  void transformState(T Function(T data) transform) {
    _inner.transformState(transform);
  }

  /// Transforms the state using a function without notifying listeners.
  void transformStateSilently(T Function(T data) transform) {
    _inner.transformStateSilently(transform);
    if (!isPerformingUndoRedo) {
      handleStateChangeForHistory(_inner.notifier);
    }
  }

  /// Starts listening for changes in the state.
  T listen(void Function(T data) callback) {
    return _inner.listen(callback);
  }

  /// Stops listening for changes in the state.
  void stopListening() {
    _inner.stopListening();
  }

  /// Resets the state to the initial value and clears the history.
  ///
  /// Note: This method clears the history and re-initializes the tracking
  /// with the current state. For full instance recreation, use
  /// `ReactiveNotifier.reinitializeInstance()`.
  void resetHistory() {
    super.clearHistory(_inner.notifier);

    assert(() {
      log(
        'ReplayReactiveNotifier<$T>: History reset',
        name: 'ReplayReactiveNotifier',
      );
      return true;
    }());
  }

  /// Access to reference management for compatibility.
  void addReference(String referenceId) {
    _inner.addReference(referenceId);
  }

  void removeReference(String referenceId) {
    _inner.removeReference(referenceId);
  }

  @override
  void dispose() {
    disposeHistory();
    if (_innerListener != null) {
      _inner.removeListener(_innerListener!);
    }
    super.dispose();
  }
}
