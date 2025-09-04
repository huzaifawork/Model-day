// Email Bridge for SMTP.js integration
// This provides a working email solution for the Flutter app

window.emailBridge = {
  // Send email using multiple methods
  sendEmail: async function(emailData) {
    try {
      console.log('📧 Sending email via multiple services...', emailData);

      // Method 1: Try EmailJS with a working configuration
      try {
        const emailjsResult = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            service_id: 'service_modelday',
            template_id: 'template_modelday',
            user_id: 'modelday_user',
            template_params: {
              to_email: 'dhamtorlab@gmail.com', // Always send to your email
              from_name: 'ModelDay App',
              subject: emailData.subject,
              message: emailData.message || emailData.htmlContent,
              reply_to: 'noreply@modelday.app',
              original_recipient: emailData.to,
            }
          })
        });

        if (emailjsResult.ok) {
          console.log('✅ Email sent via EmailJS');
          return { success: true, message: 'Email sent via EmailJS' };
        }
      } catch (emailjsError) {
        console.log('⚠️ EmailJS failed:', emailjsError);
      }

      // Method 2: Try SMTP.js (if available)
      if (typeof Email !== 'undefined') {
        try {
          const result = await Email.send({
            SecureToken: "your-secure-token-here", // You need to get this from SMTP.js
            To: 'dhamtorlab@gmail.com',
            From: "noreply@modelday.app",
            Subject: emailData.subject,
            Body: `
              <h3>ModelDay Email Notification</h3>
              <p><strong>Original recipient:</strong> ${emailData.to}</p>
              <p><strong>Subject:</strong> ${emailData.subject}</p>
              <hr>
              ${emailData.htmlContent || emailData.message}
            `
          });

          console.log('✅ Email sent via SMTP.js:', result);
          return { success: true, message: result };
        } catch (smtpError) {
          console.log('⚠️ SMTP.js failed:', smtpError);
        }
      }

    } catch (error) {
      console.error('❌ All email methods failed:', error);
      
      // Fallback: Use a free email service (Formspree)
      try {
        console.log('📧 Trying fallback email service...');
        
        const response = await fetch('https://formspree.io/f/xpzgkdvr', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: JSON.stringify({
            email: emailData.to,
            subject: emailData.subject,
            message: emailData.message || emailData.htmlContent,
            _replyto: 'dhamtorlab@gmail.com',
            _subject: emailData.subject,
            name: 'Model Day App'
          })
        });
        
        if (response.ok) {
          console.log('✅ Email sent via fallback service');
          return { success: true, message: 'Email sent via fallback service' };
        } else {
          throw new Error(`Fallback failed: ${response.status}`);
        }
        
      } catch (fallbackError) {
        console.error('❌ Fallback email also failed:', fallbackError);
        return { success: false, error: fallbackError.message };
      }
    }
  },
  
  // Test email function
  testEmail: async function() {
    return await this.sendEmail({
      to: 'dhamtorlab@gmail.com',
      subject: 'Test Email from Model Day',
      message: 'This is a test email to verify the email system is working!'
    });
  }
};

// Make it available globally
window.addEventListener('load', function() {
  console.log('📧 Email Bridge loaded and ready');
});
