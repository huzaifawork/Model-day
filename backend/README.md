# ModelDay Email Service Setup

This backend service enables real email sending for the ModelDay Flutter app, similar to your Blazor MAUI implementation.

## 🚀 Quick Setup (Python - Recommended)

### 1. Install Python Dependencies
```bash
cd backend
pip install -r requirements.txt
```

### 2. Configure Gmail Settings

#### Enable 2-Factor Authentication
1. Go to [Google Account Settings](https://myaccount.google.com/)
2. Security → 2-Step Verification → Turn On

#### Generate App Password
1. Go to [App Passwords](https://myaccount.google.com/apppasswords)
2. Select "Mail" and "Other (Custom name)"
3. Enter "ModelDay Email Service"
4. Copy the generated 16-character password

#### Update Configuration
Edit `simple_email_server.py` line 18-19:
```python
'sender_email': 'your-email@gmail.com',  # Your Gmail address
'sender_password': 'your-16-char-app-password',  # Gmail App Password
```

### 3. Run the Service
```bash
python simple_email_server.py
```

The service will start at `http://localhost:5000`

### 4. Test the Service
```bash
curl http://localhost:5000/test
```

## 🔧 Alternative Setup (Node.js)

### 1. Install Node.js Dependencies
```bash
cd backend
npm install
```

### 2. Configure Email Settings
Edit `email_service.js` line 8-11:
```javascript
auth: {
  user: 'your-email@gmail.com', // Your Gmail address
  pass: 'your-16-char-app-password' // Gmail App Password
}
```

### 3. Run the Service
```bash
npm start
# or for development:
npm run dev
```

## 📧 How It Works

1. **Flutter App** → Sends comment notification request
2. **Backend Service** → Receives request and sends actual email via SMTP
3. **Gmail SMTP** → Delivers email to post author
4. **Post Author** → Receives beautiful HTML email notification

## 🧪 Testing the Email System

### 1. Start the Backend Service
```bash
python simple_email_server.py
```

### 2. Run Your Flutter App
```bash
flutter run -d chrome
```

### 3. Test Comment Notification
1. Go to Community Board
2. Add a comment to any post
3. Check console logs for email sending process
4. Check the recipient's email inbox

## 📱 Email Template Features

The email includes:
- ✅ Beautiful HTML design (similar to your Blazor template)
- ✅ Post title and commenter name
- ✅ Full comment content
- ✅ Direct link to view the post
- ✅ Professional ModelDay branding
- ✅ Mobile-responsive design

## 🚀 Production Deployment

### Option 1: Vercel (Node.js)
1. Push code to GitHub
2. Connect to Vercel
3. Deploy as serverless function
4. Update `_emailServiceUrl` in Flutter app

### Option 2: Heroku (Python)
1. Create Heroku app
2. Push code to Heroku
3. Set environment variables
4. Update `_emailServiceUrl` in Flutter app

### Option 3: Railway/Render
1. Connect GitHub repository
2. Deploy with one click
3. Update `_emailServiceUrl` in Flutter app

## 🔒 Security Notes

- ✅ Never commit email passwords to Git
- ✅ Use environment variables in production
- ✅ Enable CORS only for your domain in production
- ✅ Use HTTPS in production

## 🐛 Troubleshooting

### "Authentication failed"
- Check 2FA is enabled
- Verify App Password is correct
- Ensure email address is correct

### "Connection refused"
- Check if service is running on correct port
- Verify firewall settings
- Check CORS configuration

### "Email not received"
- Check spam folder
- Verify recipient email address
- Check Gmail sending limits

## 📊 Console Output

When working correctly, you'll see:
```
📧 Sending email notification...
📧 To: user@example.com
📧 Post: "Sample Post"
📧 Commenter: John Doe
🌐 Connecting to smtp.gmail.com:587...
✅ Connected to SMTP server
🔐 Authenticating with your-email@gmail.com...
✅ Authentication successful
📧 Email sent successfully to user@example.com
```

## 🎯 Next Steps

1. Set up the backend service
2. Configure your Gmail credentials
3. Test the email system
4. Deploy to production
5. Update Flutter app with production URL

Your email notification system will then work exactly like your Blazor MAUI implementation! 🎉
