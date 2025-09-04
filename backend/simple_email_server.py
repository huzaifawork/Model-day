#!/usr/bin/env python3
"""
Simple Python email server for ModelDay
This is a lightweight alternative to the Node.js service
"""

import smtplib
import json
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime
import os

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Email configuration (similar to your Blazor example)
EMAIL_CONFIG = {
    'smtp_server': 'smtp.gmail.com',
    'smtp_port': 587,
    'sender_email': 'dhamtorlab@gmail.com',  # Your Gmail address
    'sender_password': 'your-app-password-here',  # Gmail App Password
    'sender_name': 'ModelDay Community'
}

def create_html_email(post_title, commenter_name, comment_content, post_id, post_author_email):
    """Create HTML email content similar to your Blazor template"""
    
    html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #007bff; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ padding: 20px; background-color: #f8f9fa; border-radius: 0 0 8px 8px; }}
        .comment-box {{ background-color: #e3f2fd; border-left: 4px solid #2196f3; padding: 15px; margin: 15px 0; }}
        .footer {{ padding: 15px; text-align: center; font-size: 12px; color: #666; }}
        .btn {{ background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 10px 0; }}
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
                <strong>📝 Post:</strong> "{post_title}"<br>
                <strong>👤 Commenter:</strong> {commenter_name}<br>
                <strong>💬 Comment:</strong><br>
                <em>"{comment_content}"</em><br>
                <strong>🕒 Time:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
            </div>
            
            <p>
                <a href="https://modelday.app/community-board?post={post_id}" class="btn">
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
</html>"""
    
    return html_content

def send_email_smtp(to_email, subject, html_content, text_content):
    """Send email using SMTP (similar to your Blazor implementation)"""
    
    try:
        print(f"🔧 Attempting to send email to: {to_email}")
        print(f"📧 Using email: {EMAIL_CONFIG['sender_email']}")
        
        # Create message
        msg = MIMEMultipart('alternative')
        msg['From'] = f"{EMAIL_CONFIG['sender_name']} <{EMAIL_CONFIG['sender_email']}>"
        msg['To'] = to_email
        msg['Subject'] = subject
        
        # Add both plain text and HTML versions
        text_part = MIMEText(text_content, 'plain')
        html_part = MIMEText(html_content, 'html')
        
        msg.attach(text_part)
        msg.attach(html_part)
        
        # Connect to server and send email
        print(f"🌐 Connecting to {EMAIL_CONFIG['smtp_server']}:{EMAIL_CONFIG['smtp_port']}...")
        
        server = smtplib.SMTP(EMAIL_CONFIG['smtp_server'], EMAIL_CONFIG['smtp_port'])
        server.starttls()  # Enable encryption
        
        print("✅ Connected to SMTP server")
        print(f"🔐 Authenticating with {EMAIL_CONFIG['sender_email']}...")
        
        server.login(EMAIL_CONFIG['sender_email'], EMAIL_CONFIG['sender_password'])
        
        print("✅ Authentication successful")
        
        # Send email
        server.send_message(msg)
        server.quit()
        
        print(f"📧 Email sent successfully to {to_email}")
        return True
        
    except smtplib.SMTPAuthenticationError as e:
        print(f"❌ Authentication failed: {e}")
        print("🔍 Check these Gmail settings:")
        print("   1. 2-Factor Authentication is enabled")
        print("   2. App Password is correctly generated")
        print("   3. Email address is correct")
        return False
        
    except Exception as e:
        print(f"❌ Error sending email: {e}")
        return False

@app.route('/send-email', methods=['POST', 'OPTIONS'])
def send_comment_notification():
    """API endpoint to send comment notifications"""
    
    # Handle preflight requests
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.get_json()
        
        post_author_email = data.get('postAuthorEmail')
        post_title = data.get('postTitle')
        commenter_name = data.get('commenterName')
        comment_content = data.get('commentContent')
        post_id = data.get('postId')
        
        print('📧 Sending email notification...')
        print(f'📧 To: {post_author_email}')
        print(f'📧 Post: {post_title}')
        print(f'📧 Commenter: {commenter_name}')
        
        # Create email content
        html_content = create_html_email(
            post_title, commenter_name, comment_content, post_id, post_author_email
        )
        
        text_content = f"""
Hello!

Someone has commented on your post in the ModelDay Community Board.

Post: "{post_title}"
Commenter: {commenter_name}
Comment: "{comment_content}"

View Post: https://modelday.app/community-board?post={post_id}

Best regards,
ModelDay Team
        """
        
        subject = f'🔔 New Comment on Your Post: "{post_title}"'
        
        # Send email
        success = send_email_smtp(post_author_email, subject, html_content, text_content)
        
        if success:
            return jsonify({
                'success': True,
                'message': 'Email sent successfully'
            }), 200
        else:
            return jsonify({
                'success': False,
                'message': 'Failed to send email'
            }), 500
            
    except Exception as e:
        print(f"❌ Error in send_comment_notification: {e}")
        return jsonify({
            'success': False,
            'error': str(e),
            'message': 'Failed to send email'
        }), 500

@app.route('/test', methods=['GET'])
def test_service():
    """Test endpoint to verify the service is running"""
    return jsonify({
        'status': 'running',
        'message': 'ModelDay Email Service is operational',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    print("📧 Starting ModelDay Email Service...")
    print("🔧 Make sure to update EMAIL_CONFIG with your Gmail credentials")
    print("🌐 Service will be available at: http://localhost:5000")
    
    # Run the Flask app
    app.run(host='0.0.0.0', port=5000, debug=True)
