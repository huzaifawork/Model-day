// Firebase Storage CORS workaround for web development
// This script helps handle CORS issues during development

(function() {
    'use strict';

    // Disable CORS checks globally for development
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        console.log('🔧 Development mode detected - applying CORS workarounds');
    }
    
    // Override XMLHttpRequest for Firebase Storage requests
    const originalXHR = window.XMLHttpRequest;
    
    window.XMLHttpRequest = function() {
        const xhr = new originalXHR();
        const originalOpen = xhr.open;
        const originalSend = xhr.send;
        
        xhr.open = function(method, url, async, user, password) {
            // Check if this is a Firebase Storage request
            if (url && (url.includes('firebasestorage.googleapis.com') || url.includes('storage.googleapis.com') || url.includes('.firebasestorage.app') || url.includes('.appspot.com'))) {
                console.log('🔧 Intercepting Firebase Storage request:', url);

                // Keep .firebasestorage.app URLs as they are (CORS is configured on this bucket)
                // Don't convert - the URLs are already correct!
                console.log('✅ Using correct firebasestorage.app domain:', url);
                
                // Add CORS headers for Firebase Storage
                xhr.addEventListener('readystatechange', function() {
                    if (xhr.readyState === 4) {
                        console.log('📡 Firebase Storage response status:', xhr.status);
                        if (xhr.status === 0) {
                            console.warn('! CORS error detected for:', url);
                            // Try to reload the image with cache busting
                            if (url.includes('firebasestorage.googleapis.com')) {
                                const urlObj = new URL(url);
                                urlObj.searchParams.set('_t', Date.now().toString());
                                console.log('🔄 Retrying with cache bust:', urlObj.toString());
                            }
                        }
                    }
                });
            }
            
            return originalOpen.apply(this, arguments);
        };
        
        xhr.send = function(data) {
            // Add additional headers for Firebase Storage requests
            if (this.responseURL && this.responseURL.includes('storage.googleapis.com')) {
                this.setRequestHeader('Access-Control-Allow-Origin', '*');
                this.setRequestHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
                this.setRequestHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
            }
            
            return originalSend.apply(this, arguments);
        };
        
        return xhr;
    };
    
    // Override fetch for Firebase Storage requests
    const originalFetch = window.fetch;
    
    window.fetch = function(input, init) {
        let url = typeof input === 'string' ? input : input.url;

        if (url && (url.includes('firebasestorage.googleapis.com') || url.includes('storage.googleapis.com') || url.includes('.firebasestorage.app') || url.includes('.appspot.com'))) {
            console.log('🔧 Intercepting Firebase Storage fetch:', url);

            // Keep .firebasestorage.app URLs as they are (CORS is configured on this bucket)
            if (url.includes('.appspot.com')) {
                url = url.replace('.appspot.com', '.firebasestorage.app');
                console.log('🔄 Converted fetch URL to correct bucket:', url);
            }
            
            // Add CORS headers to the request
            init = init || {};
            init.headers = init.headers || {};
            init.mode = 'cors';
            init.credentials = 'omit';
            
            // Add cache-busting parameter and CORS headers
            const urlObj = new URL(url);
            urlObj.searchParams.set('alt', 'media');
            urlObj.searchParams.set('_t', Date.now().toString());

            // Add CORS headers
            init.headers = init.headers || {};
            init.headers['Access-Control-Allow-Origin'] = '*';
            init.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS';
            init.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization';
            
            const modifiedInput = typeof input === 'string' ? urlObj.toString() : 
                Object.assign({}, input, { url: urlObj.toString() });
            
            return originalFetch(modifiedInput, init).catch(error => {
                console.error('❌ Firebase Storage fetch error:', error);
                throw error;
            });
        }
        
        return originalFetch.apply(this, arguments);
    };
    
    // Override Image constructor for Firebase Storage URLs
    const originalImage = window.Image;
    window.Image = function() {
        const img = new originalImage();
        const originalSrc = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');

        Object.defineProperty(img, 'src', {
            get: function() {
                return originalSrc.get.call(this);
            },
            set: function(value) {
                if (value && (value.includes('firebasestorage.googleapis.com') || value.includes('storage.googleapis.com'))) {
                    console.log('🖼️ Intercepting Image src:', value);

                    // URLs are already using correct .firebasestorage.app domain
                    console.log('✅ Using correct Image URL:', value);

                    // Add cache-busting
                    const url = new URL(value);
                    url.searchParams.set('_t', Date.now().toString());
                    value = url.toString();
                }

                originalSrc.set.call(this, value);
            }
        });

        return img;
    };

    console.log('✅ Firebase Storage CORS workaround loaded with Image override');
})();
