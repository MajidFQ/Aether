# How Chat Saving Works

## The Big Picture

```
User taps 💾  →  _saveChat()  →  Firestore  →  ChatHistoryScreen reads it back
```

---

## Step 1 — The Message Model (`chat_screen.dart`)

Every message in the chat is a `Message` object:

```dart
class Message {
  final String text;       // the actual message content
  final bool isUser;       // true = sent by user, false = sent by AI
  final DateTime timestamp;
}
```

To save to Firestore (which only understands plain data, not Dart objects),
`Message` has two conversion methods:

```dart
// Dart object → plain Map (for saving)
Map<String, dynamic> toMap() => {
  'text': text,
  'isUser': isUser,
  'timestamp': timestamp.toIso8601String(), // DateTime → "2025-05-17T20:30:00"
};

// Plain Map → Dart object (for loading)
factory Message.fromMap(Map<String, dynamic> map) => Message(
  text: map['text'],
  isUser: map['isUser'],
  timestamp: DateTime.parse(map['timestamp']),
);
```

---

## Step 2 — Saving (`_saveChat` in `chat_screen.dart`)

When the user taps 💾, this function runs:

```dart
Future<void> _saveChat() async {
  final uid = FirebaseAuth.instance.currentUser?.uid; // who is logged in?

  await FirebaseFirestore.instance
      .collection('users')       // top-level collection
      .doc(uid)                  // this user's document
      .collection('chats')       // sub-collection of chats
      .add({                     // .add() creates a new doc with auto-generated ID
        'messages': _messages.map((m) => m.toMap()).toList(), // List<Message> → List<Map>
        'firstQuestion': ...,    // used as the title in history list
        'createdAt': FieldValue.serverTimestamp(), // Firestore sets the time
      });
}
```

### What gets stored in Firestore

```
Firestore
└── users/
    └── {userId}/
        └── chats/
            └── {autoId}/          ← created by .add()
                ├── firstQuestion: "What is Schrödinger's equation?"
                ├── createdAt:     Timestamp(2025-05-17 20:30:00)
                └── messages: [
                      { text: "What is...", isUser: true,  timestamp: "2025-05-17T..." },
                      { text: "Great question!", isUser: false, timestamp: "2025-05-17T..." },
                      ...
                    ]
```

---

## Step 3 — Loading (`ChatHistoryScreen`)

The history screen uses a **StreamBuilder** — it listens to Firestore in real time:

```dart
FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .collection('chats')
    .orderBy('createdAt', descending: true) // newest first
    .snapshots()                            // live stream, updates automatically
```

`StreamBuilder` rebuilds the UI whenever Firestore data changes — so if you
save a new chat, it appears in the list instantly without refreshing.

---

## Step 4 — Replaying a Saved Chat

When you tap a history tile, the saved maps are converted back to `Message` objects:

```dart
final messages = rawMessages
    .map((m) => Message.fromMap(Map<String, dynamic>.from(m)))
    .toList();

// Open ChatScreen with the restored messages
Navigator.push(
  MaterialPageRoute(
    builder: (_) => ChatScreen(initialMessages: messages),
  ),
);
```

`ChatScreen` accepts an optional `initialMessages` parameter. If provided,
it uses those instead of starting fresh — so you see the full saved conversation.

---

## Summary Flow

```
[Chat Screen]
    │
    │  User taps 💾
    ▼
_saveChat()
    │  converts List<Message> → List<Map> via .toMap()
    │  writes to Firestore with .add()
    ▼
Firestore: users/{uid}/chats/{autoId}
    │
    │  StreamBuilder listens automatically
    ▼
[Chat History Screen]
    │  shows list of saved chats
    │
    │  User taps a tile
    ▼
Message.fromMap() converts List<Map> → List<Message>
    │
    ▼
ChatScreen(initialMessages: messages)  ← conversation restored
```

---

## Key Firestore Concepts Used

| Concept | What it does |
|---|---|
| `.collection('chats')` | Groups related documents together |
| `.add({...})` | Creates a new document with an auto-generated ID |
| `.snapshots()` | Returns a live stream — UI updates automatically |
| `FieldValue.serverTimestamp()` | Firestore sets the time (avoids device clock issues) |
| `orderBy('createdAt', descending: true)` | Sorts newest chats to the top |
