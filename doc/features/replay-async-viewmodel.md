# ReplayAsyncViewModelImpl<T>

An `AsyncViewModelImpl` that provides undo/redo functionality for **success states only**.

## Overview

`ReplayAsyncViewModelImpl<T>` extends `AsyncViewModelImpl<T>` to add automatic state history tracking with undo/redo capabilities. Only success states are recorded in history - loading, error, and initial states are NOT tracked.

## When to Use

| Scenario | Use ReplayAsyncViewModelImpl<T> |
|----------|--------------------------------|
| API calls with undo support | Yes |
| Database operations with history | Yes |
| Data lists with undo deletion | Yes |
| Async initialization required | Yes |
| Sync initialization | No (use ReplayViewModel) |
| Simple state | No (use ReplayReactiveNotifier) |

## Basic Usage

```dart
// Define model
class TodoItem {
  final String id;
  final String title;
  final bool completed;

  TodoItem({required this.id, required this.title, this.completed = false});

  TodoItem copyWith({String? title, bool? completed}) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }
}

// Define async ViewModel with history
class TodoListViewModel extends ReplayAsyncViewModelImpl<List<TodoItem>> {
  final TodoRepository _repository;

  TodoListViewModel(this._repository) : super(
    AsyncState.initial(),
    historyLimit: 50,
  );

  @override
  Future<List<TodoItem>> init() async {
    return await _repository.loadTodos();
  }

  void toggleTodo(String id) {
    transformDataState((items) {
      return items?.map((item) {
        if (item.id == id) {
          return item.copyWith(completed: !item.completed);
        }
        return item;
      }).toList();
    });
    // This change is recorded in history
  }

  void deleteTodo(String id) {
    transformDataState((items) {
      return items?.where((item) => item.id != id).toList();
    });
    // User can undo this deletion!
  }
}

// Define service
mixin TodoService {
  static final todos = ReactiveNotifier<TodoListViewModel>(
    () => TodoListViewModel(TodoRepository()),
  );
}
```

## Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `initialState` | `AsyncState<T>` | required | Initial async state (typically `AsyncState.initial()`) |
| `historyLimit` | `int` | 100 | Maximum success states to keep |
| `debounceHistory` | `Duration?` | null | Debounce for grouping rapid changes |
| `onCanUndoChanged` | `void Function(bool)?` | null | Callback when undo availability changes |
| `onCanRedoChanged` | `void Function(bool)?` | null | Callback when redo availability changes |
| `loadOnInit` | `bool` | true | Whether to call init() automatically |
| `waitForContext` | `bool` | false | Whether to wait for BuildContext before init() |

## Properties

### Async Properties (from AsyncViewModelImpl)

| Property | Type | Description |
|----------|------|-------------|
| `isLoading` | `bool` | Loading state check |
| `hasData` | `bool` | Success state check |
| `error` | `Object?` | Current error |
| `stackTrace` | `StackTrace?` | Error stack trace |
| `data` | `T` | Current data (throws if error) |

### From ReplayHistoryMixin<T>

| Property | Type | Description |
|----------|------|-------------|
| `canUndo` | `bool` | Whether undo is available |
| `canRedo` | `bool` | Whether redo is available |
| `historyLength` | `int` | Number of success states in history |
| `currentHistoryIndex` | `int` | Current position in history (0-indexed) |
| `isPerformingUndoRedo` | `bool` | Whether undo/redo operation is in progress |

## Methods

### Lifecycle Methods (from AsyncViewModelImpl)

| Method | Description |
|--------|-------------|
| `init()` | Async initialization (MUST override, returns `Future<T>`) |
| `dispose()` | Cleanup and disposal |
| `reload()` | Reinitialize ViewModel |
| `onResume(data)` | Post-initialization hook |
| `setupListeners()` | Register external listeners |
| `removeListeners()` | Remove external listeners |

### Async-Specific State Methods

| Method | Description |
|--------|-------------|
| `transformDataState(fn)` | Transform only data (records history) |
| `transformDataStateSilently(fn)` | Transform data silently (records history) |
| `loadingState()` | Set loading state (NOT recorded) |
| `errorState(error, stack)` | Set error state (NOT recorded) |

### State Update Methods

| Method | Notifies | Records History | Description |
|--------|----------|-----------------|-------------|
| `updateState(data)` | Yes | Yes (success only) | Sets success state |
| `updateSilently(data)` | No | Yes (success only) | Sets success silently |
| `transformState(fn)` | Yes | Yes (success only) | Transforms AsyncState |
| `transformStateSilently(fn)` | No | Yes (success only) | Transforms silently |

### History Methods

| Method | Return | Description |
|--------|--------|-------------|
| `undo()` | `void` | Reverts to previous success state |
| `redo()` | `void` | Restores next success state |
| `clearHistory([T? currentState])` | `void` | Clears history, keeping current data |
| `jumpToHistory(int index)` | `void` | Jumps to specific success state |
| `peekHistory(int index)` | `T?` | Gets data at index without changing |

### Pattern Matching (from AsyncViewModelImpl)

| Method | Description |
|--------|-------------|
| `match()` | Exhaustive (5 states) |
| `when()` | Simplified (4 states) |

## Important: Success States Only

**Key behavior**: Only success states with data are recorded in history.

```
State Flow:
initial --> loading --> success(data1) --> success(data2) --> error
                             |                  |
                             v                  v
                        Recorded            Recorded
                        in history          in history

History: [data1, data2]
         Not recorded: initial, loading, error
```

This means:
- `loadingState()` does NOT record to history
- `errorState()` does NOT record to history
- Only `success` states with non-null data are recorded
- Undo/Redo navigates between success states only

## Lifecycle Diagram

```
+----------------------------------------------------------+
|            ReplayAsyncViewModelImpl Lifecycle              |
+----------------------------------------------------------+
|                                                            |
|  Constructor --> loadOnInit? --> init() (async)           |
|       |              |              |                      |
|       v              v              v                      |
|   AsyncState     If true:      Returns T                  |
|   .initial()     auto-load     (success state)            |
|                                                            |
+----------------------------------------------------------+
|                                                            |
|  State Flow (onAsyncStateChanged hook):                   |
|                                                            |
|  initial --> loading --> success OR error                 |
|                               |                            |
|                               v                            |
|                     Only success states                   |
|                     recorded in history                   |
|                                                            |
+----------------------------------------------------------+
|                                                            |
|  undo() / redo():                                         |
|       |                                                    |
|       v                                                    |
|  Navigate between success states only                     |
|  (isPerformingUndoRedo prevents double recording)         |
|                                                            |
+----------------------------------------------------------+
```

## Examples

### CRUD Operations with Undo

```dart
class ItemsViewModel extends ReplayAsyncViewModelImpl<List<Item>> {
  ItemsViewModel() : super(AsyncState.initial(), historyLimit: 30);

  @override
  Future<List<Item>> init() async {
    return await api.fetchItems();
  }

  void addItem(Item item) {
    transformDataState((items) => [...?items, item]);
    // User can undo adding
  }

  void deleteItem(String id) {
    transformDataState((items) => items?.where((i) => i.id != id).toList());
    // User can undo deletion!
  }

  void updateItem(String id, String newTitle) {
    transformDataState((items) => items?.map((i) {
      if (i.id == id) return i.copyWith(title: newTitle);
      return i;
    }).toList());
    // User can undo edit
  }
}
```

### UI Integration

```dart
ReactiveAsyncBuilder<TodoListViewModel, List<TodoItem>>(
  notifier: TodoService.todos.notifier,
  onLoading: () => Center(child: CircularProgressIndicator()),
  onError: (error, stack) => Center(child: Text('Error: $error')),
  onData: (items, viewModel, keep) {
    return Column(
      children: [
        // Undo/Redo toolbar
        keep(Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: viewModel.canUndo ? viewModel.undo : null,
              icon: Icon(Icons.undo),
            ),
            Text('${viewModel.currentHistoryIndex + 1}/${viewModel.historyLength}'),
            IconButton(
              onPressed: viewModel.canRedo ? viewModel.redo : null,
              icon: Icon(Icons.redo),
            ),
          ],
        )),
        // Todo list
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final todo = items[index];
              return ListTile(
                title: Text(todo.title),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => viewModel.deleteTodo(todo.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  },
)
```

### Offline-First with History

```dart
class OfflineFirstViewModel extends ReplayAsyncViewModelImpl<List<Item>> {
  List<Item>? _cachedData;

  OfflineFirstViewModel() : super(
    AsyncState.initial(),
    historyLimit: 20,
  );

  @override
  void onAsyncStateChanged(AsyncState<List<Item>> previous, AsyncState<List<Item>> next) {
    super.onAsyncStateChanged(previous, next);
    if (next.isSuccess) {
      _cachedData = next.data;
    }
  }

  @override
  Future<List<Item>> init() async {
    try {
      return await api.fetchItems();
    } catch (e) {
      // If we have cached data, keep using it
      if (_cachedData != null) {
        return _cachedData!;
      }
      rethrow;
    }
  }
}
```

### With Context Access

```dart
class ThemeAwareViewModel extends ReplayAsyncViewModelImpl<ThemeData> {
  ThemeAwareViewModel() : super(
    AsyncState.initial(),
    waitForContext: true,  // Wait for BuildContext
    historyLimit: 10,
  );

  @override
  Future<ThemeData> init() async {
    final theme = Theme.of(requireContext('theme initialization'));
    return await loadThemeBasedData(theme);
  }
}
```

## Comparison: ViewModel vs AsyncViewModel History

| Aspect | ReplayViewModel | ReplayAsyncViewModelImpl |
|--------|-----------------|--------------------------|
| Init | Synchronous | Asynchronous |
| What's tracked | All state changes | Success states only |
| Loading states | N/A | NOT tracked |
| Error states | N/A | NOT tracked |
| Undo behavior | Reverts to previous state | Reverts to previous success data |
| Use case | Forms, editors | API data, CRUD lists |

## Related Documentation

- [ReplayReactiveNotifier](replay-reactive-notifier.md) - For simple state
- [ReplayViewModel](replay-viewmodel.md) - For sync complex state
- [ReplayHistoryMixin](replay-history-mixin.md) - For custom implementations
- [Best Practices](../guides/best-practices.md) - Recommended patterns
