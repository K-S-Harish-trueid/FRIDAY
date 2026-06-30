const String groqApiKey = 'YOUR_GROQ_API_KEY';       // <-- paste your Groq key here
const String geminiApiKey = 'YOUR_GEMINI_API_KEY';   // <-- paste your Gemini key here
const String defaultProvider = 'groq';

const String groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';
const String groqModel = 'llama-3.3-70b-versatile';
const String geminiBaseUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

// Own FastAPI backend — change host/port to match your server
const String ownApiUrl = 'http://127.0.0.1:8000/api/chat'; // 10.0.2.2 = Android emulator → localhost
