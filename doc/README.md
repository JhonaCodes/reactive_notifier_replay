# ReactiveNotifier Replay Documentation

## Overview

ReactiveNotifier Replay is an undo/redo extension for ReactiveNotifier that adds time-travel debugging and state history tracking capabilities. Navigate through state changes with undo/redo, visualize history timelines, and group rapid changes with debounce support.

**Current Version**: 1.0.0

## Documentation Index

### Getting Started
- [Quick Start Guide](getting-started/quick-start.md) - Get up and running in minutes

### Core Features

#### Replay Components
- [ReplayReactiveNotifier<T>](features/replay-reactive-notifier.md) - Simple state with undo/redo
- [ReplayViewModel<T>](features/replay-viewmodel.md) - Complex state with history tracking
- [ReplayAsyncViewModelImpl<T>](features/replay-async-viewmodel.md) - Async operations with success state history
- [ReplayHistoryMixin<T>](features/replay-history-mixin.md) - Reusable history functionality

### Guides
- [Best Practices](guides/best-practices.md) - Patterns and recommendations
- [Migration Guide](guides/migration.md) - Migrating from manual history tracking

### Testing
- [Testing Guide](testing/testing-guide.md) - Complete testing patterns

### API Reference
- [API Reference](api-reference.md) - Complete API documentation

### Examples
- [Examples](examples.md) - Practical code examples

## Quick Reference

### Core Components

| Component | Purpose | Use When |
|-----------|---------|----------|
| `ReplayReactiveNotifier<T>` | Simple state with history | Counters, settings with undo |
| `ReplayViewModel<T>` | Complex state + business logic | Text editors, forms |
| `ReplayAsyncViewModelImpl<T>` | Async ops with success state history | Data lists with undo deletion |
| `ReplayHistoryMixin<T>` | Reusable history logic | Custom implementations |

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `canUndo` | `bool` | Whether undo is available |
| `canRedo` | `bool` | Whether redo is available |
| `historyLength` | `int` | Current number of states in history |
| `currentHistoryIndex` | `int` | Current position in history (0-indexed) |
| `isPerformingUndoRedo` | `bool` | Whether undo/redo operation is in progress |

### Key Methods

| Method | Description |
|--------|-------------|
| `undo()` | Undoes the last state change |
| `redo()` | Redoes the previously undone change |
| `clearHistory([T? state])` | Clears history, keeping current or specified state |
| `jumpToHistory(int index)` | Jumps to specific index in history |
| `peekHistory(int index)` | Gets state at index without changing current state |

### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `historyLimit` | `int` | 100 | Maximum states to keep |
| `debounceHistory` | `Duration?` | null | Group rapid changes |
| `onCanUndoChanged` | `Function(bool)?` | null | Undo availability callback |
| `onCanRedoChanged` | `Function(bool)?` | null | Redo availability callback |

## Architecture

```
+----------------------------------+
|        Replay Components          |
|  +----------------------------+   |
|  | ReplayReactiveNotifier<T>  |   |
|  | ReplayViewModel<T>         |   |
|  | ReplayAsyncViewModelImpl<T>|   |
|  +----------------------------+   |
|              |                    |
|              | uses               |
|              v                    |
|  +----------------------------+   |
|  |   ReplayHistoryMixin<T>    |   |
|  +----------------------------+   |
|              |                    |
|              | wraps/extends      |
|              v                    |
|  +----------------------------+   |
|  |   ReactiveNotifier Core    |   |
|  |  ReactiveNotifier<T>       |   |
|  |  ViewModel<T>              |   |
|  |  AsyncViewModelImpl<T>     |   |
|  +----------------------------+   |
+----------------------------------+
```

## Document Structure

```
docs/
|-- README.md                       # This file
|-- api-reference.md                # Complete API documentation
|-- examples.md                     # Practical examples
|-- getting-started/
|   +-- quick-start.md              # Installation and basic usage
|-- features/
|   |-- replay-reactive-notifier.md # ReplayReactiveNotifier docs
|   |-- replay-viewmodel.md         # ReplayViewModel docs
|   |-- replay-async-viewmodel.md   # ReplayAsyncViewModelImpl docs
|   +-- replay-history-mixin.md     # ReplayHistoryMixin docs
|-- guides/
|   |-- best-practices.md           # Best practices
|   +-- migration.md                # Migration guide
+-- testing/
    +-- testing-guide.md            # Testing patterns
```

## Related Packages

- [reactive_notifier](https://pub.dev/packages/reactive_notifier) - Core state management
- [reactive_notifier_hydrated](https://pub.dev/packages/reactive_notifier_hydrated) - Persistence extension
