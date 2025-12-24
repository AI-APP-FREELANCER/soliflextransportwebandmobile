# Nginx Configuration Guide for Soliflex Application

## Architecture Overview

- **Nginx**: Receives traffic on port 80 (HTTP) → redirects to 443 (HTTPS)
- **Backend API**: Running on `localhost:5000` (Node.js/Express)
- **Frontend**: Running on `localhost:8081` (Flutter Web via http-server)

## Complete API Routes List

All backend routes are prefixed with `/api` and run on port 5000.

### Authentication Routes (`/api/*`)
- `POST /api/register` - User registration
- `POST /api/login` - User login
- `GET /api/departments` - Get all departments
- `GET /api/user/:userId` - Get user details

### Order Routes (`/api/*`)
- `GET /api/orders` - Get all orders
- `GET /api/orders/user/:userId` - Get user's orders
- `GET /api/orders/:orderId` - Get single order details
- `POST /api/create-order` - Create new order
- `POST /api/update-order-status` - Update order status
- `POST /api/calculate-invoice-rate` - Calculate invoice rate
- `POST /api/amend-order` - Amend existing order
- `POST /api/initialize-workflow` - Initialize workflow for order
- `POST /api/workflow-action` - Perform workflow action (approve/reject/revoke/cancel)
- `POST /api/fix-completed-orders` - Retroactive fix for completed orders

### RFQ Routes (`/api/*`)
- `GET /api/vendors` - Get all vendors
- `GET /api/vehicles` - Get all vehicles
- `POST /api/rfq/match-vehicles` - Match vehicles for material weight
- `POST /api/rfq/create` - Create RFQ
- `GET /api/rfq/user/:userId` - Get user's RFQs
- `GET /api/rfq/:rfqId` - Get single RFQ details
- `GET /api/rfq/pending` - Get pending RFQs
- `POST /api/rfq/:rfqId/approve` - Approve RFQ
- `POST /api/rfq/:rfqId/reject` - Reject RFQ
- `POST /api/rfq/:rfqId/start` - Start RFQ
- `POST /api/rfq/:rfqId/complete` - Complete RFQ

### Admin Routes (`/api/admin/*`)
- `GET /api/admin/users` - Get all users
- `POST /api/admin/users` - Create new user
- `PUT /api/admin/users/:userId` - Update user
- `DELETE /api/admin/users/:userId` - Delete user
- `GET /api/admin/vendors` - Get all vendors
- `POST /api/admin/vendors` - Create new vendor
- `PUT /api/admin/vendors/:vendorName` - Update vendor
- `DELETE /api/admin/vendors/:vendorName` - Delete vendor
- `GET /api/admin/vehicles` - Get all vehicles
- `POST /api/admin/vehicles` - Create new vehicle
- `PUT /api/admin/vehicles/:vehicleId` - Update vehicle
- `DELETE /api/admin/vehicles/:vehicleId` - Delete vehicle

### Notification Routes (`/api/notifications/*`)
- `GET /api/notifications/department/:department` - Get notifications by department
- `GET /api/notifications/user/:userId` - Get notifications by user
- `POST /api/notifications/:notificationId/read` - Mark notification as read
- `GET /api/notifications/unread-count/:department` - Get unread count

### Health Check
- `GET /health` - Backend health check (no `/api` prefix)

## Recommended Nginx Configuration

```nginx
server {
    listen 80;
    server_name your-domain.com;  # Replace with your domain or IP
    
    # Redirect all HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;  # Replace with your domain or IP
    
    # SSL Configuration (adjust paths to your certificates)
    ssl_certificate /path/to/your/certificate.crt;
    ssl_certificate_key /path/to/your/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Increase body size for file uploads (if needed)
    client_max_body_size 10M;
    
    # Proxy settings
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_cache_bypass $http_upgrade;
    
    # Backend API - All /api/* routes go to backend (port 5000)
    location /api/ {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS headers (if needed)
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;
        
        # Handle preflight requests
        if ($request_method = OPTIONS) {
            return 204;
        }
    }
    
    # Health check endpoint (no /api prefix)
    location /health {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Frontend - All other routes go to Flutter web app (port 8081)
    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support (if needed for Flutter hot reload in dev)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Static assets caching (optional optimization)
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://localhost:8081;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

## Simplified Configuration (If you don't have SSL yet)

```nginx
server {
    listen 80;
    server_name your-domain.com;  # Replace with your domain or IP
    
    client_max_body_size 10M;
    
    # Backend API routes
    location /api/ {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:5000;
    }
    
    # Frontend (all other routes)
    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Testing Your Configuration

After updating nginx config:

1. **Test configuration syntax:**
   ```bash
   sudo nginx -t
   ```

2. **Reload nginx:**
   ```bash
   sudo systemctl reload nginx
   # or
   sudo service nginx reload
   ```

3. **Test endpoints:**
   ```bash
   # Test health check
   curl https://your-domain.com/health
   
   # Test API endpoint
   curl https://your-domain.com/api/departments
   
   # Test frontend
   curl -I https://your-domain.com/
   ```

## Important Notes

1. **All API routes** are under `/api/*` and should proxy to `localhost:5000`
2. **Health check** at `/health` (no `/api` prefix) also goes to backend
3. **All other routes** (frontend) should proxy to `localhost:8081`
4. **CORS** is already handled in the backend, but nginx can add additional headers if needed
5. **WebSocket support** is included for potential future needs

## Route Summary

- **Backend (port 5000)**: `/api/*` and `/health`
- **Frontend (port 8081)**: Everything else (`/`)

