const express = require('express');
const cors = require('cors');
require('dotenv').config();
const { OpenAI } = require('openai');

const app = express();
app.use(cors());
app.use(express.json());

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

app.post('/api/openai/chat', async (req, res) => {
  const { messages } = req.body; // messages: [{role: 'system', content: '...'}, {role: 'user', content: '...'}]
  try {
    console.log('🤖 Received chat request with', messages.length, 'messages');

    const completion = await openai.chat.completions.create({
      model: 'gpt-3.5-turbo',
      messages,
      max_tokens: 500,
      temperature: 0.7,
    });

    const response = completion.choices[0].message.content;
    console.log('✅ OpenAI response generated successfully');

    res.json({ response });
  } catch (err) {
    console.error('❌ OpenAI API error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`)); 