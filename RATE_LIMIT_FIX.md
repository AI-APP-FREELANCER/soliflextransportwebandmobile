# Rate Limiting and JSON Parsing Error Fix

## Problem Summary

The application was experiencing two critical issues:

1. **HTTP 429 (Too Many Requests) Errors**: Rate limiting was too strict, causing legitimate parallel requests to be blocked
2. **JSON Parsing Errors**: When rate limiting triggered, the backend returned plain text error messages instead of JSON, causing `FormatException: SyntaxError: Unexpected token 'T'` errors in the frontend

## Root Causes

1. **Backend Rate Limiter Configuration**:
   - General API limit: 100 requests per 15 minutes (too low for parallel requests)
   - Auth limit: 5 attempts per 15 minutes (too restrictive)
   - Rate limiter returned plain text messages instead of JSON

2. **Frontend Error Handling**:
   - All API methods tried to parse responses as JSON without checking status codes first
   - No handling for 429 errors specifically
   - No graceful fallback when response wasn't valid JSON

## Fixes Implemented

### Backend Changes (`backend/server.js`)

1. **Increased Rate Limits**:
   - General API: Increased from 100 to **500 requests per 15 minutes**
   - Auth endpoints: Increased from 5 to **10 attempts per 15 minutes**

2. **Fixed Rate Limiter Response Format**:
   - Added custom `handler` function to return JSON responses
   - Changed `message` from plain string to JSON object
   - Ensures all rate limit responses are valid JSON

```javascript
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 500, // Increased from 100
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message: 'Too many requests from this IP, please try again later.'
    });
  },
});
```

### Frontend Changes (`lib/services/api_service.dart`)

1. **Created `_parseResponse()` Helper Method**:
   - Checks for 429 status code and handles it gracefully
   - Validates response status codes before parsing JSON
   - Provides user-friendly error messages
   - Handles non-JSON responses safely

2. **Updated All API Methods**:
   - Replaced all `jsonDecode(response.body)` calls with `_parseResponse(response)`
   - Removed manual status code checks (now handled by helper)
   - Consistent error handling across all endpoints

## Benefits

1. **Better User Experience**:
   - Clear, user-friendly error messages instead of technical JSON parsing errors
   - Proper handling of rate limit scenarios

2. **Improved Reliability**:
   - No more crashes from invalid JSON parsing
   - Graceful degradation when backend returns unexpected formats

3. **Higher Throughput**:
   - Increased rate limits allow for normal parallel request patterns
   - Still maintains security against abuse

## Testing Checklist

- [x] Login with valid credentials works
- [x] Multiple parallel requests don't trigger false rate limits
- [x] Rate limit errors show user-friendly messages
- [x] JSON parsing errors are eliminated
- [x] All API endpoints handle errors gracefully

## Deployment Notes

After deploying these changes:

1. **Backend**: Restart PM2 process
   ```bash
   pm2 restart soliflex-backend
   pm2 save
   ```

2. **Frontend**: Rebuild and restart
   ```bash
   flutter clean
   flutter build web --release
   pm2 restart soliflex-frontend
   pm2 save
   ```

## Monitoring

Watch for:
- Rate limit errors in production (should be rare now)
- Any remaining JSON parsing errors (should be eliminated)
- User reports of "Too many requests" errors (should be minimal)

