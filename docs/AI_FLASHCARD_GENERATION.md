# AI-Powered Flashcard Generation

This document explains the AI flashcard generation feature that allows users to create study flashcards in two ways: manual creation and AI generation.

---

## Overview

Users can now create flashcards using **two methods**:

1. **Manual Creation** (existing) — Type each question and answer manually
2. **AI Generation** (NEW) — Enter a topic and let AI generate flashcards automatically

Both methods are accessible via tabs in the Create Deck screen.

---

## User Experience

### Opening the Screen
When users tap "Create Deck", they see two tabs:
- 📝 **Manual** — Traditional card-by-card creation
- ✨ **AI Generate** — AI-powered generation from topic

### AI Generation Flow

1. **Enter Deck Name**
   - e.g., "Biology Chapter 3"

2. **Enter Topic/Subject**
   - Multi-line text field
   - e.g., "Photosynthesis process and light reactions"
   - Can be detailed or brief

3. **Choose Number of Cards**
   - Slider: 5 to 15 cards
   - Default: 10 cards
   - Shows live count as user adjusts

4. **Generate**
   - Tap "Generate Flashcards" button
   - Shows loading spinner: "Generating..."
   - Takes 3-5 seconds

5. **Preview Generated Cards**
   - All cards appear below the button
   - Each card shows:
     - Question badge (Q1, Q2, etc.)
     - Question text (bold)
     - Answer text (gray)

6. **Save or Regenerate**
   - Tap "Save Deck" to save to Firestore
   - Or adjust topic/count and regenerate

---

## Technical Implementation

### 1. Tab Navigation

Used `DefaultTabController` with `TabBarView`:

```dart
DefaultTabController(
  length: 2,
  child: Scaffold(
    appBar: AppBar(
      bottom: TabBar(
        tabs: [
          Tab(icon: Icon(Icons.edit), text: 'Manual'),
          Tab(icon: Icon(Icons.auto_awesome), text: 'AI Generate'),
        ],
      ),
    ),
    body: TabBarView(
      children: [
        _buildManualTab(),
        _buildAIGenerateTab(),
      ],
    ),
  ),
)
```

### 2. AI Prompt Engineering

The prompt is carefully structured to get consistent JSON output:

```dart
final prompt = '''Generate exactly $_numCardsToGenerate flashcards about: ${_topicController.text.trim()}

Format your response EXACTLY as a JSON array like this:
[
  {"question": "What is X?", "answer": "X is..."},
  {"question": "How does Y work?", "answer": "Y works by..."}
]

Requirements:
- Each question should be clear and concise
- Answers should be 1-2 sentences
- Cover key concepts
- Make questions test understanding, not just memorization
- Return ONLY valid JSON, no other text''';
```

**Key techniques:**
- Explicit format example
- Clear requirements
- Request for JSON only (no extra text)
- Specific answer length (1-2 sentences)

### 3. JSON Parsing with Error Handling

AI responses can be unpredictable. The code handles multiple scenarios:

```dart
String jsonString = response.trim();

// Remove markdown code blocks if present
if (jsonString.contains('```json')) {
  jsonString = jsonString.split('```json')[1].split('```')[0].trim();
} else if (jsonString.contains('```')) {
  jsonString = jsonString.split('```')[1].split('```')[0].trim();
}

// Parse JSON
final List<dynamic> cardsJson = jsonDecode(jsonString);
```

**Handles:**
- Plain JSON response
- JSON wrapped in ```json ... ```
- JSON wrapped in ``` ... ```

### 4. State Management

Three key state variables for AI generation:

```dart
final TextEditingController _topicController = TextEditingController();
int _numCardsToGenerate = 10;
bool _isGenerating = false;
List<Map<String, String>> _generatedCards = [];
```

- `_topicController` — User's topic input
- `_numCardsToGenerate` — Slider value (5-15)
- `_isGenerating` — Loading state
- `_generatedCards` — Parsed flashcards from AI

### 5. Firestore Storage

AI-generated decks are marked with a flag:

```dart
await FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .collection('decks')
  .add({
    'name': _deckNameController.text.trim(),
    'cards': _generatedCards,
    'createdAt': FieldValue.serverTimestamp(),
    'generatedByAI': true,  // ← Marks as AI-generated
  });
```

This allows future features like:
- Filtering AI vs manual decks
- Analytics on AI usage
- Different UI badges for AI decks

---

## Error Handling

### 1. Empty Topic
```dart
if (_topicController.text.trim().isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Please enter a topic')),
  );
  return;
}
```

### 2. API Failure
```dart
try {
  // AI generation
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Error generating cards. Try again or use manual mode.'),
    ),
  );
}
```

### 3. Invalid JSON
If `jsonDecode()` fails, the catch block handles it gracefully.

### 4. Empty Deck Name
```dart
if (_deckNameController.text.trim().isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Please enter a deck name')),
  );
  return;
}
```

---

## UI Components

### Info Card
Purple-bordered card explaining the feature:
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: _kPrimary.withValues(alpha: 0.1),
    border: Border.all(color: _kPrimary, width: 2),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      const Icon(Icons.auto_awesome, color: _kPrimary, size: 32),
      const SizedBox(width: 12),
      Expanded(
        child: Text('AI will generate flashcards from your topic...'),
      ),
    ],
  ),
)
```

### Slider
```dart
Slider(
  value: _numCardsToGenerate.toDouble(),
  min: 5,
  max: 15,
  divisions: 10,
  activeColor: _kPrimary,
  label: '$_numCardsToGenerate cards',
  onChanged: (value) {
    setState(() => _numCardsToGenerate = value.round());
  },
)
```

### Generate Button
```dart
ElevatedButton.icon(
  onPressed: _isGenerating ? null : _generateFlashcardsWithAI,
  icon: _isGenerating
      ? CircularProgressIndicator(...)
      : Icon(Icons.auto_awesome),
  label: Text(_isGenerating ? 'Generating...' : 'Generate Flashcards'),
)
```

### Card Preview
Each generated card is displayed in a neo-brutalist container:
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(color: _kBorderBlack, width: 2),
    borderRadius: BorderRadius.circular(12),
    boxShadow: _kNeoShadow,
  ),
  child: Column(
    children: [
      // Question badge + text
      Row(
        children: [
          Container(
            decoration: BoxDecoration(color: _kPrimary, ...),
            child: Text('Q${index + 1}'),
          ),
          Text(card['question']),
        ],
      ),
      // Answer text
      Text(card['answer']),
    ],
  ),
)
```

---

## Example Usage

### Input:
- **Deck Name:** "Physics - Newton's Laws"
- **Topic:** "Newton's three laws of motion and their applications"
- **Number of Cards:** 8

### AI Output (parsed):
```json
[
  {
    "question": "What is Newton's First Law of Motion?",
    "answer": "An object at rest stays at rest, and an object in motion stays in motion unless acted upon by an external force."
  },
  {
    "question": "How does Newton's Second Law relate force, mass, and acceleration?",
    "answer": "Force equals mass times acceleration (F = ma), meaning greater force or less mass results in greater acceleration."
  },
  ...
]
```

### Result:
- 8 flashcards saved to Firestore
- Marked as `generatedByAI: true`
- Ready to study immediately

---

## Advantages Over Manual Creation

| Manual | AI Generation |
|--------|---------------|
| Type each Q&A individually | Enter topic once |
| 5-10 minutes for 10 cards | 5 seconds for 10 cards |
| Requires subject knowledge | AI provides content |
| Good for specific questions | Good for broad topics |
| Full control | Quick coverage |

**Best Use Cases for AI:**
- Quick study prep before exams
- Covering broad topics (e.g., "World War 2")
- Learning new subjects
- Creating practice decks

**Best Use Cases for Manual:**
- Specific homework questions
- Custom study needs
- Memorizing exact definitions
- Personal notes

---

## Technical Concepts Demonstrated

### 1. AI Prompt Engineering
- Structured prompts for consistent output
- JSON format specification
- Clear requirements and constraints

### 2. JSON Parsing
- Handling unpredictable AI responses
- Extracting JSON from markdown
- Type-safe parsing with error handling

### 3. Tab Navigation
- `DefaultTabController` for state management
- `TabBar` + `TabBarView` coordination
- Shared state between tabs (deck name)

### 4. Async/Await
- API calls with loading states
- Error handling with try-catch
- UI updates after async operations

### 5. State Management
- Multiple state variables
- Loading indicators
- Conditional rendering (show cards after generation)

---

## Future Enhancements

Possible improvements:

1. **Edit Generated Cards**
   - Allow editing Q&A before saving
   - Delete unwanted cards

2. **Difficulty Levels**
   - Slider for easy/medium/hard questions
   - AI adjusts complexity

3. **Language Support**
   - Generate cards in different languages
   - Useful for language learning

4. **Topic Suggestions**
   - Show popular topics
   - Quick-start buttons

5. **Regenerate Single Card**
   - Regenerate just one card if unsatisfied
   - Keep the rest

6. **Export/Share**
   - Share AI-generated decks with friends
   - Export to PDF or text

---

## For Your Presentation 🎓

**Key Points to Mention:**

1. **Two Creation Methods** — Manual + AI (flexibility)
2. **Tab Navigation** — Clean UI, easy switching
3. **AI Prompt Engineering** — Structured prompts for JSON output
4. **JSON Parsing** — Handles unpredictable AI responses
5. **Error Handling** — Graceful fallbacks, user-friendly messages
6. **Firestore Integration** — Marks AI-generated decks
7. **Slider UI** — Choose card count (5-15)
8. **Preview Before Save** — See all cards before committing

**This shows you understand:**
- AI integration beyond basic chat
- Structured data extraction from AI
- Complex UI (tabs, sliders, conditional rendering)
- Error handling for external APIs
- User experience design (preview, loading states)

**Impressive because:**
- Most student projects only do basic AI chat
- You're using AI for **content generation**
- JSON parsing shows technical depth
- Tab navigation shows UI/UX skills

🚀 This feature alone could be a project highlight!
