---
name: flutter-python-fullstack
description: Use when building desktop/web applications with Flutter frontend and Python FastAPI backend, when setting up project structure with control scripts and installers, or when implementing tabbed UI with system monitoring
---

# Flutter + Python Fullstack Application Pattern

Build cross-platform desktop/web applications with a Flutter Material 3 frontend and Python FastAPI backend.

## Project Structure

```
project-root/
├── backend/                    # Python FastAPI backend
│   ├── main.py                # FastAPI app with lifespan
│   ├── database.py            # SQLite schema & seeding
│   ├── requirements.txt       # Python dependencies
│   ├── models/                # Domain models & registry
│   ├── tts/                   # Engine implementations (e.g., kokoro, qwen3)
│   │   └── kokoro_engine.py   # Singleton engine pattern
│   ├── services/              # Business logic (engines, providers)
│   │   └── base.py            # Abstract base classes
│   │   └── factory.py         # Factory pattern for providers
│   ├── tests/                 # pytest test suite
│   │   ├── conftest.py        # Fixtures & path setup
│   │   ├── test_health.py     # Basic health tests
│   │   ├── test_all_endpoints.py  # Comprehensive API tests
│   │   └── test_*.py          # Grouped by feature
│   ├── data/                  # SQLite DB & static data
│   │   ├── knowledge_bases/   # KB storage (if using RAG)
│   │   │   └── {kb_id}/
│   │   │       ├── kb_config.json
│   │   │       ├── documents/     # Source PDFs
│   │   │       ├── chunks/        # Text chunks
│   │   │       ├── bm25.pkl       # BM25 index
│   │   │       ├── sparse_index.pkl
│   │   │       └── vector_index.npz
│   │   └── app.db             # SQLite database
│   └── outputs/               # Generated files (audio, etc.)
│
├── flutter_app/               # Flutter UI
│   ├── lib/
│   │   ├── main.dart          # App entry, theme, MainScreen with TabBar
│   │   ├── screens/           # Tab screens (StatefulWidget)
│   │   │   ├── quick_tts_screen.dart
│   │   │   ├── voice_clone_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── models/            # Data models
│   │   ├── services/          # ApiService HTTP client
│   │   │   └── api_service.dart
│   │   └── widgets/           # Reusable widgets
│   ├── pubspec.yaml           # Flutter dependencies
│   ├── macos/                 # macOS desktop config
│   └── web/                   # Web build config
│
├── bin/                       # Control scripts
│   ├── appctl                 # Bash control script (comprehensive)
│   ├── appctl.ps1             # PowerShell for Windows
│   └── tts_mcp_server.py      # MCP server (optional)
│
├── scripts/                   # Utility scripts
│   ├── test_api.py            # Integration test script (colored output)
│   ├── test_all_models.py     # Model verification
│   └── build_dmg.sh           # macOS DMG installer builder
│
├── .logs/                     # Runtime logs (backend, flutter)
├── .pids/                     # PID files for process management
├── runs/logs/                 # MCP server & run logs
├── dist/                      # Built installers (DMG, etc.)
│
├── install.sh                 # macOS/Linux installer
├── install.bat                # Windows installer
├── issues.sh                  # Diagnostic/troubleshooting script
├── requirements.txt           # Python dependencies
└── venv/                      # Python virtual environment
```

## Flutter UI Patterns

### Theme Configuration (Material 3)

```dart
MaterialApp(
  title: 'MyApp',
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,  // Primary theme color
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  ),
  themeMode: ThemeMode.system,  // Respects OS preference
  home: const MainScreen(),
)
```

### Main Screen with TabBar Navigation

```dart
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ApiService _api = ApiService();
  bool _isBackendConnected = false;
  bool _isChecking = true;
  Map<String, dynamic>? _systemStats;

  @override
  void initState() {
    super.initState();
    _checkBackend();
    _startStatsPolling();
  }

  Future<void> _checkBackend() async {
    setState(() => _isChecking = true);
    final connected = await _api.checkHealth();
    setState(() {
      _isBackendConnected = connected;
      _isChecking = false;
    });
  }

  void _startStatsPolling() {
    _updateStats();
    // Poll every 2 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && _isBackendConnected) {
        await _updateStats();
        return true;
      }
      return mounted;  // Stop if unmounted
    });
  }

  Future<void> _updateStats() async {
    try {
      final stats = await _api.getSystemStats();
      if (mounted) {
        setState(() => _systemStats = stats);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to backend...'),
            ],
          ),
        ),
      );
    }

    if (!_isBackendConnected) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Backend not connected',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Run: ./bin/appctl up'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _checkBackend,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 4,  // Number of tabs
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 40,  // Compact header
          title: _buildSystemStatsBar(),
          actions: [
            IconButton(
              icon: const Icon(Icons.model_training, size: 22),
              onPressed: () => _showModelsDialog(),
              tooltip: 'Models',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.graphic_eq, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('MyApp',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 14),
            tabs: [
              Tab(icon: Icon(Icons.volume_up, size: 28), text: 'Quick TTS'),
              Tab(icon: Icon(Icons.record_voice_over, size: 28), text: 'Voice Clone'),
              Tab(icon: Icon(Icons.menu_book, size: 28), text: 'Reader'),
              Tab(icon: Icon(Icons.hub, size: 28), text: 'Settings'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            QuickTtsScreen(),
            VoiceCloneScreen(),
            ReaderScreen(),
            SettingsScreen(),
          ],
        ),
      ),
    );
  }
}
```

### System Stats Bar with Color-Coded Chips

```dart
Widget _buildSystemStatsBar() {
  if (_systemStats == null) {
    return const SizedBox.shrink();
  }

  final cpuPercent = _systemStats!['cpu_percent'] ?? 0.0;
  final ramUsed = _systemStats!['ram_used_gb'] ?? 0.0;
  final ramTotal = _systemStats!['ram_total_gb'] ?? 0.0;
  final ramPercent = _systemStats!['ram_percent'] ?? 0.0;
  final gpu = _systemStats!['gpu'];

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _buildStatChip(
        Icons.memory,
        'CPU',
        '${cpuPercent.toStringAsFixed(0)}%',
        cpuPercent > 80 ? Colors.red : (cpuPercent > 50 ? Colors.orange : Colors.green),
      ),
      const SizedBox(width: 8),
      _buildStatChip(
        Icons.storage,
        'RAM',
        '${ramUsed.toStringAsFixed(1)}/${ramTotal.toStringAsFixed(0)}GB',
        ramPercent > 80 ? Colors.red : (ramPercent > 50 ? Colors.orange : Colors.green),
      ),
      if (gpu != null) ...[
        const SizedBox(width: 8),
        _buildStatChip(
          Icons.videogame_asset,
          'GPU',
          gpu['memory_used_gb'] != null
              ? '${(gpu['memory_used_gb'] ?? 0.0).toStringAsFixed(1)}/${(gpu['memory_total_gb'] ?? 0.0).toStringAsFixed(0)}GB'
              : (gpu['name'] ?? 'Active'),
          gpu['memory_percent'] != null
              ? ((gpu['memory_percent'] ?? 0.0) > 80
                  ? Colors.red
                  : ((gpu['memory_percent'] ?? 0.0) > 50 ? Colors.orange : Colors.green))
              : Colors.teal,
        ),
      ],
    ],
  );
}

Widget _buildStatChip(IconData icon, String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),  // Use withValues, not deprecated withOpacity
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text('$label: $value',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
      ],
    ),
  );
}
```

### Voice/Speaker Selection with ChoiceChips

```dart
// Data class for speakers
class Speaker {
  final String name;
  final String language;
  final Color color;
  final String? flag;

  const Speaker({required this.name, required this.language, required this.color, this.flag});
}

// In your screen:
final List<Speaker> _speakers = [
  Speaker(name: 'Ryan', language: 'English', color: Colors.blue, flag: 'US'),
  Speaker(name: 'Sohee', language: 'Korean', color: Colors.pink, flag: 'KR'),
  Speaker(name: 'Aiden', language: 'Chinese', color: Colors.red, flag: 'CN'),
];

String _selectedSpeaker = 'Ryan';

Widget _buildSpeakerSelector() {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _speakers.map((speaker) {
      final isSelected = _selectedSpeaker == speaker.name;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (speaker.flag != null) ...[
              Text(speaker.flag!, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
            ],
            Text(speaker.name),
          ],
        ),
        selected: isSelected,
        selectedColor: speaker.color.withValues(alpha: 0.3),
        onSelected: (selected) {
          if (selected) setState(() => _selectedSpeaker = speaker.name);
        },
      );
    }).toList(),
  );
}
```

### ApiService HTTP Client (Comprehensive)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000';
  static const String mcpUrl = 'http://localhost:8010';

  // ==================== Health & System ====================

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getSystemStats() async {
    final response = await http.get(Uri.parse('$baseUrl/api/system/stats'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load stats');
  }

  Future<Map<String, dynamic>> getSystemInfo() async {
    final response = await http.get(Uri.parse('$baseUrl/api/system/info'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load system info');
  }

  // ==================== Engine-Specific Endpoints ====================
  // Pattern: /api/{engine}/{action}

  // --- Kokoro TTS ---
  Future<List<Map<String, dynamic>>> getKokoroVoices() async {
    final response = await http.get(Uri.parse('$baseUrl/api/kokoro/voices'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body)['voices']);
    }
    throw Exception('Failed to load voices');
  }

  Future<String> generateKokoroAudio({
    required String text,
    required String voice,
    double speed = 1.0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/kokoro/generate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'text': text, 'voice': voice, 'speed': speed}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['audio_url'];
    }
    throw Exception('Generation failed: ${response.body}');
  }

  // --- Voice Clone (Qwen3/Chatterbox) ---
  Future<List<Map<String, dynamic>>> getCloneVoices(String engine) async {
    final response = await http.get(Uri.parse('$baseUrl/api/$engine/voices'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body)['voices']);
    }
    throw Exception('Failed to load $engine voices');
  }

  Future<Map<String, dynamic>> uploadVoiceSample({
    required String engine,  // 'qwen3' or 'chatterbox'
    required String name,
    required String transcript,
    required List<int> audioBytes,
    required String filename,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/$engine/voices'));
    request.fields['name'] = name;
    request.fields['transcript'] = transcript;
    request.files.add(http.MultipartFile.fromBytes('file', audioBytes, filename: filename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Upload failed: ${response.body}');
  }

  Future<void> deleteVoice(String engine, String name) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/$engine/voices/$name'),
    );
    if (response.statusCode != 200) {
      throw Exception('Delete failed: ${response.body}');
    }
  }

  Future<String> generateCloneAudio({
    required String engine,
    required String text,
    required String voiceName,
    String? language,
    double? exaggeration,
  }) async {
    final body = {
      'text': text,
      'voice_name': voiceName,
      if (language != null) 'language': language,
      if (exaggeration != null) 'exaggeration': exaggeration,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/api/$engine/generate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body)['audio_url'];
    }
    throw Exception('Generation failed: ${response.body}');
  }

  // ==================== Audio Library ====================

  Future<List<Map<String, dynamic>>> listAudioFiles(String category) async {
    // category: 'tts' or 'voice-clone'
    final response = await http.get(Uri.parse('$baseUrl/api/$category/audio/list'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body)['audio_files']);
    }
    throw Exception('Failed to list audio');
  }

  Future<void> deleteAudioFile(String category, String filename) async {
    final response = await http.delete(Uri.parse('$baseUrl/api/$category/audio/$filename'));
    if (response.statusCode != 200) {
      throw Exception('Delete failed: ${response.body}');
    }
  }

  // ==================== MCP Server ====================

  Future<List<Map<String, dynamic>>> getMcpTools() async {
    final response = await http.post(
      Uri.parse(mcpUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/list',
      }),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body)['result']['tools']);
    }
    throw Exception('MCP failed');
  }
}
```

### Sidebar + Main Content Layout

```dart
@override
Widget build(BuildContext context) {
  return Row(
    children: [
      // Sidebar with item list
      _buildSidebar(),
      // Main content
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(/* main content */),
        ),
      ),
    ],
  );
}

Widget _buildSidebar() {
  return Container(
    width: 280,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              const Icon(Icons.library_music, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Library', style: TextStyle(fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _loadItems),
            ],
          ),
        ),
        // Scrollable list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(child: Text('No items yet', style: TextStyle(color: Colors.grey.shade600)))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) => _buildItemCard(_items[index]),
                    ),
        ),
      ],
    ),
  );
}
```

### Card-Based Content Layout

```dart
// Colored header card
Card(
  color: Theme.of(context).colorScheme.secondaryContainer,
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(Icons.volume_up, color: Theme.of(context).colorScheme.onSecondaryContainer),
        const SizedBox(width: 8),
        Text('Title', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('Badge', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSecondary)),
        ),
      ],
    ),
  ),
),

// Info chips in a row
Row(
  children: [
    Icon(Icons.mic, size: 16, color: Colors.grey.shade600),
    const SizedBox(width: 4),
    Text('Voice: Emma', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    const SizedBox(width: 16),
    Icon(Icons.speed, size: 16, color: Colors.grey.shade600),
    const SizedBox(width: 4),
    Text('Speed: 1.0x', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
  ],
),

// Error card
if (_error != null)
  Card(
    color: Colors.red.shade100,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(_error!, style: const TextStyle(color: Colors.red)),
    ),
  ),

// Content card with surfaceContainerHighest
Card(
  color: Theme.of(context).colorScheme.surfaceContainerHighest,
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(/* content */),
  ),
),

// Tertiary container for samples
Card(
  color: Theme.of(context).colorScheme.tertiaryContainer,
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(/* voice samples */),
  ),
),
```

## Python Backend Patterns

### FastAPI with Lifespan

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("Initializing...")
    init_db()
    seed_db()
    yield
    # Shutdown
    print("Shutting down...")

app = FastAPI(
    title="My API",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve generated files
outputs_dir = Path(__file__).parent / "outputs"
outputs_dir.mkdir(parents=True, exist_ok=True)
app.mount("/files", StaticFiles(directory=str(outputs_dir)), name="files")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### Health and System Endpoints

```python
import psutil
import platform
import sys

@app.get("/api/health")
async def health():
    return {"status": "ok", "service": "myapp"}

@app.get("/api/system/info")
async def get_system_info():
    return {
        "python_version": sys.version,
        "device": "cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu",
        "os": platform.system(),
        "arch": platform.machine(),
        "torch_version": torch.__version__,
        "models": {
            "kokoro": {"loaded": kokoro_engine.is_loaded()},
            "qwen3": {"loaded": qwen3_engine.is_loaded()},
        }
    }

@app.get("/api/system/stats")
async def get_system_stats():
    cpu_percent = psutil.cpu_percent(interval=0.1)
    mem = psutil.virtual_memory()

    stats = {
        "cpu_percent": cpu_percent,
        "ram_used_gb": mem.used / (1024**3),
        "ram_total_gb": mem.total / (1024**3),
        "ram_percent": mem.percent,
        "gpu": None,
    }

    # GPU stats (MPS for Apple Silicon, CUDA for NVIDIA)
    try:
        import torch
        if torch.backends.mps.is_available():
            stats["gpu"] = {"name": "Apple Silicon", "type": "mps"}
        elif torch.cuda.is_available():
            stats["gpu"] = {
                "name": torch.cuda.get_device_name(0),
                "memory_used_gb": torch.cuda.memory_allocated(0) / (1024**3),
                "memory_total_gb": torch.cuda.get_device_properties(0).total_memory / (1024**3),
                "memory_percent": torch.cuda.memory_allocated(0) / torch.cuda.get_device_properties(0).total_memory * 100,
            }
    except:
        pass

    return stats
```

### Multi-Engine API Pattern

```python
# Pattern: /api/{engine}/voices, /api/{engine}/generate

# --- Kokoro TTS (built-in voices) ---
@app.get("/api/kokoro/voices")
async def list_kokoro_voices():
    return {
        "voices": [
            {"code": "bf_emma", "name": "Emma", "gender": "female", "grade": "A", "is_default": True},
            {"code": "bm_daniel", "name": "Daniel", "gender": "male", "grade": "A", "is_default": False},
        ],
        "default": "bf_emma"
    }

@app.post("/api/kokoro/generate")
async def generate_kokoro(request: KokoroRequest):
    result = await kokoro_engine.generate(
        text=request.text,
        voice=request.voice,
        speed=request.speed,
    )
    return {"audio_url": f"/files/{result.filename}"}

# --- Voice Clone Engines (user-uploaded voices) ---
@app.get("/api/qwen3/voices")
async def list_qwen3_voices():
    voices = voice_storage.list_voices("qwen3")
    return {"voices": voices}

@app.post("/api/qwen3/voices")
async def upload_qwen3_voice(
    name: str = Form(...),
    transcript: str = Form(...),
    file: UploadFile = File(...),
):
    # Validate and save voice sample
    audio_path = voice_storage.save("qwen3", name, file, transcript)
    return {"message": "Voice uploaded", "name": name}

@app.delete("/api/qwen3/voices/{name}")
async def delete_qwen3_voice(name: str):
    if not voice_storage.exists("qwen3", name):
        raise HTTPException(404, "Voice not found")
    voice_storage.delete("qwen3", name)
    return {"message": "Voice deleted"}

@app.post("/api/qwen3/generate")
async def generate_qwen3(request: Qwen3Request):
    if request.mode == "clone" and not request.voice_name:
        raise HTTPException(400, "voice_name required for clone mode")

    result = await qwen3_engine.generate(
        text=request.text,
        voice_name=request.voice_name,
        language=request.language,
    )
    return {"audio_url": f"/files/{result.filename}"}
```

### Engine Singleton Pattern

```python
# tts/kokoro_engine.py
_engine = None

class KokoroEngine:
    def __init__(self):
        self._model = None

    def load_model(self):
        if self._model is None:
            from kokoro import KokoroModel
            self._model = KokoroModel()
        return self._model

    def is_loaded(self) -> bool:
        return self._model is not None

    async def generate(self, text: str, voice: str, speed: float = 1.0):
        model = self.load_model()
        # ... generation logic
        return result

def get_kokoro_engine() -> KokoroEngine:
    global _engine
    if _engine is None:
        _engine = KokoroEngine()
    return _engine
```

### Pydantic Request Models

```python
from pydantic import BaseModel
from typing import Optional, Literal

class KokoroRequest(BaseModel):
    text: str
    voice: str = "bf_emma"
    speed: float = 1.0

class Qwen3Request(BaseModel):
    text: str
    mode: Literal["clone", "custom"] = "clone"
    voice_name: Optional[str] = None
    speaker: Optional[str] = None  # For custom mode
    language: str = "English"
    seed: int = -1

class ChatterboxRequest(BaseModel):
    text: str
    voice_name: str
    exaggeration: float = 0.5
    cfg_weight: float = 0.5
```

## Control Script Pattern (bin/appctl)

```bash
#!/usr/bin/env bash
set -euo pipefail

# MyApp Control Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$ROOT_DIR/backend"
FLUTTER_DIR="$ROOT_DIR/flutter_app"
PID_DIR="$ROOT_DIR/.pids"
LOG_DIR="$ROOT_DIR/.logs"
RUNS_LOG_DIR="$ROOT_DIR/runs/logs"

# Locate venv: prefer root-level (install.sh), fall back to backend/venv
if [ -d "$ROOT_DIR/venv" ]; then
    VENV_DIR="$ROOT_DIR/venv"
elif [ -d "$BACKEND_DIR/venv" ]; then
    VENV_DIR="$BACKEND_DIR/venv"
else
    VENV_DIR="$ROOT_DIR/venv"
fi

# Ports
BACKEND_PORT=8000
MCP_PORT=8010
FLUTTER_WEB_PORT=5173
FLUTTER_WEB_HOST="127.0.0.1"

# Flutter app name (matches pubspec.yaml name)
FLUTTER_APP_NAME="my_app"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$PID_DIR" "$LOG_DIR" "$RUNS_LOG_DIR"

# ============== Helper Functions ==============

print_status() {
    local name="$1"
    local port="$2"

    if lsof -ti:"$port" &>/dev/null; then
        local pid=$(lsof -ti:"$port" | head -1)
        echo -e "${GREEN}●${NC} $name: ${GREEN}RUNNING${NC} [PID: $pid, Port: $port]"
    else
        echo -e "${RED}○${NC} $name: ${RED}STOPPED${NC}"
    fi
}

kill_port() {
    local port="$1"
    local pids=$(lsof -ti:"$port" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        echo "$pids" | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
}

wait_for_health() {
    local url="$1"
    local max_retries="${2:-30}"
    local retry=0

    echo -n "Waiting for $url "
    while [ $retry -lt $max_retries ]; do
        if curl -s "$url" &>/dev/null; then
            echo -e " ${GREEN}OK${NC}"
            return 0
        fi
        echo -n "."
        sleep 1
        ((retry++))
    done
    echo -e " ${RED}FAILED${NC}"
    return 1
}

# ============== Backend Functions ==============

start_backend() {
    echo -e "${BLUE}Starting backend...${NC}"
    kill_port $BACKEND_PORT

    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating Python virtual environment..."
        python3 -m venv "$VENV_DIR"
        source "$VENV_DIR/bin/activate"
        pip install -r "$ROOT_DIR/requirements.txt"
    else
        source "$VENV_DIR/bin/activate"
    fi

    cd "$BACKEND_DIR"
    nohup python main.py > "$LOG_DIR/backend.log" 2>&1 &
    echo $! > "$PID_DIR/backend.pid"

    wait_for_health "http://localhost:$BACKEND_PORT/api/health"
}

stop_backend() {
    echo -e "${BLUE}Stopping backend...${NC}"
    kill_port $BACKEND_PORT
    rm -f "$PID_DIR/backend.pid"
    echo -e "${GREEN}Backend stopped${NC}"
}

# ============== Flutter Functions ==============

start_flutter() {
    local mode="${1:-release}"
    local target="${2:-macos}"
    echo -e "${BLUE}Starting Flutter UI ($target, $mode mode)...${NC}"

    cd "$FLUTTER_DIR"

    if [ "$target" = "web" ]; then
        kill_port "$FLUTTER_WEB_PORT"
        echo "Building Flutter web bundle..."
        flutter build web --release
        cd "$FLUTTER_DIR/build/web"
        python3 -m http.server "$FLUTTER_WEB_PORT" --bind "$FLUTTER_WEB_HOST" > "$LOG_DIR/flutter.log" 2>&1 &
        echo $! > "$PID_DIR/flutter.pid"
        return
    fi

    if [ "$mode" = "dev" ]; then
        flutter run -d macos > "$LOG_DIR/flutter.log" 2>&1 &
        echo $! > "$PID_DIR/flutter.pid"
    else
        echo "Building Flutter app..."
        flutter build macos --release

        local app_path="$FLUTTER_DIR/build/macos/Build/Products/Release/MyApp.app"
        if [ -d "$app_path" ]; then
            open "$app_path"
        else
            echo -e "${YELLOW}App not found at $app_path, running in dev mode${NC}"
            flutter run -d macos &
            echo $! > "$PID_DIR/flutter.pid"
        fi
    fi
}

stop_flutter() {
    echo -e "${BLUE}Stopping Flutter UI...${NC}"

    if [ -f "$PID_DIR/flutter.pid" ]; then
        kill $(cat "$PID_DIR/flutter.pid") 2>/dev/null || true
        rm -f "$PID_DIR/flutter.pid"
    fi

    osascript -e 'quit app "MyApp"' 2>/dev/null || true
    kill_port "$FLUTTER_WEB_PORT"

    echo -e "${GREEN}Flutter stopped${NC}"
}

build_flutter() {
    echo -e "${BLUE}Building Flutter app...${NC}"
    cd "$FLUTTER_DIR"
    flutter pub get
    flutter build macos --release
    echo -e "${GREEN}Build complete${NC}"
}

# ============== MCP Functions ==============

start_mcp() {
    echo -e "${BLUE}Starting MCP Server...${NC}"
    kill_port $MCP_PORT

    if [ -f "$VENV_DIR/bin/activate" ]; then
        source "$VENV_DIR/bin/activate"
    fi

    nohup python3 "$SCRIPT_DIR/tts_mcp_server.py" --host 127.0.0.1 --port $MCP_PORT > "$RUNS_LOG_DIR/mcp_server.log" 2>&1 &
    echo $! > "$PID_DIR/mcp.pid"

    sleep 1
    if lsof -ti:"$MCP_PORT" &>/dev/null; then
        echo -e "${GREEN}MCP Server started${NC} on port $MCP_PORT"
    else
        echo -e "${RED}MCP Server failed to start${NC}"
        tail -5 "$RUNS_LOG_DIR/mcp_server.log" 2>/dev/null || true
    fi
}

stop_mcp() {
    echo -e "${BLUE}Stopping MCP Server...${NC}"
    kill_port $MCP_PORT
    rm -f "$PID_DIR/mcp.pid"
    echo -e "${GREEN}MCP Server stopped${NC}"
}

# ============== Database Functions ==============

seed_db() {
    echo -e "${BLUE}Seeding database...${NC}"
    source "$VENV_DIR/bin/activate"
    cd "$BACKEND_DIR"
    python3 database.py
    echo -e "${GREEN}Database seeded${NC}"
}

# ============== Test Functions ==============

run_tests() {
    echo -e "${BLUE}Running API tests...${NC}"
    source "$VENV_DIR/bin/activate"
    python3 "$ROOT_DIR/scripts/test_api.py"
}

# ============== Main Commands ==============

cmd_up() {
    local skip_flutter=false
    local skip_mcp=false
    local flutter_mode="dev"
    local flutter_target="macos"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-flutter) skip_flutter=true ;;
            --no-mcp) skip_mcp=true ;;
            --flutter-release) flutter_mode="release" ;;
            --web) flutter_target="web" ;;
            *) echo "Unknown option: $1" ;;
        esac
        shift
    done

    echo -e "${BLUE}=== Starting MyApp ===${NC}"
    start_backend

    if [ "$skip_mcp" = false ]; then
        start_mcp
    fi

    if [ "$skip_flutter" = false ]; then
        start_flutter "$flutter_mode" "$flutter_target"
    fi

    echo ""
    echo -e "${GREEN}=== MyApp Ready ===${NC}"
    echo -e "Backend:    http://localhost:$BACKEND_PORT"
    echo -e "API Docs:   http://localhost:$BACKEND_PORT/docs"
    echo -e "MCP Server: http://localhost:$MCP_PORT"
    if [ "$flutter_target" = "web" ] && [ "$skip_flutter" = false ]; then
        echo -e "Web UI:     http://$FLUTTER_WEB_HOST:$FLUTTER_WEB_PORT"
    fi
}

cmd_down() {
    echo -e "${BLUE}=== Stopping MyApp ===${NC}"
    stop_flutter
    stop_mcp
    stop_backend
    echo -e "${GREEN}=== MyApp Stopped ===${NC}"
}

cmd_restart() {
    cmd_down
    sleep 2
    cmd_up "$@"
}

cmd_status() {
    echo -e "${BLUE}=== MyApp Status ===${NC}"
    echo ""
    echo -e "${GREEN}Services:${NC}"
    print_status "Backend" $BACKEND_PORT
    print_status "MCP Server" $MCP_PORT

    # Flutter status
    local flutter_running=false
    if [ -f "$PID_DIR/flutter.pid" ]; then
        local pid=$(cat "$PID_DIR/flutter.pid")
        if kill -0 "$pid" 2>/dev/null; then
            flutter_running=true
            echo -e "${GREEN}●${NC} Flutter UI: ${GREEN}RUNNING${NC} [PID: $pid]"
        fi
    fi
    if [ "$flutter_running" = false ]; then
        local app_pid=$(pgrep -f "$FLUTTER_APP_NAME.app/Contents/MacOS" 2>/dev/null | head -1 || true)
        if [ -n "$app_pid" ]; then
            echo -e "${GREEN}●${NC} Flutter UI: ${GREEN}RUNNING${NC} [PID: $app_pid]"
        else
            echo -e "${RED}○${NC} Flutter UI: ${RED}STOPPED${NC}"
        fi
    fi

    echo ""
    echo -e "${GREEN}Logs:${NC}"
    echo "  appctl logs backend   - Backend logs"
    echo "  appctl logs mcp       - MCP server logs"
    echo "  appctl logs flutter   - Flutter logs"
    echo "  appctl logs all       - Tail all logs"
}

cmd_logs() {
    local target="${1:-backend}"

    case "$target" in
        backend) log_file="$LOG_DIR/backend.log" ;;
        mcp) log_file="$RUNS_LOG_DIR/mcp_server.log" ;;
        flutter) log_file="$LOG_DIR/flutter.log" ;;
        all)
            echo "Tailing all logs (Ctrl+C to exit)..."
            tail -f "$LOG_DIR"/*.log "$RUNS_LOG_DIR"/*.log 2>/dev/null
            return ;;
        *) log_file="$LOG_DIR/$target.log" ;;
    esac

    if [ -f "$log_file" ]; then
        echo "Tailing $log_file (Ctrl+C to exit)..."
        tail -f "$log_file"
    else
        echo "Log file not found: $log_file"
        echo "Available logs:"
        ls -1 "$LOG_DIR"/*.log "$RUNS_LOG_DIR"/*.log 2>/dev/null || echo "  (none)"
    fi
}

# ============== Usage ==============

usage() {
    cat << EOF
${BLUE}MyApp Control Script${NC}

Usage: appctl <command> [options]

${GREEN}Service Commands:${NC}
    up [options]                Start all services (Backend + MCP + Flutter)
        --no-flutter            Skip Flutter UI
        --no-mcp                Skip MCP server
        --flutter-release       Run Flutter in release mode (default: dev)
        --web                   Start Flutter in web mode
    down                        Stop all services
    restart                     Restart all services
    status                      Show service status

${GREEN}Backend Commands:${NC}
    backend start               Start backend only
    backend stop                Stop backend

${GREEN}Flutter Commands:${NC}
    flutter start [--dev] [--web]  Start Flutter UI (macOS or web)
    flutter stop                Stop Flutter UI
    flutter build               Build Flutter macOS app

${GREEN}MCP Server Commands:${NC}
    mcp start                   Start MCP server
    mcp stop                    Stop MCP server

${GREEN}Database Commands:${NC}
    db seed                     Seed database

${GREEN}Utility Commands:${NC}
    logs [service]              Tail logs (backend|mcp|flutter|all)
    test                        Run API tests
    clean                       Clean logs and temp files
    version                     Show version info

${GREEN}Examples:${NC}
    appctl up                   # Start everything
    appctl up --no-flutter      # Backend + MCP only
    appctl up --web             # Backend + MCP + Flutter web
    appctl status               # Check what's running
    appctl logs backend         # Tail backend logs

EOF
}

# ============== Main ==============

case "${1:-}" in
    up) shift; cmd_up "$@" ;;
    down) cmd_down ;;
    restart) shift; cmd_restart "$@" ;;
    status) cmd_status ;;
    backend)
        case "${2:-}" in
            start) start_backend ;;
            stop) stop_backend ;;
            *) echo "Usage: appctl backend {start|stop}" ;;
        esac ;;
    flutter)
        case "${2:-}" in
            start) shift 2; start_flutter "$@" ;;
            stop) stop_flutter ;;
            build) build_flutter ;;
            *) echo "Usage: appctl flutter {start|stop|build}" ;;
        esac ;;
    mcp)
        case "${2:-}" in
            start) start_mcp ;;
            stop) stop_mcp ;;
            status) print_status "MCP Server" $MCP_PORT ;;
            *) echo "Usage: appctl mcp {start|stop|status}" ;;
        esac ;;
    db)
        case "${2:-}" in
            seed) seed_db ;;
            *) echo "Usage: appctl db seed" ;;
        esac ;;
    logs) shift; cmd_logs "${1:-backend}" ;;
    test) run_tests ;;
    clean)
        echo -e "${BLUE}Cleaning temporary files...${NC}"
        rm -rf "$LOG_DIR"/*.log 2>/dev/null || true
        rm -rf "$RUNS_LOG_DIR"/*.log 2>/dev/null || true
        rm -rf "$PID_DIR"/*.pid 2>/dev/null || true
        echo -e "${GREEN}Cleaned.${NC}" ;;
    version)
        echo -e "${BLUE}MyApp${NC}"
        echo "Version: 1.0.0"
        echo "Root: $ROOT_DIR"
        echo ""
        echo "Components:"
        command -v python3 >/dev/null && echo "  Python: $(python3 --version 2>&1 | cut -d' ' -f2)"
        command -v flutter >/dev/null && echo "  Flutter: $(flutter --version 2>&1 | head -1 | cut -d' ' -f2)" ;;
    help|-h|--help) usage ;;
    *) usage ;;
esac
```

## Installation Script Pattern (install.sh)

```bash
#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# MyApp - Installation Script
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FLUTTER_DIR="$ROOT_DIR/flutter_app"
VENV_DIR="$ROOT_DIR/venv"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}$*${NC}"; }
ok()    { echo -e "${GREEN}✓ $*${NC}"; }
warn()  { echo -e "${YELLOW}$*${NC}"; }
fail()  { echo -e "${RED}$*${NC}"; }

# =============================================================================
# 1. Prerequisites
# =============================================================================
info "=== MyApp Installation ==="
echo ""
info "Checking prerequisites..."

# Homebrew
if ! command -v brew &> /dev/null; then
    warn "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
ok "Homebrew"

# Python 3
if ! command -v python3 &> /dev/null; then
    warn "Python3 not found. Installing via Homebrew..."
    brew install python@3.11
fi
PYTHON_VERSION=$(python3 --version)
ok "$PYTHON_VERSION"

# =============================================================================
# 2. Python Virtual Environment
# =============================================================================
echo ""
info "Setting up Python virtual environment..."

if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    ok "Created venv at $VENV_DIR"
else
    ok "venv already exists at $VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
ok "Activated venv"

pip install --upgrade pip --quiet
ok "pip upgraded"

# =============================================================================
# 3. Install Python Dependencies
# =============================================================================
echo ""
info "Installing Python dependencies from requirements.txt..."
pip install -r "$ROOT_DIR/requirements.txt"
ok "Dependencies installed"

# =============================================================================
# 4. Verify Key Imports
# =============================================================================
echo ""
info "Verifying critical imports..."
python3 -c "
import sys, importlib
modules = ['fastapi', 'uvicorn', 'torch', 'transformers']
failed = []
for mod in modules:
    try:
        importlib.import_module(mod)
    except ImportError as e:
        failed.append((mod, str(e)))
if failed:
    print('ERROR: The following imports failed:')
    for mod, err in failed:
        print(f'  {mod}: {err}')
    sys.exit(1)
print('All critical imports OK')
"
ok "All critical imports verified"

# =============================================================================
# 5. Initialize Database
# =============================================================================
echo ""
info "Initializing database..."
cd "$BACKEND_DIR"
python3 database.py
ok "Database initialized and seeded"

# =============================================================================
# 6. Flutter (optional)
# =============================================================================
echo ""
if command -v flutter &> /dev/null; then
    info "Setting up Flutter..."
    cd "$FLUTTER_DIR"
    flutter pub get
    flutter config --enable-macos-desktop 2>/dev/null || true
    ok "Flutter ready"
else
    warn "Flutter not found - skipping Flutter setup."
    warn "Install Flutter for the desktop GUI: https://docs.flutter.dev/get-started/install/macos"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "To start MyApp:"
echo -e "  ${BLUE}source venv/bin/activate${NC}"
echo -e "  ${BLUE}./bin/appctl up${NC}"
echo ""
echo "Or start backend only:"
echo -e "  ${BLUE}source venv/bin/activate${NC}"
echo -e "  ${BLUE}cd backend && uvicorn main:app --host 0.0.0.0 --port 8000${NC}"
echo ""
echo "API docs: http://localhost:8000/docs"
```

## Test Patterns

### Integration Test Script (scripts/test_api.py)

```python
#!/usr/bin/env python3
"""
Full API test script for MyApp backend.
Run with: python scripts/test_api.py
Requires backend running on localhost:8000
"""

import requests
import sys

BASE_URL = "http://localhost:8000"

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'

def print_test(name: str, passed: bool, details: str = ""):
    status = f"{Colors.GREEN}PASS{Colors.END}" if passed else f"{Colors.RED}FAIL{Colors.END}"
    print(f"  [{status}] {name}")
    if details and not passed:
        print(f"         {Colors.YELLOW}{details}{Colors.END}")

def test_health():
    """Test health endpoint."""
    print(f"\n{Colors.BLUE}=== Health Check ==={Colors.END}")
    try:
        r = requests.get(f"{BASE_URL}/api/health")
        passed = r.status_code == 200 and r.json().get("status") == "ok"
        print_test("GET /api/health", passed, r.text)
        return passed
    except Exception as e:
        print_test("GET /api/health", False, str(e))
        return False

def test_system_stats():
    """Test system stats endpoint."""
    print(f"\n{Colors.BLUE}=== System Stats ==={Colors.END}")
    try:
        r = requests.get(f"{BASE_URL}/api/system/stats")
        data = r.json()
        passed = r.status_code == 200 and "cpu_percent" in data
        print_test("GET /api/system/stats", passed,
                   f"CPU: {data.get('cpu_percent')}%, RAM: {data.get('ram_percent')}%")
        return passed
    except Exception as e:
        print_test("GET /api/system/stats", False, str(e))
        return False

def test_voices():
    """Test voices listing."""
    print(f"\n{Colors.BLUE}=== Voices ==={Colors.END}")
    try:
        r = requests.get(f"{BASE_URL}/api/kokoro/voices")
        data = r.json()
        passed = r.status_code == 200 and "voices" in data
        print_test("GET /api/kokoro/voices", passed,
                   f"Found {len(data.get('voices', []))} voices")
        return passed, data.get("default")
    except Exception as e:
        print_test("GET /api/kokoro/voices", False, str(e))
        return False, None

def test_generate(voice: str):
    """Test generation endpoint."""
    print(f"\n{Colors.BLUE}=== Generation ==={Colors.END}")
    try:
        payload = {
            "text": "Hello, this is a test.",
            "voice": voice,
            "speed": 1.0
        }
        r = requests.post(f"{BASE_URL}/api/kokoro/generate", json=payload)
        data = r.json()
        passed = r.status_code == 200 and "audio_url" in data
        print_test(f"POST /api/kokoro/generate", passed, data.get("audio_url", r.text))
        return passed
    except Exception as e:
        print_test("POST /api/kokoro/generate", False, str(e))
        return False

def main():
    print(f"{Colors.BLUE}{'='*50}{Colors.END}")
    print(f"{Colors.BLUE}       MyApp API Test Suite{Colors.END}")
    print(f"{Colors.BLUE}{'='*50}{Colors.END}")

    results = []

    # Health check first
    if not test_health():
        print(f"\n{Colors.RED}Backend not running! Start with: ./bin/appctl up{Colors.END}")
        sys.exit(1)
    results.append(True)

    # System stats
    results.append(test_system_stats())

    # Voices
    passed, default_voice = test_voices()
    results.append(passed)

    # Generation
    if default_voice:
        results.append(test_generate(default_voice))

    # Summary
    passed_count = sum(results)
    total_count = len(results)
    print(f"\n{Colors.BLUE}{'='*50}{Colors.END}")
    print(f"Results: {passed_count}/{total_count} tests passed")

    if passed_count == total_count:
        print(f"{Colors.GREEN}All tests passed!{Colors.END}")
        sys.exit(0)
    else:
        print(f"{Colors.RED}Some tests failed.{Colors.END}")
        sys.exit(1)

if __name__ == "__main__":
    main()
```

### pytest Unit Tests (backend/tests/)

#### conftest.py

```python
import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient

backend_root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(backend_root))

from main import app

@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c
```

#### test_all_endpoints.py (Comprehensive)

```python
"""Comprehensive tests for every endpoint in the API.

Tests API contract, validation, error handling, and response structure.
Grouped by endpoint category.
"""

import io
import struct
import pytest
from fastapi.testclient import TestClient
from main import app


def _make_minimal_wav(
    num_channels: int = 1,
    sample_rate: int = 16000,
    bits_per_sample: int = 16,
    num_samples: int = 16000,
) -> io.BytesIO:
    """Create a minimal valid WAV file in memory."""
    data_size = num_samples * num_channels * (bits_per_sample // 8)
    buf = io.BytesIO()
    buf.write(b"RIFF")
    buf.write(struct.pack("<I", 36 + data_size))
    buf.write(b"WAVE")
    buf.write(b"fmt ")
    buf.write(struct.pack("<I", 16))
    buf.write(struct.pack("<H", 1))
    buf.write(struct.pack("<H", num_channels))
    buf.write(struct.pack("<I", sample_rate))
    buf.write(struct.pack("<I", sample_rate * num_channels * bits_per_sample // 8))
    buf.write(struct.pack("<H", num_channels * bits_per_sample // 8))
    buf.write(struct.pack("<H", bits_per_sample))
    buf.write(b"data")
    buf.write(struct.pack("<I", data_size))
    buf.write(b"\x00" * data_size)
    buf.seek(0)
    return buf


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


class TestSystemEndpoints:
    """GET /api/health, GET /api/system/info, GET /api/system/stats"""

    def test_health_returns_200(self, client):
        resp = client.get("/api/health")
        assert resp.status_code == 200

    def test_health_has_status_key(self, client):
        data = client.get("/api/health").json()
        assert "status" in data
        assert data["status"] == "ok"

    def test_system_info_returns_200(self, client):
        resp = client.get("/api/system/info")
        assert resp.status_code == 200

    def test_system_info_has_required_fields(self, client):
        data = client.get("/api/system/info").json()
        for key in ("python_version", "device", "os", "arch"):
            assert key in data, f"Missing key: {key}"

    def test_system_stats_returns_200(self, client):
        resp = client.get("/api/system/stats")
        assert resp.status_code == 200

    def test_system_stats_has_required_fields(self, client):
        data = client.get("/api/system/stats").json()
        assert "cpu_percent" in data
        assert "ram_used_gb" in data
        assert "ram_total_gb" in data


class TestVoicesEndpoints:
    """Voice listing and management."""

    def test_list_voices_returns_200(self, client):
        resp = client.get("/api/kokoro/voices")
        assert resp.status_code == 200

    def test_list_voices_has_voices_key(self, client):
        data = client.get("/api/kokoro/voices").json()
        assert "voices" in data
        assert isinstance(data["voices"], list)

    def test_upload_voice_with_form_data(self, client):
        """Upload a minimal WAV file as a new voice sample."""
        wav = _make_minimal_wav()
        resp = client.post(
            "/api/qwen3/voices",
            data={"name": "__test_upload__", "transcript": "hello"},
            files={"file": ("test.wav", wav, "audio/wav")},
        )
        # 200 on success, 500/503 if engine not installed
        assert resp.status_code in (200, 500, 503)
        # Cleanup
        client.delete("/api/qwen3/voices/__test_upload__")


class TestGenerationEndpoints:
    """POST /api/{engine}/generate"""

    def test_generate_missing_text_returns_422(self, client):
        resp = client.post("/api/kokoro/generate", json={})
        assert resp.status_code == 422

    def test_generate_valid_body_shape(self, client):
        resp = client.post("/api/kokoro/generate", json={
            "text": "Hello world",
            "voice": "bf_emma",
            "speed": 1.0,
        })
        # Should not be validation error
        assert resp.status_code != 422


class TestEdgeCases:
    """Miscellaneous edge cases."""

    def test_unknown_route_returns_404(self, client):
        resp = client.get("/api/this-does-not-exist")
        assert resp.status_code == 404

    def test_health_method_not_allowed(self, client):
        resp = client.post("/api/health")
        assert resp.status_code == 405

    def test_cors_headers_present(self, client):
        resp = client.options(
            "/api/health",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )
        assert "access-control-allow-origin" in resp.headers
```

## Troubleshooting Diagnostic Script (issues.sh)

```bash
#!/usr/bin/env bash
# =============================================================================
# MyApp - Diagnostic Script
# =============================================================================
# Collects system info, checks dependencies, tests connectivity.
# Output: issues_report_<timestamp>.log
# Run: ./issues.sh
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$ROOT_DIR/issues_report_$TIMESTAMP.log"
VENV_DIR="$ROOT_DIR/venv"
BACKEND_DIR="$ROOT_DIR/backend"
FLUTTER_DIR="$ROOT_DIR/flutter_app"
LOG_DIR="$ROOT_DIR/.logs"
RUNS_LOG_DIR="$ROOT_DIR/runs/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "$*" | tee -a "$LOG_FILE"; }
section() {
    log ""
    log "============================================================================="
    log "  $*"
    log "============================================================================="
}
subsection() { log "\n--- $* ---"; }

run_cmd() {
    local desc="$1"; shift
    log "$ $*"
    if output=$("$@" 2>&1); then
        log "$output"
        return 0
    else
        log "$output"
        log "${RED}[FAILED]${NC} $desc (exit code: $?)"
        return $?
    fi
}

echo "" > "$LOG_FILE"
log "${CYAN}MyApp Diagnostic Report${NC}"
log "Generated: $(date)"
log "Working Directory: $ROOT_DIR"

# =============================================================================
# 1. System Information
# =============================================================================
section "SYSTEM INFORMATION"

subsection "OS Version"
run_cmd "OS" uname -a
run_cmd "Architecture" uname -m

subsection "Disk Space"
run_cmd "Disk" df -h "$ROOT_DIR"

# =============================================================================
# 2. Development Tools
# =============================================================================
section "DEVELOPMENT TOOLS"

for tool in python3 pip3 flutter git brew; do
    if command -v $tool &>/dev/null; then
        log "${GREEN}$tool${NC}: $($tool --version 2>&1 | head -1)"
    else
        log "${YELLOW}$tool${NC}: NOT INSTALLED"
    fi
done

# =============================================================================
# 3. Python Environment
# =============================================================================
section "PYTHON ENVIRONMENT"

subsection "Python Version"
run_cmd "Python" python3 --version

subsection "pip Version"
run_cmd "pip" pip3 --version

# =============================================================================
# 4. Virtual Environment
# =============================================================================
section "VIRTUAL ENVIRONMENT"

if [ -d "$VENV_DIR" ]; then
    log "${GREEN}venv exists${NC}: $VENV_DIR"

    subsection "Installed Packages"
    for pkg in fastapi uvicorn torch transformers psutil; do
        version=$("$VENV_DIR/bin/pip" show "$pkg" 2>/dev/null | grep "^Version:" | cut -d' ' -f2)
        if [ -n "$version" ]; then
            log "  ${GREEN}$pkg${NC}: $version"
        else
            log "  ${YELLOW}$pkg${NC}: NOT INSTALLED"
        fi
    done

    subsection "Import Tests"
    "$VENV_DIR/bin/python" -c "
import sys
for mod in ['fastapi', 'uvicorn', 'torch', 'transformers']:
    try:
        __import__(mod)
        print(f'  [OK] {mod}')
    except ImportError as e:
        print(f'  [FAIL] {mod}: {e}')
" 2>&1 | tee -a "$LOG_FILE"
else
    log "${RED}venv NOT found${NC} at $VENV_DIR"
    log "Run: ./install.sh"
fi

# =============================================================================
# 5. Flutter Environment
# =============================================================================
section "FLUTTER ENVIRONMENT"

if command -v flutter &>/dev/null; then
    subsection "Flutter Version"
    run_cmd "Flutter" flutter --version

    subsection "Flutter Doctor"
    flutter doctor 2>&1 | head -20 | tee -a "$LOG_FILE"

    if [ -d "$FLUTTER_DIR" ]; then
        subsection "pubspec.yaml"
        if [ -f "$FLUTTER_DIR/pubspec.yaml" ]; then
            log "${GREEN}pubspec.yaml exists${NC}"
            grep "^name:" "$FLUTTER_DIR/pubspec.yaml" | tee -a "$LOG_FILE"
        else
            log "${RED}pubspec.yaml NOT found${NC}"
        fi
    fi
else
    log "${YELLOW}Flutter NOT installed${NC}"
fi

# =============================================================================
# 6. Port Status
# =============================================================================
section "PORT STATUS"

for port in 8000 8010 5173; do
    if command -v lsof &>/dev/null; then
        status=$(lsof -i :$port 2>/dev/null | grep LISTEN || echo "Available")
        log "Port $port: $status"
    fi
done

# =============================================================================
# 7. Network Tests
# =============================================================================
section "NETWORK TESTS"

subsection "Backend Health Check"
if curl -s --connect-timeout 5 http://localhost:8000/api/health > /dev/null 2>&1; then
    log "${GREEN}Backend reachable${NC}"
    log "Response: $(curl -s http://localhost:8000/api/health)"
else
    log "${YELLOW}Backend not responding${NC} on port 8000"
fi

subsection "MCP Server"
if curl -s --connect-timeout 5 http://localhost:8010 > /dev/null 2>&1; then
    log "${GREEN}MCP Server reachable${NC} on port 8010"
else
    log "${YELLOW}MCP Server not responding${NC} on port 8010"
fi

# =============================================================================
# 8. Runtime Logs
# =============================================================================
section "RUNTIME LOGS"

subsection "Flutter Log"
FLUTTER_LOG="$LOG_DIR/flutter.log"
if [ -f "$FLUTTER_LOG" ]; then
    log "${GREEN}Flutter log exists${NC}: $FLUTTER_LOG"
    log "Last 50 lines:"
    log "----------------------------------------"
    tail -50 "$FLUTTER_LOG" 2>/dev/null | while IFS= read -r line; do
        log "$line"
    done
    log "----------------------------------------"
else
    log "${YELLOW}Flutter log not found${NC} (Flutter may not have been started yet)"
fi

subsection "Backend Log"
BACKEND_LOG="$LOG_DIR/backend.log"
if [ -f "$BACKEND_LOG" ]; then
    log "${GREEN}Backend log exists${NC}: $BACKEND_LOG"
    log "Last 50 lines:"
    log "----------------------------------------"
    tail -50 "$BACKEND_LOG" 2>/dev/null | while IFS= read -r line; do
        log "$line"
    done
    log "----------------------------------------"
else
    log "${YELLOW}Backend log not found${NC} (Backend may not have been started yet)"
fi

subsection "MCP Server Log"
MCP_LOG="$RUNS_LOG_DIR/mcp_server.log"
if [ -f "$MCP_LOG" ]; then
    log "${GREEN}MCP server log exists${NC}: $MCP_LOG"
    log "Last 50 lines:"
    log "----------------------------------------"
    tail -50 "$MCP_LOG" 2>/dev/null | while IFS= read -r line; do
        log "$line"
    done
    log "----------------------------------------"
else
    log "${YELLOW}MCP server log not found${NC}"
fi

# =============================================================================
# 9. Environment Variables
# =============================================================================
section "ENVIRONMENT VARIABLES"

for var in PATH PYTHONPATH VIRTUAL_ENV HOME; do
    val="${!var:-<not set>}"
    if [ ${#val} -gt 100 ]; then
        val="${val:0:100}..."
    fi
    log "  $var: $val"
done

# =============================================================================
# Summary
# =============================================================================
section "SUMMARY"

log "Report saved to: ${CYAN}$LOG_FILE${NC}"
log ""
log "Share this file when reporting issues on GitHub."
log ""
echo -e "${GREEN}Done!${NC} Report: $LOG_FILE"
```

## MCP Server Pattern (Optional)

```python
#!/usr/bin/env python3
"""MCP Server for TTS operations."""

import json
import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
import logging

# Setup logging
LOG_DIR = Path(__file__).parent.parent / "runs" / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_DIR / "mcp_server.log"),
    ]
)
logger = logging.getLogger(__name__)

TOOLS = [
    {
        "name": "generate_speech",
        "description": "Generate speech audio from text",
        "inputSchema": {
            "type": "object",
            "properties": {
                "text": {"type": "string", "description": "Text to convert to speech"},
                "voice": {"type": "string", "description": "Voice to use"},
            },
            "required": ["text"]
        }
    },
    {
        "name": "list_voices",
        "description": "List available voices",
        "inputSchema": {"type": "object", "properties": {}}
    }
]

class MCPHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        request = json.loads(body)

        method = request.get("method")
        request_id = request.get("id")

        logger.info(f"MCP request: {method}")

        if method == "initialize":
            result = {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "myapp-mcp", "version": "1.0.0"}
            }
        elif method == "tools/list":
            result = {"tools": TOOLS}
        elif method == "tools/call":
            result = self._handle_tool_call(request.get("params", {}))
        else:
            result = {"error": f"Unknown method: {method}"}

        response = {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": result
        }

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

    def _handle_tool_call(self, params):
        tool_name = params.get("name")
        arguments = params.get("arguments", {})

        if tool_name == "list_voices":
            return {"content": [{"type": "text", "text": "Available voices: Emma, Daniel, Ryan"}]}
        elif tool_name == "generate_speech":
            text = arguments.get("text", "")
            return {"content": [{"type": "text", "text": f"Generated speech for: {text[:50]}..."}]}

        return {"error": f"Unknown tool: {tool_name}"}

    def log_message(self, format, *args):
        logger.info("%s - %s" % (self.address_string(), format % args))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8010)
    args = parser.parse_args()

    server = HTTPServer((args.host, args.port), MCPHandler)
    logger.info(f"MCP Server starting on {args.host}:{args.port}")
    server.serve_forever()

if __name__ == "__main__":
    main()
```

## Licensing & Payments (Polar)

Add licensing to a Flutter app with 7-day trial, license key activation, and Polar.sh for payments.

### Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│   Flutter App   │────▶│  Licensing API   │────▶│   Polar.sh  │
│                 │     │   (your backend) │     │  (payments) │
│ - Trial banner  │     │                  │     │             │
│ - License entry │     │ - Trial mgmt     │◀────│ - Webhooks  │
│ - Feature gate  │     │ - JWT tokens     │     │ - Checkout  │
│ - Token storage │     │ - Device binding │     │ - Entitle.  │
└─────────────────┘     └──────────────────┘     └─────────────┘
```

### Backend Data Model

```python
# models/licensing.py
from sqlalchemy import Column, String, Boolean, DateTime
from database import Base
import uuid
from datetime import datetime

class Activation(Base):
    __tablename__ = "activations"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    license_key_hash = Column(String, nullable=False, index=True)
    device_id = Column(String, nullable=False)
    customer_id = Column(String, nullable=True)
    product_id = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_seen_at = Column(DateTime, default=datetime.utcnow)
    revoked = Column(Boolean, default=False)

class TrialIssuance(Base):
    __tablename__ = "trial_issuances"

    device_id = Column(String, primary_key=True)
    trial_started_at = Column(DateTime, default=datetime.utcnow)
    last_check_at = Column(DateTime, default=datetime.utcnow)
```

### Backend Licensing Endpoints

```python
# routes/licensing.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from datetime import datetime, timedelta
import jwt
import hashlib
import httpx

router = APIRouter(prefix="/v1", tags=["licensing"])

# Config
JWT_SECRET = os.getenv("JWT_SECRET")
POLAR_API_KEY = os.getenv("POLAR_API_KEY")
TRIAL_DAYS = 7
TOKEN_EXPIRY_DAYS = 14
MAX_ACTIVATIONS_PER_LICENSE = 2

class TrialStartRequest(BaseModel):
    deviceId: str
    appVersion: str
    platform: str

class TrialStatusResponse(BaseModel):
    trialStartedAt: datetime
    trialEndsAt: datetime
    isTrialActive: bool
    serverTime: datetime

class LicenseActivateRequest(BaseModel):
    licenseKey: str
    deviceId: str
    appVersion: str
    platform: str

class LicenseRefreshRequest(BaseModel):
    token: str
    deviceId: str

@router.post("/trial/start")
async def start_trial(req: TrialStartRequest, db: Session = Depends(get_db)):
    """Start or return existing trial for device."""
    existing = db.query(TrialIssuance).filter_by(device_id=req.deviceId).first()

    if existing:
        trial_ends = existing.trial_started_at + timedelta(days=TRIAL_DAYS)
        return {
            "trialStartedAt": existing.trial_started_at,
            "trialEndsAt": trial_ends,
            "serverTime": datetime.utcnow()
        }

    trial = TrialIssuance(device_id=req.deviceId)
    db.add(trial)
    db.commit()

    return {
        "trialStartedAt": trial.trial_started_at,
        "trialEndsAt": trial.trial_started_at + timedelta(days=TRIAL_DAYS),
        "serverTime": datetime.utcnow()
    }

@router.get("/trial/status")
async def get_trial_status(deviceId: str, db: Session = Depends(get_db)):
    """Check trial status for device."""
    trial = db.query(TrialIssuance).filter_by(device_id=deviceId).first()

    if not trial:
        raise HTTPException(404, "No trial found for this device")

    now = datetime.utcnow()
    trial_ends = trial.trial_started_at + timedelta(days=TRIAL_DAYS)

    return TrialStatusResponse(
        trialStartedAt=trial.trial_started_at,
        trialEndsAt=trial_ends,
        isTrialActive=now < trial_ends,
        serverTime=now
    )

@router.post("/license/activate")
async def activate_license(req: LicenseActivateRequest, db: Session = Depends(get_db)):
    """Validate license with Polar and issue entitlement token."""
    # Validate with Polar API
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"https://api.polar.sh/v1/license-keys/{req.licenseKey}/validate",
            headers={"Authorization": f"Bearer {POLAR_API_KEY}"}
        )

        if resp.status_code != 200:
            raise HTTPException(400, "Invalid or inactive license")

        polar_data = resp.json()

        if not polar_data.get("active"):
            raise HTTPException(400, "License is not active")

    # Check activation count
    key_hash = hashlib.sha256(req.licenseKey.encode()).hexdigest()
    existing_activations = db.query(Activation).filter_by(
        license_key_hash=key_hash, revoked=False
    ).count()

    if existing_activations >= MAX_ACTIVATIONS_PER_LICENSE:
        raise HTTPException(400, "Maximum activations reached for this license")

    # Create activation record
    activation = Activation(
        license_key_hash=key_hash,
        device_id=req.deviceId,
        customer_id=polar_data.get("customer_id"),
        product_id=polar_data.get("product_id")
    )
    db.add(activation)
    db.commit()

    # Issue JWT
    exp = datetime.utcnow() + timedelta(days=TOKEN_EXPIRY_DAYS)
    token = jwt.encode({
        "sub": activation.id,
        "deviceId": req.deviceId,
        "entitlements": ["pro"],
        "exp": exp,
        "refreshBefore": (exp - timedelta(days=2)).isoformat()
    }, JWT_SECRET, algorithm="HS256")

    return {"token": token, "expiresAt": exp.isoformat()}

@router.post("/license/refresh")
async def refresh_license(req: LicenseRefreshRequest, db: Session = Depends(get_db)):
    """Refresh entitlement token if license still valid."""
    try:
        payload = jwt.decode(req.token, JWT_SECRET, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token")

    # Verify activation still valid
    activation = db.query(Activation).filter_by(
        id=payload["sub"], revoked=False
    ).first()

    if not activation:
        raise HTTPException(401, "Activation revoked or not found")

    # Update last seen
    activation.last_seen_at = datetime.utcnow()
    db.commit()

    # Issue new token
    exp = datetime.utcnow() + timedelta(days=TOKEN_EXPIRY_DAYS)
    new_token = jwt.encode({
        "sub": activation.id,
        "deviceId": req.deviceId,
        "entitlements": ["pro"],
        "exp": exp,
        "refreshBefore": (exp - timedelta(days=2)).isoformat()
    }, JWT_SECRET, algorithm="HS256")

    return {"token": new_token, "expiresAt": exp.isoformat()}

@router.post("/license/deactivate")
async def deactivate_license(licenseKey: str, deviceId: str, db: Session = Depends(get_db)):
    """Revoke activation for a device."""
    key_hash = hashlib.sha256(licenseKey.encode()).hexdigest()
    activation = db.query(Activation).filter_by(
        license_key_hash=key_hash, device_id=deviceId, revoked=False
    ).first()

    if activation:
        activation.revoked = True
        db.commit()

    return {"message": "Deactivated"}
```

### Polar Webhook Handler

```python
# routes/webhooks.py
from fastapi import APIRouter, Request, HTTPException
import hmac
import hashlib

router = APIRouter(prefix="/webhooks", tags=["webhooks"])
POLAR_WEBHOOK_SECRET = os.getenv("POLAR_WEBHOOK_SECRET")

@router.post("/polar")
async def polar_webhook(request: Request, db: Session = Depends(get_db)):
    """Handle Polar webhook events."""
    body = await request.body()
    signature = request.headers.get("Polar-Signature")

    # Verify signature
    expected = hmac.new(
        POLAR_WEBHOOK_SECRET.encode(),
        body,
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(signature, expected):
        raise HTTPException(401, "Invalid signature")

    event = await request.json()
    event_type = event.get("type")

    if event_type in ("subscription.canceled", "order.refunded", "subscription.revoked"):
        # Mark activations as revoked
        customer_id = event["data"]["customer_id"]
        db.query(Activation).filter_by(
            customer_id=customer_id, revoked=False
        ).update({"revoked": True})
        db.commit()

    return {"received": True}
```

### Flutter Licensing Service

```dart
// services/licensing_service.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class EntitlementState {
  final bool trialActive;
  final bool proActive;
  final String? reason;
  final DateTime? trialEndsAt;

  EntitlementState({
    required this.trialActive,
    required this.proActive,
    this.reason,
    this.trialEndsAt,
  });

  bool get canAccessPro => proActive || trialActive;
}

class LicensingService {
  static const String baseUrl = 'http://localhost:8000';
  final _storage = const FlutterSecureStorage();

  // Storage keys
  static const _keyDeviceId = 'device_id';
  static const _keyTrialStarted = 'trial_started_at';
  static const _keyTrialEnds = 'trial_ends_at';
  static const _keyLicenseToken = 'license_token';
  static const _keyTokenExpires = 'token_expires_at';
  static const _keyServerTimeOffset = 'server_time_offset';

  String? _deviceId;

  /// Initialize device ID (create if not exists)
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    _deviceId = await _storage.read(key: _keyDeviceId);
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await _storage.write(key: _keyDeviceId, value: _deviceId);
    }
    return _deviceId!;
  }

  /// Start trial and store server timestamps
  Future<void> startTrial() async {
    final deviceId = await getDeviceId();

    final response = await http.post(
      Uri.parse('$baseUrl/v1/trial/start'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'deviceId': deviceId,
        'appVersion': '1.0.0',
        'platform': 'macos',
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _storage.write(key: _keyTrialStarted, value: data['trialStartedAt']);
      await _storage.write(key: _keyTrialEnds, value: data['trialEndsAt']);

      // Store server time offset for clock tampering protection
      final serverTime = DateTime.parse(data['serverTime']);
      final offset = serverTime.difference(DateTime.now()).inSeconds;
      await _storage.write(key: _keyServerTimeOffset, value: offset.toString());
    }
  }

  /// Get trial status (prefer server, fall back to cache)
  Future<Map<String, dynamic>?> getTrialStatus({bool forceServer = false}) async {
    final deviceId = await getDeviceId();

    if (forceServer) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/v1/trial/status?deviceId=$deviceId'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          await _storage.write(key: _keyTrialEnds, value: data['trialEndsAt']);
          return data;
        }
      } catch (e) {
        // Fall through to cached
      }
    }

    // Return cached data
    final trialEnds = await _storage.read(key: _keyTrialEnds);
    if (trialEnds != null) {
      final ends = DateTime.parse(trialEnds);
      final offsetStr = await _storage.read(key: _keyServerTimeOffset);
      final offset = int.tryParse(offsetStr ?? '0') ?? 0;
      final adjustedNow = DateTime.now().add(Duration(seconds: offset));

      return {
        'trialEndsAt': trialEnds,
        'isTrialActive': adjustedNow.isBefore(ends),
      };
    }
    return null;
  }

  /// Activate license with key
  Future<bool> activateLicense(String licenseKey) async {
    final deviceId = await getDeviceId();

    final response = await http.post(
      Uri.parse('$baseUrl/v1/license/activate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'licenseKey': licenseKey,
        'deviceId': deviceId,
        'appVersion': '1.0.0',
        'platform': 'macos',
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _storage.write(key: _keyLicenseToken, value: data['token']);
      await _storage.write(key: _keyTokenExpires, value: data['expiresAt']);
      return true;
    }
    return false;
  }

  /// Refresh token if expiring soon
  Future<void> refreshLicenseIfNeeded() async {
    final token = await _storage.read(key: _keyLicenseToken);
    final expiresStr = await _storage.read(key: _keyTokenExpires);

    if (token == null || expiresStr == null) return;

    final expires = DateTime.parse(expiresStr);
    final refreshThreshold = DateTime.now().add(const Duration(hours: 48));

    if (expires.isBefore(refreshThreshold)) {
      final deviceId = await getDeviceId();

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/v1/license/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'token': token, 'deviceId': deviceId}),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          await _storage.write(key: _keyLicenseToken, value: data['token']);
          await _storage.write(key: _keyTokenExpires, value: data['expiresAt']);
        } else {
          // Token invalid - clear it
          await _storage.delete(key: _keyLicenseToken);
          await _storage.delete(key: _keyTokenExpires);
        }
      } catch (e) {
        // Offline - will retry later
      }
    }
  }

  /// Get current entitlement state
  Future<EntitlementState> getEntitlementState() async {
    // Check license token first
    final token = await _storage.read(key: _keyLicenseToken);
    final expiresStr = await _storage.read(key: _keyTokenExpires);

    if (token != null && expiresStr != null) {
      final expires = DateTime.parse(expiresStr);
      // Grace period: 3 days after expiry for offline users
      final graceEnd = expires.add(const Duration(days: 3));

      if (DateTime.now().isBefore(graceEnd)) {
        return EntitlementState(
          trialActive: false,
          proActive: true,
          reason: DateTime.now().isAfter(expires) ? 'grace_period' : 'licensed',
        );
      }
    }

    // Check trial
    final trialStatus = await getTrialStatus();
    if (trialStatus != null && trialStatus['isTrialActive'] == true) {
      return EntitlementState(
        trialActive: true,
        proActive: false,
        reason: 'trial',
        trialEndsAt: DateTime.parse(trialStatus['trialEndsAt']),
      );
    }

    return EntitlementState(
      trialActive: false,
      proActive: false,
      reason: 'no_entitlement',
    );
  }
}
```

### Flutter Trial Banner Widget

```dart
// widgets/trial_banner.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/licensing_service.dart';

class TrialBanner extends StatelessWidget {
  final EntitlementState state;
  final VoidCallback onEnterLicense;
  final String polarCheckoutUrl;

  const TrialBanner({
    super.key,
    required this.state,
    required this.onEnterLicense,
    required this.polarCheckoutUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (state.proActive && state.reason != 'grace_period') {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    Color bgColor;
    String message;

    if (state.reason == 'grace_period') {
      bgColor = Colors.orange.shade100;
      message = 'License needs renewal - please connect to internet';
    } else if (state.trialActive && state.trialEndsAt != null) {
      final daysLeft = state.trialEndsAt!.difference(DateTime.now()).inDays;
      bgColor = daysLeft <= 2 ? Colors.orange.shade100 : theme.colorScheme.primaryContainer;
      message = 'Trial: $daysLeft days remaining';
    } else {
      bgColor = Colors.red.shade100;
      message = 'Trial ended';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          Icon(
            state.proActive ? Icons.warning : Icons.access_time,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(polarCheckoutUrl)),
            child: const Text('Buy License'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onEnterLicense,
            child: const Text('Enter License'),
          ),
        ],
      ),
    );
  }
}
```

### Flutter License Entry Dialog

```dart
// widgets/license_entry_dialog.dart
import 'package:flutter/material.dart';
import '../services/licensing_service.dart';

class LicenseEntryDialog extends StatefulWidget {
  final LicensingService licensingService;

  const LicenseEntryDialog({super.key, required this.licensingService});

  static Future<bool?> show(BuildContext context, LicensingService service) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => LicenseEntryDialog(licensingService: service),
    );
  }

  @override
  State<LicenseEntryDialog> createState() => _LicenseEntryDialogState();
}

class _LicenseEntryDialogState extends State<LicenseEntryDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _activate() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    final success = await widget.licensingService.activateLicense(key);

    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _loading = false;
          _error = 'Invalid or inactive license key';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter License Key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX-XXXX-XXXX',
              errorText: _error,
            ),
            enabled: !_loading,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _activate,
          child: const Text('Activate'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

### Flutter Feature Gating Pattern

```dart
// In any screen needing Pro features:
class ProFeatureScreen extends StatelessWidget {
  final EntitlementState entitlementState;
  final Widget child;
  final Widget? lockedWidget;

  const ProFeatureScreen({
    super.key,
    required this.entitlementState,
    required this.child,
    this.lockedWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (entitlementState.canAccessPro) {
      return child;
    }

    return lockedWidget ?? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Pro Feature', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Upgrade to access this feature'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Show license dialog or open checkout
            },
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }
}
```

### Licensing Policies

| Policy | Recommendation |
|--------|----------------|
| Trial duration | 7 days (configurable) |
| Token expiry | 14 days (requires periodic online check) |
| Offline grace | 3 days after token expiry |
| Max activations | 2 devices per license (configurable) |
| Clock tampering | Use server timestamps, store offset |
| Reinstall | Trial resets (acceptable for indie apps) |
| Refunds | Handled via webhook, revokes on next refresh |

### Environment Variables

```bash
# Backend .env
JWT_SECRET=your-jwt-secret-min-32-chars
POLAR_API_KEY=polar_sk_...
POLAR_WEBHOOK_SECRET=whsec_...
```

### Flutter Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  http: ^1.1.0
  url_launcher: ^6.2.0
  uuid: ^4.0.0
```

## Quick Reference

| Component | Location | Key Files |
|-----------|----------|-----------|
| Backend | `backend/` | `main.py`, `database.py` |
| Flutter | `flutter_app/` | `main.dart`, `api_service.dart` |
| Control | `bin/` | `appctl`, `appctl.ps1` |
| Install | root | `install.sh`, `install.bat` |
| Diagnose | root | `issues.sh` |
| Tests (integration) | `scripts/` | `test_api.py` |
| Tests (unit) | `backend/tests/` | `conftest.py`, `test_*.py` |
| MCP Server | `bin/` | `tts_mcp_server.py` |
| Licensing | `backend/routes/` | `licensing.py`, `webhooks.py` |
| Licensing (Flutter) | `flutter_app/lib/` | `licensing_service.dart`, `trial_banner.dart` |
| DMG Builder | `scripts/` | `build_dmg.sh` |
| Dist | `dist/` | `MyApp-x.x.x-macos.dmg` |
| Logs | `.logs/`, `runs/logs/` | `backend.log`, `flutter.log`, `mcp_server.log` |
| PIDs | `.pids/` | `backend.pid`, `flutter.pid`, `mcp.pid` |

## Code Review Checklist

When reviewing an existing app against this skill:

1. Check each item below
2. **For any missing items: CREATE them immediately** - do not just document gaps
3. Use the patterns and templates in this skill as your guide

### Project Structure Review

- [ ] `backend/` contains FastAPI app with `main.py`
- [ ] `flutter_app/` contains Flutter code with proper structure
- [ ] `bin/appctl` control script exists (comprehensive)
- [ ] `install.sh` installer script exists
- [ ] `issues.sh` diagnostic script exists with runtime logs section
- [ ] `.logs/` and `.pids/` directories managed
- [ ] `venv/` for Python isolation

### Flutter UI Review

- [ ] **Theme**: Uses `ColorScheme.fromSeed()` with Material 3
- [ ] **Dark mode**: Supports `ThemeMode.system`
- [ ] **Backend check**: Health check on startup with loading/disconnected states
- [ ] **Stats polling**: Uses `Future.doWhile()` with `mounted` guard
- [ ] **Navigation**: TabBar with scrollable tabs, icons (28px), bold labels
- [ ] **Status chips**: Color-coded (green/orange/red) using `withValues(alpha:)`
- [ ] **Sidebar**: For list views, uses sidebar + main content pattern (280px)
- [ ] **Cards**: Uses theme colors (`secondaryContainer`, `tertiaryContainer`, `surfaceContainerHighest`)
- [ ] **Error display**: Red-tinted error cards (`Colors.red.shade100`)
- [ ] **ApiService**: Centralized HTTP client with engine-specific endpoints

### Python Backend Review

- [ ] **FastAPI lifespan**: Uses `@asynccontextmanager` pattern
- [ ] **CORS**: Middleware configured for Flutter web
- [ ] **Health endpoint**: `GET /api/health` exists
- [ ] **System info**: `GET /api/system/info` with models status
- [ ] **System stats**: `GET /api/system/stats` with CPU/RAM/GPU
- [ ] **Static files**: Mounted for serving generated content
- [ ] **Pydantic models**: Request/response validation
- [ ] **Engine pattern**: Singletons with `get_engine()` factory
- [ ] **Multi-engine**: Engine-specific endpoints (`/api/{engine}/...`)

### Control Scripts Review

- [ ] **appctl up**: Starts backend + MCP + Flutter with flags
- [ ] **appctl down**: Stops all services cleanly
- [ ] **appctl status**: Shows running/stopped with colors
- [ ] **appctl logs**: Tails log files (backend|mcp|flutter|all)
- [ ] **appctl test**: Runs API tests
- [ ] **appctl clean**: Cleans logs and temp files
- [ ] **Health polling**: `wait_for_health()` with retry loop
- [ ] **venv detection**: Checks both root and backend locations
- [ ] **PID management**: Stores PIDs, cleans up on stop

### Testing Review

- [ ] **Integration tests**: `scripts/test_api.py` with colored output
- [ ] **conftest.py**: Path setup, TestClient fixture
- [ ] **Test structure**: Class-based organization by endpoint category
- [ ] **Health tests**: Verify `/api/health` returns 200
- [ ] **Validation tests**: Test 422 for missing required fields
- [ ] **Edge cases**: Test 404 for unknown routes, 405 for wrong methods

### Diagnostic Script Review

- [ ] **System info**: OS, architecture, disk space
- [ ] **Tools check**: Python, Flutter, git versions
- [ ] **venv check**: Package versions, import tests
- [ ] **Port status**: Check 8000, 8010, 5173
- [ ] **Network tests**: Backend and MCP health checks
- [ ] **Runtime logs**: Include last 50 lines of flutter.log, backend.log, mcp_server.log
- [ ] **Timestamped output**: `issues_report_YYYYMMDD_HHMMSS.log`

### Licensing Review (if applicable)

- [ ] **Backend endpoints**: `/v1/trial/start`, `/v1/trial/status`, `/v1/license/activate`, `/v1/license/refresh`
- [ ] **JWT signing**: Uses secure secret, stored in env vars
- [ ] **License key hashing**: Keys hashed at rest in DB
- [ ] **Activation limit**: Max devices per license enforced
- [ ] **Webhook handler**: Polar webhooks verified with signature
- [ ] **Flutter secure storage**: Device ID and tokens in `flutter_secure_storage`
- [ ] **Server timestamps**: Trial based on server time, not device clock
- [ ] **Token refresh**: Automatic refresh before expiry (48h threshold)
- [ ] **Offline grace**: 3-day grace period after token expiry
- [ ] **Trial banner**: Shows days remaining, buy/enter license buttons
- [ ] **Feature gating**: Pro features wrapped with `EntitlementState` check
- [ ] **No secrets in app**: Polar API key only on server

## Productization Patterns

When preparing an app for commercial release, implement these patterns:

### Centralized Version Management

Create synchronized version files across all components:

**backend/version.py:**
```python
"""Version information."""
VERSION = "2026.02.1"  # Date-based: YYYY.MM.N
BUILD_NUMBER = 1
VERSION_NAME = "Initial Release"

def get_version_string() -> str:
    return f"{VERSION} (build {BUILD_NUMBER})"
```

**flutter_app/lib/version.dart:**
```dart
const String appVersion = "2026.02.1";
const int buildNumber = 1;
const String versionName = "Initial Release";
String get versionString => "$appVersion (build $buildNumber)";
```

**scripts/bump_version.py** - Synchronizes versions across:
- backend/version.py
- flutter_app/lib/version.dart
- flutter_app/pubspec.yaml

### Settings Infrastructure

**Database tables (database.py):**
```python
CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS license_info (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    license_key TEXT,
    email TEXT,
    activated_at TIMESTAMP,
    last_validated TIMESTAMP,
    is_valid INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS trial_info (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);
```

**settings_service.py pattern:**
```python
def get_setting(key: str) -> str | None:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT value FROM app_settings WHERE key = ?", (key,))
    row = cursor.fetchone()
    conn.close()
    return row[0] if row else None

def set_setting(key: str, value: str) -> bool:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        """INSERT INTO app_settings (key, value, updated_at)
           VALUES (?, ?, ?)
           ON CONFLICT(key) DO UPDATE SET value = ?, updated_at = ?""",
        (key, value, datetime.now(), value, datetime.now())
    )
    conn.commit()
    conn.close()
    return True
```

**Settings endpoints:**
- `GET /api/settings` - All settings
- `GET /api/settings/{key}` - Single setting
- `PUT /api/settings` - Update setting
- `GET /api/settings/output-folder` - Get output folder
- `PUT /api/settings/output-folder` - Set output folder

### Flutter Settings Service

**flutter_app/lib/services/settings_service.dart:**
```dart
class SettingsService {
  static const String baseUrl = 'http://localhost:8000';

  Future<Map<String, String>> getAllSettings() async {
    final response = await http.get(Uri.parse('$baseUrl/api/settings'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, v.toString()));
    }
    throw Exception('Failed to load settings');
  }

  Future<void> setSetting(String key, String value) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/settings'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'key': key, 'value': value}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update setting');
    }
  }
}
```

### Professional UI Screens

**8-tab navigation structure:**
```dart
DefaultTabController(
  length: 8,
  child: Scaffold(
    appBar: AppBar(
      title: _buildSystemStatsBar(),
      actions: [/* version badge */],
      bottom: const TabBar(
        tabs: [
          Tab(icon: Icon(Icons.volume_up), text: 'TTS'),
          Tab(icon: Icon(Icons.record_voice_over), text: 'Clone'),
          // ... feature tabs
          Tab(icon: Icon(Icons.model_training), text: 'Models'),
          Tab(icon: Icon(Icons.settings), text: 'Settings'),
          Tab(icon: Icon(Icons.info_outline), text: 'About'),
        ],
      ),
    ),
    body: const TabBarView(children: [/* screens */]),
  ),
)
```

**Settings screen sections:**
- General: Output folder (with FilePicker)
- Appearance: Theme (SegmentedButton)
- Updates: Auto-update toggle, frequency dropdown
- License: Status, activation button
- Advanced: Clear cache, reset settings

**About screen elements:**
- App logo (Icon in styled container)
- Version from version.dart
- Description
- Links (url_launcher): Website, GitHub, Issues
- Credits: Color-coded chips for engines/libraries
- License info and copyright

### DMG Build Pipeline

**scripts/build_dmg.sh:**
```bash
#!/bin/bash
set -e

VERSION=$(python3 -c "exec(open('backend/version.py').read()); print(VERSION)")

# Build Flutter release
flutter build macos --release

# Create DMG
if command -v create-dmg &> /dev/null; then
    create-dmg --volname "AppName" --app-drop-link 450 185 \
        "AppName-$VERSION.dmg" "build/AppName.app"
else
    hdiutil create -volname "AppName" -srcfolder "build/AppName.app" \
        -ov -format UDZO "AppName-$VERSION.dmg"
fi

# Generate SHA256
shasum -a 256 "AppName-$VERSION.dmg" > "AppName-$VERSION.dmg.sha256"
```

### Website Pricing Section

Standard pricing layout for trial + one-time purchase:

```html
<section id="pricing">
  <div class="pricing-grid">
    <!-- Free Trial Card -->
    <div class="pricing-card">
      <h3>Free Trial</h3>
      <p>7 Days Full Access</p>
      <div class="price">$0</div>
      <ul class="features">
        <li>All features</li>
        <li>No credit card required</li>
      </ul>
      <a href="#download" class="cta-secondary">Start Free Trial</a>
    </div>

    <!-- Pro License Card (highlighted) -->
    <div class="pricing-card highlighted">
      <span class="badge">BEST VALUE</span>
      <h3>Pro License</h3>
      <p>One-time purchase</p>
      <div class="price">$39.99</div>
      <p class="subtitle">Lifetime access</p>
      <ul class="features">
        <li>Everything in Trial</li>
        <li>Lifetime updates</li>
        <li>Priority support</li>
        <li>Commercial use</li>
      </ul>
      <a href="https://polar.sh/..." class="cta-primary">Buy Now</a>
    </div>
  </div>
</section>
```

### Model Management UI

**Models screen features:**
- Show download status (Ready/Downloading/Not downloaded)
- Show model size in GB
- Show source URL (HuggingFace repo) - clickable link
- Download button for undownloaded models
- Delete button for downloaded models (with confirmation dialog)
- Group by engine with color-coded headers

**Delete model endpoint:**
```python
@app.delete("/api/models/{model_name}")
async def model_delete(model_name: str):
    """Delete a downloaded HuggingFace model."""
    registry = ModelRegistry()
    model = registry.get_model(model_name)
    # ... validation ...
    cache_dir = registry.models_dir / f"models--{model.hf_repo.replace('/', '--')}"
    shutil.rmtree(cache_dir)
    return {"message": f"Model deleted", "freed_gb": model.size_gb}
```

**About screen with clickable credits:**
```dart
static const Map<String, String> _engineUrls = {
  'Kokoro TTS': 'https://github.com/hexgrad/kokoro',
  'Qwen3-TTS': 'https://huggingface.co/Qwen/Qwen3-TTS-12Hz-0.6B-Base',
  'Chatterbox': 'https://huggingface.co/ResembleAI/chatterbox',
  'IndexTTS-2': 'https://huggingface.co/IndexTeam/IndexTTS-v2',
};

// Use ActionChip with onPressed to open URLs
ActionChip(
  onPressed: () => _launchUrl(url),
  avatar: Icon(Icons.open_in_new, size: 16),
  label: Text(label),
  backgroundColor: color,
)
```

### Pregenerated Demo Samples

Display pregenerated audio samples to showcase TTS engines without requiring users to configure voice cloning first.

**Backend endpoint for fetching samples:**
```python
@app.get("/api/pregenerated")
async def get_pregenerated_samples(engine: str | None = None):
    """List pregenerated audio samples, optionally filtered by engine."""
    conn = get_connection()
    cursor = conn.cursor()
    if engine:
        cursor.execute(
            "SELECT * FROM pregenerated_samples WHERE engine = ? ORDER BY created_at DESC",
            (engine,)
        )
    else:
        cursor.execute("SELECT * FROM pregenerated_samples ORDER BY created_at DESC")
    samples = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return {"samples": samples}
```

**Database table:**
```sql
CREATE TABLE IF NOT EXISTS pregenerated_samples (
    id TEXT PRIMARY KEY,
    engine TEXT NOT NULL,
    voice_name TEXT NOT NULL,
    title TEXT NOT NULL,
    text TEXT NOT NULL,
    audio_path TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Flutter API service methods:**
```dart
Future<List<Map<String, dynamic>>> getPregeneratedSamples({String? engine}) async {
  final uri = engine != null
      ? Uri.parse('$baseUrl/api/pregenerated?engine=$engine')
      : Uri.parse('$baseUrl/api/pregenerated');
  final response = await http.get(uri);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return List<Map<String, dynamic>>.from(data['samples']);
  }
  throw Exception('Failed to load pregenerated samples');
}

String getPregeneratedAudioUrl(String audioPath) {
  return '$baseUrl$audioPath';
}
```

**Flutter UI for displaying samples (similar to Kokoro voice samples):**
```dart
Widget _buildDemoSamplesSection() {
  if (_demoSamples.isEmpty) return const SizedBox.shrink();

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.record_voice_over, color: Colors.teal.shade600),
              const SizedBox(width: 8),
              const Text('Demo Samples', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Pregenerated', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._demoSamples.map((sample) {
            final id = sample['id'] as String? ?? '';
            final voiceName = sample['voice_name'] as String? ?? '';
            final text = sample['text'] as String? ?? '';
            final isPlaying = _playingDemoId == id;

            return InkWell(
              onTap: isPlaying ? _stopDemoPlayback : () => _playDemoSample(sample),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPlaying ? Colors.teal.shade50 : null,
                  border: Border.all(color: isPlaying ? Colors.teal : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(voiceName, style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_outline),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}
```

**State management for demo playback:**
```dart
List<Map<String, dynamic>> _demoSamples = [];
bool _isLoadingDemoSamples = false;
String? _playingDemoId;

Future<void> _loadDemoSamples() async {
  setState(() => _isLoadingDemoSamples = true);
  try {
    final samples = await _api.getPregeneratedSamples(engine: 'qwen3');
    if (mounted) setState(() => _demoSamples = samples);
  } catch (e) {
    debugPrint('Failed to load demo samples: $e');
  } finally {
    if (mounted) setState(() => _isLoadingDemoSamples = false);
  }
}

Future<void> _playDemoSample(Map<String, dynamic> sample) async {
  final audioPath = sample['audio_path'] as String?;
  if (audioPath == null) return;

  setState(() => _playingDemoId = sample['id']);
  final playUrl = _api.getPregeneratedAudioUrl(audioPath);
  await _audioPlayer.setUrl(playUrl);
  await _audioPlayer.play();
}
```

### Productization Checklist

- [ ] **Version files**: Centralized version management
- [ ] **LICENSE file**: GPL v3.0 or appropriate license
- [ ] **Settings database**: app_settings, license_info, trial_info tables
- [ ] **Settings API**: GET/PUT endpoints for settings
- [ ] **Settings service**: Flutter service for settings management
- [ ] **Models screen**: Full-page with status, size, source URL, download/delete
- [ ] **Settings screen**: Output folder, theme, updates, license sections
- [ ] **About screen**: Version, links, clickable credits with URLs
- [ ] **8-tab navigation**: Include Models, Settings, About tabs
- [ ] **Version badge**: Show version in app bar
- [ ] **DMG build script**: Automated build with SHA256
- [ ] **Version bump script**: Synchronized version updates
- [ ] **Website pricing**: Trial + Pro license cards
- [ ] **Polar.sh integration**: License management webhook
- [ ] **Delete model API**: Endpoint to remove downloaded models
- [ ] **Demo samples**: Pregenerated audio samples for TTS engine showcase

## Common Mistakes

1. **Not checking `mounted` before setState** - Always guard async callbacks
2. **Using deprecated `withOpacity`** - Use `withValues(alpha:)` instead
3. **Missing CORS middleware** - Flutter web needs CORS enabled
4. **No health endpoint** - Always provide `/api/health` for connectivity checks
5. **Blocking startup** - Use lifespan pattern, not `@app.on_event`
6. **No venv detection** - Check both root and backend for venv location
7. **Missing runtime logs in issues.sh** - Always include Flutter/backend/MCP logs
8. **No integration tests** - Provide `scripts/test_api.py` for quick validation
9. **Hardcoded ports** - Define ports as constants at top of control script
10. **Missing MCP server management** - Include start/stop/status for MCP
11. **Storing license keys unhashed** - Always hash license keys in the database
12. **Trusting device clock for trial** - Use server timestamps, store offset locally
13. **Polar API key in Flutter** - Keep API keys server-side only
14. **No offline grace period** - Allow 3-day grace for licensed users offline
15. **Leaking key existence** - Return generic "Invalid or inactive license" errors
16. **No activation limits** - Enforce max devices per license to prevent sharing
17. **Missing webhook signature verification** - Always verify Polar webhook signatures
