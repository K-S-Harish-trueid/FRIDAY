// F.R.I.D.A.Y talks to exactly one place: our own FastAPI backend.
// No LLM provider keys live on the client — Groq/Gemini calls happen
// server-side only. See backend/.env / Render environment variables.
const String defaultProvider = 'own';

const String backendBaseUrl = 'https://friday-backend-t7xa.onrender.com';

// shared_preferences key for the persisted provider choice — read by both
// ChatNotifier and the "/preference" slash command.
const String providerPrefsKey = 'active_provider';
