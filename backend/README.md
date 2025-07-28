# Model Day Backend (OpenAI Proxy)

This backend securely proxies OpenAI API requests for the Model Day Flutter app.

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```
2. Create a `.env` file in this folder:
   ```env
   OPENAI_API_KEY=your-openai-api-key-here
   ```
3. Start the server:
   ```bash
   npm start
   ```

## API Endpoint

- `POST /api/openai/chat`
  - Request body:
    ```json
    {
      "messages": [{ "role": "user", "content": "Hello!" }]
    }
    ```
  - Response:
    ```json
    {
      "response": "AI reply here."
    }
    ```

## Deployment

- Deploy to any Node.js host (Vercel, Render, Heroku, etc.)
- Keep your `.env` secret and never expose your OpenAI key to the frontend.
