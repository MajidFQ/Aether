# Aether — Mobile Application Development Report

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Tech Stack](#2-tech-stack)
3. [Architecture](#3-architecture)
4. [Features & Implementation](#4-features--implementation)
   - 4.1 [Authentication](#41-authentication)
   - 4.2 [AI Chat](#42-ai-chat)
   - 4.3 [To-Do List](#43-to-do-list)
   - 4.4 [Flashcards](#44-flashcards)
   - 4.5 [Study Timer](#45-study-timer)
   - 4.6 [Profile & Daily Goals](#46-profile--daily-goals)
   - 4.7 [Dark Mode](#47-dark-mode)
   - 4.8 [Edit Profile & About Me](#48-edit-profile--about-me)
5. [Firestore Data Structure](#5-firestore-data-structure)
6. [Security](#6-security)
7. [UI Design System](#7-ui-design-system)
8. [Screen Inventory](#8-screen-inventory)
9. [Project Statistics](#9-project-statistics)

---

## 1. Project Overview

**Aether** is a cross-platform (Android + Web) study assistant application built with Flutter and Firebase. It is designed to help students stay organized, focused, and productive by combining four core study tools — AI chat, task management, flashcard studying, and a focus timer — into a single cohesive app.

The app is built around a clean **neo-brutalist design language**: thick black borders, offset box shadows, a bold purple accent color (`#5B4FFF`), and the Plus Jakarta Sans typeface. Every screen is fully dark-mode aware.

**App Overview Screenshot:**

| Home Screen (Light) | Home Screen (Dark) |
|:---:|:---:|
| *(paste screenshot here)* | *(paste screenshot here)* |
| `home_light.png` | `home_dark.png` |

---

## 2. Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Frontend** | Flutter 3.x (Dart) | Cross-platform UI |
| **Authentication** | Firebase Auth | Email/Password + Google Sign-In |
| **Database** | Cloud Firestore | Real-time NoSQL storage |
| **AI** | Groq API (`llama-3.3-70b`) | AI chat responses |
| **State Management** | Provider + `setState` | Theme, auth, local UI state |
| **Local Storage** | SharedPreferences | Dark mode preference |
| **HTTP** | `http` package | Groq API calls |
| **Environment** | `flutter_dotenv` | Secure API key loading |
| **Fonts** | `google_fonts` | Plus Jakarta Sans |

---

## 3. Architecture

```
lib/
├── main.dart                  ← App entry, Firebase init, route table, ThemeProvider
├── firebase_options.dart      ← Auto-generated Firebase config
│
├── models/
│   └── task_model.dart        ← Task data class with Firestore serialization
│
├── providers/
│   └── theme_provider.dart    ← ChangeNotifier for dark/light mode
│
├── services/
│   ├── auth_service.dart      ← Firebase Auth + Google Sign-In wrapper
│   └── groq_service.dart      ← Groq API HTTP client
│
├── utils/
│   └── theme_helper.dart      ← getBackgroundColor(), getCardColor(), etc.
│
├── widgets/
│   ├── custom_text_field.dart ← Reusable neo-brutalist text input
│   └── social_button.dart     ← Google sign-in button
│
└── screens/
    ├── auth/
    │   ├── login_screen.dart
    │   └── register_screen.dart
    ├── home/
    │   └── home_screen.dart
    ├── chat/
    │   ├── chat_screen.dart
    │   └── chat_history_screen.dart
    ├── flashcards/
    │   ├── deck_list_screen.dart
    │   ├── create_deck_screen.dart
    │   └── study_screen.dart
    ├── timer/
    │   └── timer_screen.dart
    ├── tasks/
    │   └── add_task_screen.dart
    └── profile/
        ├── profile_screen.dart
        └── edit_profile_screen.dart
```

**State management strategy:**
- `ThemeProvider` (Provider) — app-wide dark mode, consumed by `MaterialApp` via `Consumer`
- `AuthService` (Provider) — Firebase Auth instance, injected at root
- Everything else — local `setState` per screen, `StreamBuilder` for Firestore live data

---

## 4. Features & Implementation

---

### 4.1 Authentication

**Screenshots:**

| Login Screen | Register Screen |
|:---:|:---:|
| *(paste screenshot here)* | *(paste screenshot here)* |
| `login.png` | `register.png` |

**What it does:**
Users register or log in using Email/Password or Google Sign-In. The session persists across app restarts — the user never needs to log in again unless they explicitly log out.

**How it works:**

The `AuthService` class wraps `FirebaseAuth.instance` and exposes clean methods:

```
signInWithEmailAndPassword()
registerWithEmail()
signInWithGoogle()
sendPasswordResetEmail()
signOut()
```

In `main.dart`, an `AuthWrapper` widget uses a `StreamBuilder` on `FirebaseAuth.instance.authStateChanges()`. This stream emits a `User` when logged in and `null` when logged out — the app routes automatically without any manual session checks.

**Google Sign-In** is handled differently per platform:
- **Web:** `signInWithPopup(GoogleAuthProvider())` — Firebase opens a browser popup
- **Android:** `google_sign_in` package runs `authenticate()`, returns an ID token, which is passed to Firebase as a `GoogleAuthProvider.credential`

Both paths are unified inside a single `signInWithGoogle()` method using `kIsWeb`.

**Email validation (strict):**
The register screen validates email client-side before any Firebase call:
- Exactly one `@` symbol
- Local part: only valid characters, no leading/trailing dots, no consecutive dots
- Domain: each label validated individually, no leading/trailing hyphens
- TLD: letters only, 2–6 characters
- Blocks patterns like `user@domain.com.com` (duplicate TLD detection)

**Password validation:**
- Minimum 6 characters
- Must contain at least one letter
- Must contain at least one number

Firebase error codes (`wrong-password`, `user-not-found`, `email-already-in-use`) are mapped to inline field errors — not generic SnackBars.

**Password reset:** "Forgot?" opens a dialog, user enters email, `sendPasswordResetEmail()` sends a Firebase reset link.

---

### 4.2 AI Chat

**Screenshots:**

| Chat Screen | Chat History |
|:---:|:---:|
| *(paste screenshot here)* | *(paste screenshot here)* |
| `chat.png` | `chat_history.png` |

**What it does:**
Users converse with an AI study assistant. Messages appear as styled chat bubbles. Conversations can be named and saved to Firestore. A history screen lets users browse, reopen, and rename saved chats.

**How it works:**

The AI is powered by **Groq's free API** using the `llama-3.3-70b-versatile` model. Groq uses the same request/response format as OpenAI:

```
POST https://api.groq.com/openai/v1/chat/completions

Body: {
  "model": "llama-3.3-70b-versatile",
  "messages": [{ "role": "user", "content": "..." }],
  "max_tokens": 1024
}

Response: {
  "choices": [{ "message": { "content": "AI reply..." } }]
}
```

The `GroqService` class handles the HTTP call using the `http` package. The API key is loaded from `assets/.env` via `flutter_dotenv` — never hardcoded.

**Message model:**
Each message is a `Message` object:
```dart
class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
}
```
`toMap()` / `fromMap()` handle Firestore serialization.

**Saving chats:**
The save button opens a dialog asking the user to name the chat. The full `messages` list is serialized and written to `users/{uid}/chats/{autoId}` with `firstQuestion` (chat name) and `createdAt`.

**Chat History:**
A `StreamBuilder` listens to the chats collection ordered by `createdAt` descending. Tapping a tile reconstructs `Message` objects and opens `ChatScreen` with `initialMessages` pre-populated. Long-press or edit icon opens a rename dialog that calls `doc.reference.update({'firstQuestion': newName})`.

---

### 4.3 To-Do List

**Screenshots:**

| Home — Tasks | Add Task | Task Detail |
|:---:|:---:|:---:|
| *(paste screenshot here)* | *(paste screenshot here)* | *(paste screenshot here)* |
| `tasks_home.png` | `add_task.png` | `task_detail.png` |

**What it does:**
Users create tasks with a title, description, due date/time, and priority (low/medium/high). The home screen shows up to 3 upcoming incomplete tasks in real time. Tapping a task opens a detail bottom sheet; tapping the checkmark marks it complete.

**How it works:**

The `Task` model uses `toMap()` / `fromMap()` for Firestore serialization. `dueDate` is stored as an ISO 8601 string for reliable sorting and parsing.

`AddTaskScreen` uses:
- `Form` with `GlobalKey<FormState>` for validation
- `showDatePicker()` + `showTimePicker()` — Flutter built-ins, combined into a single `DateTime`
- Custom priority chips — color-coded (🟢 green / 🟠 orange / 🔴 red), selected chip fills with its color

On the home screen, a `StreamBuilder` runs this Firestore query:
```
users/{uid}/tasks
  .where('isCompleted', isEqualTo: false)
  .orderBy('dueDate')
  .limit(3)
```

This query requires a **composite index** in Firestore (isCompleted + dueDate), created in the Firebase Console. The stream updates the UI in real time — no manual refresh.

Tapping a task opens a `ModalBottomSheet` with the full title, formatted due date, description, and a green "Mark as Complete" button. Completing calls `doc.reference.update({'isCompleted': true})`, which removes it from the stream instantly.

---

### 4.4 Flashcards

**Screenshots:**

| Deck List | Create Deck | Study Screen |
|:---:|:---:|:---:|
| *(paste screenshot here)* | *(paste screenshot here)* | *(paste screenshot here)* |
| `deck_list.png` | `create_deck.png` | `study.png` |

**What it does:**
Users create named decks of up to 10 question/answer cards. Studying a deck shows cards one at a time — tap to flip and reveal the answer. "Got it!" and "Study again" buttons track progress. A score dialog appears at the end.

**How it works:**

`CreateDeckScreen` maintains a dynamic `List<Map>` of card pairs. Cards can be added (up to 10) or deleted. On save, the entire deck is written as a single Firestore document with a `cards` array.

`DeckListScreen` uses a `StreamBuilder` on the decks collection. Each tile shows the deck name and card count. Tapping "Study" passes the deck data via:
```dart
Navigator.pushNamed(context, '/study', arguments: deckData)
```

`StudyScreen` receives data from `ModalRoute.of(context)!.settings.arguments`. Local state tracks:
- `currentIndex` — which card is showing
- `showAnswer` — whether the card is flipped
- `correctCount` — score accumulator

Tapping the card toggles `showAnswer`. "Got it!" increments `correctCount` and advances. When all cards are done, an `AlertDialog` shows the final score.

---

### 4.5 Study Timer

**Screenshots:**

| Timer Screen | Duration Picker |
|:---:|:---:|
| *(paste screenshot here)* | *(paste screenshot here)* |
| `timer.png` | `timer_picker.png` |

**What it does:**
A Pomodoro-style focus timer, default 25 minutes, customizable from 1 to 120 minutes. Users can start, pause, and reset. Completed sessions are saved to Firestore. Today's total study time is shown at the bottom.

**How it works:**

The timer uses Dart's `Timer.periodic`:
```dart
_timer = Timer.periodic(Duration(seconds: 1), (_) {
  if (_secondsRemaining <= 1) {
    // session complete
  } else {
    setState(() => _secondsRemaining--);
  }
});
```

The circular progress indicator fills as time passes:
```dart
value = 1 - (secondsRemaining / sessionSeconds)
```

**Duration customization:**
A bottom sheet contains:
- A `Slider` (1–120 min, 119 divisions) with live minute preview
- Quick-pick preset chips: 5, 10, 15, 25, 30, 45, 60, 90 min
- The AppBar duration button is disabled while the timer is running

On completion, the session is written to Firestore:
```
users/{uid}/sessions/{autoId}
  duration: 25   (minutes)
  completedAt: <server timestamp>
```

This data is later read by the Profile screen to calculate total study time and today's progress toward the daily goal.

---

### 4.6 Profile & Daily Goals

**Screenshots:**

| Profile Screen | Goal Picker |
|:---:|:---:|
| *(paste screenshot here)* | *(paste screenshot here)* |
| `profile.png` | `goal_picker.png` |

**What it does:**
A full profile screen showing the user's avatar, name, email, and optional personal info. A daily study goal card shows today's progress with a progress bar. Four stat cards pull live data from Firestore.

**How it works:**

**Daily goal** is stored in `users/{uid}` as `dailyGoal`. A `Slider` bottom sheet (15–180 min) lets the user change it. Saving uses `SetOptions(merge: true)` to update only that field:
```dart
FirebaseFirestore.instance
  .collection('users').doc(uid)
  .set({'dailyGoal': newGoal}, SetOptions(merge: true));
```

**Progress bar:**
```dart
LinearProgressIndicator(
  value: (todayMinutes / dailyGoal).clamp(0.0, 1.0)
)
```
Today's minutes come from reading the sessions subcollection and filtering by today's date.

**Stats calculation:**
On screen load, 4 Firestore reads run:
1. Sessions — sum all `duration` values; filter by today's date for daily progress
2. Tasks — count where `isCompleted == true`
3. Decks — count all documents
4. Chats — count all documents

Results populate a 2×2 `GridView` of stat cards.

**Logout confirmation:**
Tapping the logout icon slides up a `ModalBottomSheet` with a red icon, description, "Yes, log me out" (red), and "Cancel" buttons — preventing accidental logouts.

---

### 4.7 Dark Mode

**Screenshots:**

| Light Mode | Dark Mode |
|:---:|:---:|
| *(paste screenshot here)* | *(paste screenshot here)* |
| `light_mode.png` | `dark_mode.png` |

**What it does:**
A toggle in the home screen AppBar and in Profile settings switches the entire app between light and dark themes. The preference persists across app restarts.

**How it works:**

`ThemeProvider` extends `ChangeNotifier`:
```dart
Future<void> toggleTheme() async {
  _isDark = !_isDark;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isDark', _isDark);
  notifyListeners();
}
```

On startup, `_loadTheme()` reads `SharedPreferences` and calls `notifyListeners()` before the first frame.

In `main.dart`, `MaterialApp` is wrapped in `Consumer<ThemeProvider>`:
```dart
themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
theme: ThemeData(brightness: Brightness.light, ...),
darkTheme: ThemeData(brightness: Brightness.dark, ...),
```

Since all screens had hardcoded colors, a `theme_helper.dart` utility provides:
```dart
getBackgroundColor(context)  // #F5F5F7 or #1E1E2E
getCardColor(context)        // white or #2A2A3E
getTextColor(context)        // black or white
getMutedTextColor(context)   // grey variants
```
Every screen calls these instead of hardcoded values — making dark mode work across all 12 screens.

---

### 4.8 Edit Profile & About Me

**Screenshots:**

| Edit Profile | About Me Card (Home) |
|:---:|:---:|
| *(paste screenshot here)* | *(paste screenshot here)* |
| `edit_profile.png` | `about_me.png` |

**What it does:**
Users can add personal info — name, age, education, hobbies, and a bio. This info appears on the Profile screen and as an "About Me" card on the Home screen. All fields except name are optional.

**How it works:**

`EditProfileScreen` loads existing data from Firestore on init, pre-fills all fields. On save:
1. `FirebaseAuth.currentUser.updateDisplayName(name)` — updates the Auth profile
2. `Firestore.set({...}, SetOptions(merge: true))` — saves age, education, hobbies, bio without overwriting other fields like `dailyGoal`

Returning `Navigator.pop(context, true)` signals the caller to reload:
```dart
final result = await Navigator.pushNamed(context, '/edit-profile');
if (result == true) _loadProfile();
```

The **About Me card** on the home screen:
- Shows a "Tell us about yourself" prompt with a "+ Add Info" button when empty
- When filled, displays bio text and info chips (age, education, hobbies) with relevant icons
- Reloads automatically after editing

The avatar preview in `EditProfileScreen` uses `ValueListenableBuilder` on the name controller — the initial letter updates live as the user types their name.

---

## 5. Firestore Data Structure

```
Firestore (default database)
│
└── users/
    └── {uid}/                         ← User profile document
        │   dailyGoal: 60              (int, minutes)
        │   bio: "..."                 (string)
        │   education: "..."           (string)
        │   hobbies: "..."             (string)
        │   age: 20                    (int, nullable)
        │   updatedAt: <timestamp>
        │
        ├── chats/
        │   └── {chatId}/
        │       messages: [            (array of maps)
        │         { text, isUser, timestamp }
        │       ]
        │       firstQuestion: "..."   (chat name)
        │       createdAt: <timestamp>
        │
        ├── tasks/
        │   └── {taskId}/
        │       title: "..."
        │       description: "..."
        │       dueDate: "2026-05-21T15:00:00" (ISO 8601)
        │       priority: "high"       (low / medium / high)
        │       isCompleted: false
        │       createdAt: <timestamp>
        │
        ├── decks/
        │   └── {deckId}/
        │       name: "Physics Ch.3"
        │       cards: [               (array of maps)
        │         { question: "...", answer: "..." }
        │       ]
        │       createdAt: <timestamp>
        │
        └── sessions/
            └── {sessionId}/
                duration: 25           (int, minutes)
                completedAt: <timestamp>
```

**Composite index required:**
The tasks query (`where isCompleted + orderBy dueDate`) requires a composite index created in the Firebase Console.

---

## 6. Security

| Concern | Solution |
|---|---|
| API key exposure | Stored in `assets/.env`, loaded via `flutter_dotenv`, excluded from Git via `.gitignore` |
| Unauthorized data access | All Firestore paths are under `users/{uid}/` — users can only access their own data |
| Weak passwords | Client-side: min 6 chars, must contain letter + number. Firebase enforces minimum server-side |
| Invalid emails | Multi-step client-side validation before any Firebase call |
| Accidental logout | Confirmation bottom sheet before `signOut()` is called |

---

## 7. UI Design System

Aether uses a consistent **neo-brutalist** design language across all 12 screens:

| Token | Value |
|---|---|
| Primary color | `#5B4FFF` (purple) |
| Background (light) | `#F5F5F7` |
| Background (dark) | `#1E1E2E` |
| Card (light) | `#FFFFFF` |
| Card (dark) | `#2A2A3E` |
| Border | `#000000`, 2px solid |
| Shadow | `Offset(4, 4)`, black, blur 0 |
| Font | Plus Jakarta Sans (Google Fonts) |
| Border radius | 12–16px |

**Reusable components:**
- `CustomTextField` — labeled input with error state, neo-brutalist border
- `SocialButton` — Google sign-in button
- `_ActionCard` — home screen feature cards
- `_StatCard` — profile stats grid
- `_InfoChip` — about me tags

---

## 8. Screen Inventory

| # | Screen | Route | Key Feature |
|---|---|---|---|
| 1 | Login | `/login` | Email + Google sign-in, forgot password |
| 2 | Register | `/register` | Strict email validation, inline errors |
| 3 | Home | `/home` | Dashboard — tasks, quick actions, about me card |
| 4 | Chat | `/chat` | AI conversation, save + history |
| 5 | Chat History | `/chat-history` | Browse, reopen, rename saved chats |
| 6 | Deck List | `/flashcards` | View all decks, real-time stream |
| 7 | Create Deck | `/create-deck` | Dynamic card form, up to 10 cards |
| 8 | Study | `/study` | Card flip, score tracking |
| 9 | Study Timer | `/timer` | Customizable Pomodoro, session saving |
| 10 | Add Task | `/add-task` | Date/time picker, priority chips |
| 11 | Profile | `/profile` | Stats, daily goal, settings, logout |
| 12 | Edit Profile | `/edit-profile` | Live avatar preview, optional personal info |

---

## 9. Project Statistics

| Metric | Value |
|---|---|
| Total screens | 12 |
| Firebase services | 2 (Auth, Firestore) |
| External APIs | 1 (Groq) |
| Auth methods | 2 (Email/Password, Google) |
| Firestore subcollections | 4 (chats, tasks, decks, sessions) |
| Reusable widgets | 5+ |
| Supported platforms | Android, Web |
| AI model | `llama-3.3-70b-versatile` |
| Dark mode | ✅ All 12 screens |
| Persistent login | ✅ Firebase Auth stream |
| Offline-safe writes | ✅ Firestore SDK handles queuing |

---

*Report generated for Aether v1.0.0 — Mobile Application Development course project.*
