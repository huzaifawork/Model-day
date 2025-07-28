// Vercel serverless function for OpenAI chat
const { OpenAI } = require('openai');

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

module.exports = async (req, res) => {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

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
};
