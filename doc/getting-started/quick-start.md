# Quick Start Guide

## Installation

```yaml
dependencies:
  reactive_notifier: ^2.16.0
  reactive_notifier_replay: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Basic Usage

### 1. Simple State with ReplayReactiveNotifier

```dart
import 'package:reactive_notifier_replay/reactive_notifier_replay.dart';

// Define service with replay-enabled notifier
mixin CounterService {
  static final counter = ReplayReactiveNotifier<int>(
    create: () => 0,
    historyLimit: 50,
  );

  static void increment() => counter.updateState(counter.notifier + 1);
  static void decrement() => counter.updateState(counter.notifier - 1);
  static void undo() => counter.undo();
  static void redo() => counter.redo();
}

// Use in widgets - works with standard ReactiveBuilder
ReactiveBuilder<int>(
  notifier: CounterService.counter,
  build: (value, notifier, keep) {
    return Column(
      children: [
        Text('Count: $value'),
        Row(
          children: [
            IconButton(
              onPressed: CounterService.counter.canUndo
                ? CounterService.undo
                : null,
              icon: Icon(Icons.undo),
            ),
            IconButton(
              onPressed: CounterService.counter.canRedo
                ? CounterService.redo
                : null,
              icon: Icon(Icons.redo),
            ),
          ],
        ),
      ],
    );
  },
)
```

### 2. Complex State with ReplayViewModel

```dart
// Define state model
class DocumentState {
  final String content;
  final bool isDirty;

  const DocumentState({this.content = '', this.isDirty = false});

  DocumentState copyWith({String? content, bool? isDirty}) {
    return DocumentState(
      content: content ?? this.content,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

// Define ViewModel with history tracking
class DocumentViewModel extends ReplayViewModel<DocumentState> {
  DocumentViewModel() : super(
    DocumentState(),
    historyLimit: 100,
    debounceHistory: Duration(milliseconds: 300), // Group rapid typing
  );

  @override
  void init() {
    // Synchronous initialization
  }

  void updateContent(String content) {
    transformState((state) => state.copyWith(
      content: content,
      isDirty: true,
    ));
  }
}

// Define service
mixin DocumentService {
  static final document = ReactiveNotifier<DocumentViewModel>(
    () => DocumentViewModel(),
  );
}

// Use in widget
ReactiveViewModelBuilder<DocumentViewModel, DocumentState>(
  viewmodel: DocumentService.document.notifier,
  build: (state, viewModel, keep) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: viewModel.canUndo ? viewModel.undo : null,
              icon: Icon(Icons.undo),
            ),
            IconButton(
              onPressed: viewModel.canRedo ? viewModel.redo : null,
              icon: Icon(Icons.redo),
            ),
          ],
        ),
        TextField(
          controller: TextEditingController(text: state.content),
          onChanged: viewModel.updateContent,
        ),
      ],
    );
  },
)
```

### 3. Async Data with ReplayAsyncViewModelImpl

```dart
class TodoListViewModel extends ReplayAsyncViewModelImpl<List<TodoItem>> {
  TodoListViewModel() : super(
    AsyncState.initial(),
    historyLimit: 50,
  );

  @override
  Future<List<TodoItem>> init() async {
    return await repository.loadTodos();
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
    () => TodoListViewModel(),
  );
}

// Use in widget
ReactiveAsyncBuilder<TodoListViewModel, List<TodoItem>>(
  notifier: TodoService.todos.notifier,
  onLoading: () => CircularProgressIndicator(),
  onError: (error, stack) => Text('Error: $error'),
  onData: (items, viewModel, keep) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: viewModel.canUndo ? viewModel.undo : null,
              icon: Icon(Icons.undo),
            ),
            IconButton(
              onPressed: viewModel.canRedo ? viewModel.redo : null,
              icon: Icon(Icons.redo),
            ),
          ],
        ),
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

## Key Concepts

1. **Automatic History Tracking**: State changes are automatically recorded
2. **Debounce Support**: Group rapid changes into single history entries
3. **Success States Only (Async)**: ReplayAsyncViewModelImpl only tracks success states
4. **Hook Integration**: Uses onStateChanged/onAsyncStateChanged hooks automatically
5. **Memory Efficient**: Configurable history limits prevent unbounded growth

## Next Steps

- [ReplayReactiveNotifier](../features/replay-reactive-notifier.md) - Full API documentation
- [ReplayViewModel](../features/replay-viewmodel.md) - Complex state patterns
- [Best Practices](../guides/best-practices.md) - Recommended patterns
