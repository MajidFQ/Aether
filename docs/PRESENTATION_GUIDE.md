# Aether — Project Presentation Guide

## Project Overview

**Aether** is a full-stack mobile study assistant built with Flutter and Firebase. It combines AI-powered chat, task management, flashcard studying, a focus timer, and a personalized profile — all in one app with a consistent neo-brutalist design.

| | |
|---|---|
| **Platform** | Android + Web |
| **Frontend** | Flutter (Dart) |
| **Backend** | Firebase Auth + Cloud Firestore |
| **AI** | Groq API — `llama-3.3-70b-versatile` (free tier) |
| **State Management** | Provider + local `setState` |
| **Design** | Neo-brutalist — black borders, `#5B4FFF` purple, Plus Jakarta Sans |
| **Total Screens** | 12 |

---

## Feature Division

---

### 👤 Person A

---

### 1. Authentication

**What it does:**
Users can create an account or log in using Email/Password or Google Sign-In. Once logged in, the session persists — the user never has to log in again unless they explicitly log out.

**How we achieved it:**
- We use **Firebase Authentication** as the identity provider. The `AuthService` class wraps `FirebaseAuth.instance` and exposes clean methods: `signInWithEmailAndPassword()`, `registerWithEmail()`, `signInWithGoogle()`, and `signOut()`.
- On app startup, `main.dart` wraps the entire app in a `StreamBuilder` listening to `FirebaseAuth.instance.authStateChanges()`. This stream emits a `User` object when logged in and `null` when logged out — so the app automatically routes to `HomeScreen` or `LoginScreen` without any manual session checks.
- **Google Sign-In** works differently on Web vs Android. On Web, Firebase opens a popup via `signInWithPopup(GoogleAuthProvider())`. On Android, we use the `google_sign_in` package to get an ID token, then pass it to Firebase as a credential. Both paths are handled inside a single `signInWithGoogle()` method using `kIsWeb`.
- **Input validation** is done client-side before any Firebase call — regex for email format, minimum 6 characters for password. Firebase error codes (`wrong-password`, `user-not-found`, `invalid-credential`) are mapped to human-readable messages shown inline under the relevant field.
- **Password reset** is built in — tapping "Forgot?" opens a dialog, the user enters their email, and `sendPasswordResetEmail()` sends a reset link via Firebase.

**Key widgets:** `StreamBuilder`, `TextFormField`, `CustomTextField` (reusable widget), `AlertDialog`
**Data stored:** Firebase Auth profile — uid, displayName, email

---

### 2. AI Chat

**What it does:**
Users can have a conversation with an AI study assistant. Messages appear as chat bubbles. Conversations can be named and saved to Firestore, and the full chat history is accessible from a dedicated screen where chats can be renamed.

**How we achieved it:**
- The AI is powered by **Groq's free API** using the `llama-3.3-70b-versatile` model. We chose Groq because it has a generous free tier with fast response times — no credit card required.
- The `GroqService` class sends an HTTP POST request to `https://api.groq.com/openai/v1/chat/completions`. Groq uses the same request/response format as OpenAI, so the body contains a `messages` array with `role: user` and the user's text. The response is parsed to extract `choices[0].message.content`.
- **API key security:** The key is stored in `assets/.env` and loaded at startup using the `flutter_dotenv` package. The `.env` file is listed in `.gitignore` so it is never committed to version control.
- Each message is a `Message` object with `text`, `isUser`, and `timestamp`. The UI uses a `ListView.builder` to render bubbles — purple on the right for the user, light lavender on the left for the AI.
- **Saving chats:** When the user taps the save icon, a dialog asks them to name the chat. The entire `messages` list is serialized using `Message.toMap()` and written to Firestore under `users/{uid}/chats/{autoId}`.
- **Chat History:** A `StreamBuilder` listens to the chats collection ordered by `createdAt` descending. Tapping a tile reconstructs the `Message` objects using `Message.fromMap()` and opens `ChatScreen` with `initialMessages` pre-populated. Long-pressing or tapping the edit icon opens a rename dialog that calls `doc.reference.update({'firstQuestion': newName})`.

**Key widgets:** `ListView.builder`, `TextField`, `StreamBuilder`, `ModalBottomSheet`
**Data stored:** `users/{uid}/chats` — messages array, firstQuestion (chat name), createdAt

---

### 3. To-Do List

**What it does:**
Users create tasks with a title, description, due date, due time, and priority level (low/medium/high). The home screen shows up to 3 upcoming incomplete tasks in real time. Tapping a task opens a detail sheet; tapping the checkmark marks it complete.

**How we achieved it:**
- The `AddTaskScreen` uses a `Form` with a `GlobalKey<FormState>` for validation. Date and time are picked using Flutter's built-in `showDatePicker()` and `showTimePicker()` dialogs, then combined into a single `DateTime` object before saving.
- Priority is selected via custom color-coded chips — green for low, orange for medium, red for high. The selected chip fills with its color; unselected ones are transparent.
- Tasks are saved to Firestore under `users/{uid}/tasks` with `dueDate` stored as an ISO 8601 string so it can be sorted and parsed reliably.
- On the home screen, a `StreamBuilder` listens to a Firestore query: `where('isCompleted', isEqualTo: false).orderBy('dueDate').limit(3)`. This query requires a **composite index** in Firestore (isCompleted + dueDate), which we created in the Firebase Console. The stream updates the UI in real time — no manual refresh needed.
- Tapping a task card opens a `ModalBottomSheet` showing the full title, formatted due date, description, and a green "Mark as Complete" button. Tapping the button calls `doc.reference.update({'isCompleted': true})`, which removes it from the stream instantly.

**Key widgets:** `StreamBuilder`, `Form`, `showDatePicker`, `showTimePicker`, `ModalBottomSheet`
**Data stored:** `users/{uid}/tasks` — title, description, dueDate, priority, isCompleted, createdAt

---

### 👤 Person B

---

### 4. Flashcards

**What it does:**
Users create named decks of up to 10 question/answer cards. They can then study a deck — cards are shown one at a time, tapping flips to reveal the answer, and "Got it!" or "Study again" buttons track progress. A score is shown at the end.

**How we achieved it:**
- `CreateDeckScreen` uses a dynamic list of card input pairs. Each card is a `Map<String, dynamic>` with `question` and `answer` fields. Cards can be added (up to 10) or deleted individually. On save, the entire deck is written to Firestore as a single document with a `cards` array.
- `DeckListScreen` uses a `StreamBuilder` on the decks collection ordered by `createdAt`. Each deck shows its name and card count. Tapping "Study" passes the deck data via `Navigator.pushNamed(context, '/study', arguments: deckData)`.
- `StudyScreen` receives the deck data from `ModalRoute.of(context)!.settings.arguments`. It tracks `currentIndex`, `showAnswer`, and `correctCount` using local `setState`. Tapping the card toggles `showAnswer`. "Got it!" increments `correctCount` and advances; "Study again" just advances. When all cards are done, an `AlertDialog` shows the final score.
- The card flip is a visual toggle — the card container switches between showing the question and the answer with a color change, keeping the interaction simple and clear.

**Key widgets:** `StreamBuilder`, `ListView`, `GestureDetector`, `AlertDialog`, `Navigator` with arguments
**Data stored:** `users/{uid}/decks` — name, cards array (question + answer), createdAt

---

### 5. Study Timer

**What it does:**
A Pomodoro-style focus timer, default 25 minutes but fully customizable from 1 to 120 minutes. Users can start, pause, and reset. Completed sessions are saved to Firestore. Today's total study time is shown at the bottom.

**How we achieved it:**
- The timer uses Dart's `Timer.periodic(Duration(seconds: 1), callback)` to decrement `_secondsRemaining` every second. The state is managed locally with `setState`. On pause, `_timer?.cancel()` stops the periodic callback. On reset, `_secondsRemaining` is restored to `_sessionSeconds`.
- The circular progress indicator uses `CircularProgressIndicator` with `value = 1 - (secondsRemaining / sessionSeconds)`, so it fills as time passes.
- **Duration customization:** A bottom sheet contains a `Slider` (1–120 min, 119 divisions) and quick-pick preset chips (5, 10, 15, 25, 30, 45, 60, 90 min). The duration button in the AppBar is disabled while the timer is running to prevent mid-session changes.
- On completion, the session duration is written to Firestore under `users/{uid}/sessions` with `duration` (in minutes) and `completedAt` (server timestamp). This data is later read by the Profile screen to calculate total study time.
- Today's stat is accumulated in-memory during the session — `_todaySeconds += _sessionSeconds` — and displayed as "Today: Xh Xm".

**Key widgets:** `CircularProgressIndicator`, `Timer.periodic`, `Slider`, `ModalBottomSheet`, `Wrap` (preset chips)
**Data stored:** `users/{uid}/sessions` — duration (minutes), completedAt

---

### 6. Profile & Goals

**What it does:**
A full profile screen showing the user's avatar, name, email, and optional personal info (age, education, hobbies, bio). A daily study goal card shows today's progress with a progress bar. Four stat cards pull live data from Firestore. An Edit Profile screen lets users update all their info.

**How we achieved it:**
- **Daily goal:** Stored in the user's Firestore document (`users/{uid}`) as `dailyGoal`. A `Slider` in a bottom sheet (15–180 min, 11 divisions) lets the user change it. On confirm, `FirebaseFirestore.instance.collection('users').doc(uid).set({'dailyGoal': newGoal}, SetOptions(merge: true))` updates only that field without overwriting others.
- **Progress bar:** `LinearProgressIndicator(value: (todayMinutes / dailyGoal).clamp(0.0, 1.0))`. Today's minutes come from reading the sessions subcollection and filtering by today's date.
- **Stats calculation:** On screen load, we run 4 parallel Firestore reads — sessions (sum durations), tasks (count where isCompleted == true), decks (count), chats (count). Results are stored in a `Map<String, int>` and displayed in a 2×2 `GridView`.
- **Edit Profile:** `EditProfileScreen` loads existing data from Firestore on init, pre-fills all fields, and on save calls `FirebaseAuth.currentUser.updateDisplayName()` for the name and `Firestore.set(..., merge: true)` for the rest. Returning `true` from `Navigator.pop(context, true)` signals the profile screen to reload via `_loadAll()`.
- The home screen also shows an "About Me" card that reads the same Firestore fields and displays them as info chips. If empty, it shows a prompt to add info.

**Key widgets:** `GridView`, `LinearProgressIndicator`, `Slider`, `ModalBottomSheet`, `TextFormField`, `RefreshIndicator`
**Data stored:** `users/{uid}` — dailyGoal, bio, education, hobbies, age, updatedAt

---

### 7. Dark Mode

**What it does:**
A toggle in the home screen AppBar and in Profile settings switches the entire app between light and dark themes. The preference is saved locally and restored on every app launch.

**How we achieved it:**
- A `ThemeProvider` class extends `ChangeNotifier`. It holds a `bool _isDark` and exposes `toggleTheme()`. On toggle, it flips the boolean, calls `notifyListeners()`, and writes the new value to `SharedPreferences` using `prefs.setBool('isDark', _isDark)`.
- On app startup, `ThemeProvider()` constructor calls `_loadTheme()` which reads `prefs.getBool('isDark')` and calls `notifyListeners()` once loaded — so the correct theme is applied before the first frame renders.
- In `main.dart`, `ChangeNotifierProvider(create: (_) => ThemeProvider())` wraps the app. `MaterialApp` is wrapped in a `Consumer<ThemeProvider>` which rebuilds when the theme changes, setting `themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light` along with separate `theme` and `darkTheme` `ThemeData` objects.
- Since all screens had hardcoded background colors, we created a `theme_helper.dart` utility with functions like `getBackgroundColor(context)`, `getCardColor(context)`, `getTextColor(context)` that check `Theme.of(context).brightness` and return the appropriate color. Every screen calls these instead of hardcoded values.

**Key widgets:** `Consumer`, `Switch`, `MaterialApp` (theme/darkTheme/themeMode)
**Data stored:** `SharedPreferences` — `isDark` boolean (device-local, no Firestore)

---

## Firestore Data Structure

```
users/
  {uid}/                        ← user profile doc (dailyGoal, bio, education, hobbies, age)
    chats/
      {chatId}/                 ← messages[], firstQuestion, createdAt
    tasks/
      {taskId}/                 ← title, description, dueDate, priority, isCompleted, createdAt
    decks/
      {deckId}/                 ← name, cards[], createdAt
    sessions/
      {sessionId}/              ← duration (minutes), completedAt
```

---

## App Statistics

| Metric | Value |
|---|---|
| Total Screens | 12 |
| Firebase Services Used | 2 (Auth, Firestore) |
| External APIs | 1 (Groq) |
| Auth Methods | 2 (Email/Password, Google) |
| Firestore Subcollections | 4 (chats, tasks, decks, sessions) |
| Platforms | Android + Web |
| AI Model | llama-3.3-70b-versatile |
| Design System | Neo-brutalist |

---

## Screen List

| # | Screen | Purpose |
|---|---|---|
| 1 | Login | Email + Google sign-in |
| 2 | Register | New account creation |
| 3 | Home | Dashboard — tasks, quick actions, about me |
| 4 | Chat | AI conversation interface |
| 5 | Chat History | Browse and rename saved chats |
| 6 | Deck List | View all flashcard decks |
| 7 | Create Deck | Build a new flashcard deck |
| 8 | Study | Study a deck card by card |
| 9 | Study Timer | Customizable Pomodoro timer |
| 10 | Add Task | Create a new task |
| 11 | Profile | Stats, daily goal, settings |
| 12 | Edit Profile | Update personal info |
