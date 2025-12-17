import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'replay_history_mixin.dart';

/// An [AsyncViewModelImpl] that provides undo/redo functionality for success states.
///
/// [ReplayAsyncViewModelImpl] extends [AsyncViewModelImpl] to add automatic
/// state history tracking with undo/redo capabilities. Only success states
/// are recorded in history - loading, error, and initial states are not tracked.
///
/// ## Basic Usage
///
/// ```dart
/// class DocumentViewModel extends ReplayAsyncViewModelImpl<DocumentState> {
///   DocumentViewModel() : super(
///     AsyncState.initial(),
///     historyLimit: 100,
///   );
///
///   @override
///   Future<DocumentState> init() async {
///     return await repository.loadDocument();
///   }
///
///   Future<void> updateContent(String content) async {
///     final currentData = data;
///     if (currentData != null) {
///       updateState(currentData.copyWith(content: content));
///       // Automatically recorded in history
///     }
///   }
/// }
/// ```
///
/// ## With Debounce
///
/// ```dart
/// class TextEditorViewModel extends ReplayAsyncViewModelImpl<TextState> {
///   TextEditorViewModel() : super(
///     AsyncState.initial(),
///     historyLimit: 50,
///     debounceHistory: Duration(milliseconds: 300),
///   );
///
///   @override
///   Future<TextState> init() async {
///     return await repository.loadText();
///   }
///
///   void onTextChanged(String text) {
///     transformDataState((state) => state?.copyWith(text: text));
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
abstract class ReplayAsyncViewModelImpl<T> extends AsyncViewModelImpl<T>
    with ReplayHistoryMixin<T> {
  @override
  String get historyLogName => 'ReplayAsyncViewModelImpl';

  /// Creates a [ReplayAsyncViewModelImpl] with undo/redo functionality.
  ///
  /// Parameters:
  /// - [initialState]: Initial async state (typically AsyncState.initial())
  /// - [historyLimit]: Maximum number of success states to keep (default: 100)
  /// - [debounceHistory]: Optional debounce for grouping rapid changes
  /// - [onCanUndoChanged]: Callback when undo availability changes
  /// - [onCanRedoChanged]: Callback when redo availability changes
  /// - [loadOnInit]: If true, automatically calls init() (default: true)
  /// - [waitForContext]: If true, waits for BuildContext before init()
  ReplayAsyncViewModelImpl(
    super.initialState, {
    int historyLimit = 100,
    Duration? debounceHistory,
    void Function(bool canUndo)? onCanUndoChanged,
    void Function(bool canRedo)? onCanRedoChanged,
    super.loadOnInit,
    super.waitForContext,
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

    assert(() {
      log(
        'ReplayAsyncViewModelImpl<$T>: Created with historyLimit=$historyLimit',
        name: 'ReplayAsyncViewModelImpl',
      );
      return true;
    }());
  }

  /// Hook called after every async state change.
  ///
  /// Records success states in history (unless it's an undo/redo operation).
  @override
  @protected
  void onAsyncStateChanged(AsyncState<T> previous, AsyncState<T> next) {
    super.onAsyncStateChanged(previous, next);

    // Only record success states in history
    if (!isPerformingUndoRedo && next.isSuccess && next.data != null) {
      handleStateChangeForHistory(next.data as T);
    }
  }

  @override
  @protected
  void applyHistoricalState(T state) {
    updateState(state);
  }

  /// Clears all history.
  ///
  /// Keeps the current data as the only entry in history (if in success state).
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
