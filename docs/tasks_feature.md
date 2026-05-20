# Tasks Feature Documentation

## Overview
Complete to-do list feature integrated into the Aether app, replacing the fake hardcoded tasks on the home screen with real, functional tasks stored in Firestore.

## Features Implemented

### ✅ Task Model
- **File**: `lib/models/task_model.dart`
- **Fields**:
  - `id`: Unique identifier
  - `title`: Task title
  - `description`: Task details
  - `dueDate`: DateTime for when task is due
  - `priority`: 'low', 'medium', or 'high'
  - `isCompleted`: Boolean completion status
- **Methods**:
  - `toMap()`: Convert to Firestore format
  - `fromMap()`: Create from Firestore data
  - `copyWith()`: Create modified copy

### ✅ Add Task Screen
- **File**: `lib/screens/tasks/add_task_screen.dart`
- **Features**:
  - Form validation for title (required)
  - Title and description text fields
  - Date picker for due date
  - Time picker for due time
  - Priority selector (Low/Medium/High) with color-coded chips
  - Save button with loading state
  - Dark mode support
  - Neo-brutalist design matching app theme

### ✅ Home Screen Integration
- **File**: `lib/screens/home/home_screen.dart`
- **Changes**:
  - Removed hardcoded fake task cards
  - Added StreamBuilder for real-time task updates
  - Shows up to 3 upcoming incomplete tasks
  - Tasks sorted by due date (earliest first)
  - "+ Add" button to create new tasks
  - Empty state when no tasks exist
  - Mark complete button (checkmark icon)
  - Priority color indicators (red/orange/green)
  - Dark mode support

### ✅ Firestore Structure
```
users/{uid}/tasks/{taskId}
  ├─ title: string
  ├─ description: string
  ├─ dueDate: ISO8601 string
  ├─ priority: 'low' | 'medium' | 'high'
  ├─ isCompleted: boolean
  └─ createdAt: timestamp
```

### ✅ Routing
- **Route**: `/add-task`
- **Added to**: `lib/main.dart`

## User Flow

1. **View Tasks**: Home screen shows upcoming tasks automatically
2. **Add Task**: Tap "+ Add" button → Fill form → Save
3. **Complete Task**: Tap checkmark icon on any task
4. **Real-time Updates**: Tasks update instantly via Firestore streams

## Priority Colors
- 🔴 **High**: Red
- 🟠 **Medium**: Orange  
- 🟢 **Low**: Green

## Empty State
When no tasks exist, displays:
> "No tasks yet. Tap + Add to create one!"

## Completion Feedback
When marking a task complete:
> "Task completed! 🎉"

## Dark Mode
All task-related screens fully support dark mode with appropriate color adjustments.

## Technical Details

### Dependencies Used
- `cloud_firestore`: Task storage and real-time updates
- `firebase_auth`: User authentication for task ownership
- `intl`: Date/time formatting
- `google_fonts`: Typography (Plus Jakarta Sans)

### Query Optimization
- Only fetches incomplete tasks
- Limits to 3 tasks on home screen
- Ordered by due date for relevance

### State Management
- Local `setState` for form state
- StreamBuilder for Firestore real-time updates
- Loading states for async operations

## Future Enhancements (Not Implemented)
- Edit existing tasks
- Delete tasks
- View all tasks screen
- Task categories/tags
- Notifications for due tasks
- Recurring tasks
- Task search/filter
