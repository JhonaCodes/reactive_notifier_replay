import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'replay_history_mixin.dart';

/// A [ViewModel] that provides undo/redo functionality.
///
/// [ReplayViewModel] extends [ViewModel] to add automatic state history
/// tracking with undo/redo capabilities.
///
/// ## Basic Usage
///
/// ```dart
/// class DocumentViewModel extends ReplayViewModel<DocumentState> {
///   DocumentViewModel() : super(
///     DocumentState.empty(),
///     historyLimit: 100,
///   );
///
///   void updateContent(String content) {
///     transformState((state) => state.copyWith(content: content));
///     // Automatically recorded in history
///   }
/// }
/// ```
///
/// ## With Debounce
///
/// ```dart
/// class TextEditorViewModel extends ReplayViewModel<TextState> {
///   TextEditorViewModel() : super(
///     TextState.empty(),
///     historyLimit: 50,
///     debounceHistory: Duration(milliseconds: 300),
///   );
///
///   void onTextChanged(String text) {
///     transformState((state) => state.copyWith(text: text));
///     // Rapid typing will be grouped into single history entries
///   }
/// }
/// ```
///
/// ## Service Pattern
///
/// ```dart
/// mixin DocumentService {
///   static final document = ReactiveNotifier<DocumentViewModel>(
///     () => DocumentViewModel(),
///   );
///
///   static void undo() => document.notifier.undo();
///   static void redo() => document.notifier.redo();
/// }
/// ```
abstract class ReplayViewModel<T> extends ViewModel<T>
    with ReplayHistoryMixin<T> {
  @override
  String get historyLogName => 'ReplayViewModel';

  /// Creates a [ReplayViewModel] with undo/redo functionality.
  ///
  /// Parameters:
  /// - [initialState]: Initial state
  /// - [historyLimit]: Maximum number of states to keep (default: 100)
  /// - [debounceHistory]: Optional debounce for grouping rapid changes
  /// - [onCanUndoChanged]: Callback when undo availability changes
  /// - [onCanRedoChanged]: Callback when redo availability changes
  ReplayViewModel(
    super.initialState, {
    int historyLimit = 100,
    Duration? debounceHistory,
    void Function(bool canUndo)? onCanUndoChanged,
    void Function(bool canRedo)? onCanRedoChanged,
  }) {
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
    recordInitialState(data);

    assert(() {
      log(
        'ReplayViewModel<$T>: Created with historyLimit=$historyLimit',
        name: 'ReplayViewModel',
      );
      return true;
    }());
  }

  /// Hook called after every state change.
  ///
  /// Records state in history (unless it's an undo/redo operation).
  @override
  @protected
  void onStateChanged(T previous, T next) {
    super.onStateChanged(previous, next);
    if (!isPerformingUndoRedo) {
      handleStateChangeForHistory(next);
    }
  }

  @override
  @protected
  void applyHistoricalState(T state) {
    updateState(state);
  }

  /// Clears all history.
  ///
  /// Keeps the current state as the only entry in history.
  @override
  void clearHistory([T? currentState]) {
    super.clearHistory(currentState ?? data);
  }

  @override
  void dispose() {
    disposeHistory();
    super.dispose();
  }
}
