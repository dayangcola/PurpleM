# Archived Chat Endpoints

This folder keeps the previous serverless implementations for reference only.
They are no longer deployed by default—`api/chat-stream-enhanced.js` is the
primary chat handler, while `api/chat-auto.js` reuses the same core logic for
non-streaming fallback.

Files archived here:
- `chat-stream.js`
- `chat-stream-v2.js`
- `chat.js`
- `chat-simple.js`
- `chat-with-personality.js`

Keep them for historical context or migration reference; new work should extend
`chat-stream-enhanced.js` or the shared helpers in `api/_shared/enhancedChatCore.js`.
