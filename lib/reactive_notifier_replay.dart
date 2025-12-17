/// Undo/Redo functionality extension for ReactiveNotifier.
///
/// This library provides history tracking and undo/redo capabilities
/// for ReactiveNotifier state management.
///
/// ## Quick Start
///
/// ### Using ReplayReactiveNotifier (Simple State)
///
/// ```dart
/// mixin CounterService {
///   static final counter = ReplayReactiveNotifier<int>(
///     create: () => 0,
///     historyLimit: 50,
///   );
///
///   static void increment() => counter.updateState(counter.notifier + 1);
///   static void undo() => counter.undo();
///   static void redo() => counter.redo();
/// }
/// ```
///
/// ### Using ReplayViewModel (Complex State)
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
///   }
/// }
/// ```
///
/// ### Using ReplayAsyncViewModelImpl (Async State)
///
/// ```dart
/// class DataViewModel extends ReplayAsyncViewModelImpl<List<Item>> {
///   DataViewModel() : super(AsyncState.initial(), historyLimit: 50);
///
///   @override
///   Future<List<Item>> init() async {
///     return await repository.loadItems();
///   }
/// }
/// ```
///
/// ## Features
///
/// - **History Tracking**: Automatic recording of state changes
/// - **Undo/Redo**: Navigate through state history
/// - **Debounce Support**: Group rapid changes into single history entries
/// - **History Limit**: Configure maximum history size
/// - **Availability Callbacks**: React to undo/redo availability changes
/// - **Jump to History**: Navigate to any point in history
/// - **Peek History**: View historical states without changing current state
/// - **Shared Mixin**: Reusable `ReplayHistoryMixin` for custom implementations
library;

export 'src/replay_reactive_notifier.dart';
export 'src/replay_viewmodel.dart';
export 'src/replay_async_viewmodel.dart';
export 'src/replay_history_mixin.dart';
