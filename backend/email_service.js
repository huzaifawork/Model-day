// Simple Node.js email service for ModelDay
// This can be deployed to Vercel, Netlify Functions, or any cloud provider

const nodemailer = require('nodemailer');

// Email configuration (similar to your Blazor example)
const EMAIL_CONFIG = {
  host: 'smtp.gmail.com',
  port: 587,
  secure: false, // true for 465, false for other ports
  auth: {
    user: 'dhamtorlab@gmail.com', // Your Gmail address
    pass: 'your-app-password-here' // Gmail App Password
  }
};

// Create transporter
const transporter = nodemailer.createTransporter(EMAIL_CONFIG);

// Verify connection configuration
transporter.verify(function(error, success) {
  if (error) {
    console.log('❌ Email service configuration error:', error);
  } else {
    console.log('✅ Email service ready to send messages');
  }
});

// Main email sending function
async function sendCommentNotification(req, res) {
  // Set CORS headers
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

  try {
    const {
      postAuthorEmail,
      postTitle,
      commenterName,
      commentContent,
      postId
    } = req.body;

    console.log('📧 Sending email notification...');
    console.log('📧 To:', postAuthorEmail);
    console.log('📧 Post:', postTitle);
    console.log('📧 Commenter:', commenterName);

    // Create email content (similar to your Blazor HTML template)
    const htmlContent = `
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #007bff; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { padding: 20px; background-color: #f8f9fa; border-radius: 0 0 8px 8px; }
        .comment-box { background-color: #e3f2fd; border-left: 4px solid #2196f3; padding: 15px; margin: 15px 0; }
        .footer { padding: 15px; text-align: center; font-size: 12px; color: #666; }
        .btn { background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 10px 0; }
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h2>🔔 New Comment Notification</h2>
            <h3>ModelDay Community Board</h3>
        </div>
        <div class='content'>
            <p>Hello!</p>
            <p>Someone has commented on your post in the ModelDay Community Board.</p>
            
            <div class='comment-box'>
                <strong>📝 Post:</strong> "${postTitle}"<br>
                <strong>👤 Commenter:</strong> ${commenterName}<br>
                <strong>💬 Comment:</strong><br>
                <em>"${commentContent}"</em><br>
                <strong>🕒 Time:</strong> ${new Date().toLocaleString()}
            </div>
            
            <p>
                <a href="https://modelday.app/community-board?post=${postId}" class="btn">
                    🔗 View Post & Reply
                </a>
            </p>
            
            <p>Stay connected with your community!</p>
            
            <p>Best regards,<br>
            <strong>ModelDay Team</strong></p>
        </div>
        <div class='footer'>
            This is an automated notification from ModelDay Community Board.<br>
            You received this because someone commented on your post.
        </div>
    </div>
</body>
</html>`;

    // Email options
    const mailOptions = {
      from: {
        name: 'ModelDay Community',
        address: EMAIL_CONFIG.auth.user
      },
      to: postAuthorEmail,
      subject: `🔔 New Comment on Your Post: "${postTitle}"`,
      html: htmlContent,
      text: `
Hello!

Someone has commented on your post in the ModelDay Community Board.

Post: "${postTitle}"
Commenter: ${commenterName}
Comment: "${commentContent}"

View Post: https://modelday.app/community-board?post=${postId}

Best regards,
ModelDay Team
      `
    };

    // Send email
    const info = await transporter.sendMail(mailOptions);
    
    console.log('✅ Email sent successfully:', info.messageId);
    
    res.status(200).json({
      success: true,
      messageId: info.messageId,
      message: 'Email sent successfully'
    });

  } catch (error) {
    console.error('❌ Error sending email:', error);
    
    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to send email'
    });
  }
}

// Send event notification to model
async function sendEventNotification(req, res) {
  try {
    console.log('📧 Received event notification request');

    const {
      modelEmail,
      agentEmail,
      agentName,
      eventType,
      clientName,
      eventDate,
      location,
      dayRate,
      currency,
      notes
    } = req.body;

    // Validate required fields
    if (!modelEmail || !agentEmail || !agentName || !eventType || !clientName) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields'
      });
    }

    console.log(`📧 Sending event notification to: ${modelEmail}`);
    console.log(`📧 From agent: ${agentName} (${agentEmail})`);
    console.log(`📧 Event: ${eventType} for ${clientName}`);

    // Create HTML email content
    const htmlContent = `<!DOCTYPE html>
<html>
<head>
    <style>
        .container { max-width: 600px; margin: 0 auto; font-family: Arial, sans-serif; }
        .header { background: linear-gradient(135deg, #D4AF37, #B8976C); padding: 20px; text-align: center; }
        .content { background: #f9f9f9; padding: 30px; }
        .event-details { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .btn { background: #D4AF37; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; }
        .footer { background: #333; color: white; padding: 15px; text-align: center; font-size: 12px; }
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1 style='color: white; margin: 0;'>🎬 New Event Setup</h1>
        </div>
        <div class='content'>
            <h2>Hello!</h2>

            <p>Your agent <strong>${agentName}</strong> has set up a new event for you:</p>

            <div class='event-details'>
                <h3>📋 Event Details</h3>
                <p><strong>🎬 Event Type:</strong> ${eventType}</p>
                <p><strong>🏢 Client:</strong> ${clientName}</p>
                <p><strong>📅 Date:</strong> ${eventDate}</p>
                <p><strong>📍 Location:</strong> ${location || 'TBC'}</p>
                <p><strong>💰 Day Rate:</strong> ${dayRate} ${currency}</p>
                ${notes ? `<p><strong>📝 Notes:</strong> ${notes}</p>` : ''}
                <p><strong>👤 Agent:</strong> ${agentName} (${agentEmail})</p>
            </div>

            <p>
                <a href="https://modelday.app/" class="btn">
                    🔗 View in ModelDay
                </a>
            </p>

            <p>Please log in to your ModelDay account to view full details and manage this event.</p>

            <p>Best regards,<br>
            <strong>ModelDay Team</strong></p>
        </div>
        <div class='footer'>
            This is an automated notification from ModelDay Event Management.<br>
            You received this because your agent set up a new event for you.
        </div>
    </div>
</body>
</html>`;

    // Email options
    const mailOptions = {
      from: {
        name: 'ModelDay Events',
        address: EMAIL_CONFIG.auth.user
      },
      to: modelEmail,
      subject: `🎬 New Event Setup: ${eventType} for ${clientName}`,
      html: htmlContent,
      text: `
Hello!

Your agent ${agentName} (${agentEmail}) has set up a new event for you:

🎬 Event Type: ${eventType}
🏢 Client: ${clientName}
📅 Date: ${eventDate}
📍 Location: ${location || 'TBC'}
💰 Day Rate: ${dayRate} ${currency}
${notes ? `📝 Notes: ${notes}` : ''}

View in ModelDay: https://modelday.app/

Please log in to your ModelDay account to view full details and manage this event.

Best regards,
ModelDay Team
      `
    };

    // Send email
    const info = await transporter.sendMail(mailOptions);

    console.log('✅ Event notification email sent successfully:', info.messageId);

    res.status(200).json({
      success: true,
      messageId: info.messageId,
      message: 'Event notification email sent successfully'
    });

  } catch (error) {
    console.error('❌ Error sending event notification email:', error);

    res.status(500).json({
      success: false,
      error: error.message,
      message: 'Failed to send event notification email'
    });
  }
}

// Export for serverless deployment
module.exports = { sendCommentNotification, sendEventNotification };

// For local testing
if (require.main === module) {
  const express = require('express');
  const cors = require('cors');
  const app = express();

  // Enable CORS for all routes
  app.use(cors());
  app.use(express.json());

  // Routes
  app.post('/send-comment-notification', sendCommentNotification);
  app.post('/send-event-notification', sendEventNotification);
  app.post('/send-email', sendCommentNotification); // Legacy endpoint

  // Health check
  app.get('/health', (req, res) => {
    res.status(200).json({
      status: 'healthy',
      message: 'ModelDay Email Service is running',
      timestamp: new Date().toISOString()
    });
  });

  const PORT = process.env.PORT || 3001;
  app.listen(PORT, () => {
    console.log(`🚀 ModelDay Email Service running on port ${PORT}`);
    console.log(`📧 Health check: http://localhost:${PORT}/health`);
    console.log(`📧 Comment notifications: http://localhost:${PORT}/send-comment-notification`);
    console.log(`📧 Event notifications: http://localhost:${PORT}/send-event-notification`);
  });
}
