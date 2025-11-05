# Soliflex Packaging Transporter

Enterprise-grade packaging and transportation management system with Flutter web frontend and Node.js backend.

## Features

- **Order Management**: Create, track, and manage transportation orders
- **Workflow System**: Sequential role-based approval workflow for En-Route orders
- **RFQ Management**: Request for Quotation system with vendor bidding
- **Analytics Dashboard**: Real-time analytics and operational insights
- **Vehicle Management**: Track vehicle capacity and utilization
- **User Management**: Role-based access control with department-based permissions

## Tech Stack

- **Frontend**: Flutter 3 (Dart 3) - Web
- **Backend**: Node.js + Express
- **State Management**: Provider (Riverpod compatible)
- **Data Storage**: CSV files
- **Process Management**: PM2
- **Deployment**: Azure VM (Ubuntu)

## Project Structure

```
soliflexweb/
├── lib/                    # Flutter source code
│   ├── models/            # Data models
│   ├── screens/           # UI screens
│   ├── services/          # API services
│   ├── providers/         # State management
│   └── theme/             # App theme
├── backend/               # Node.js backend
│   ├── routes/           # API routes
│   ├── services/         # Business logic
│   ├── data/             # CSV data files
│   └── server.js         # Express server
├── build/                 # Flutter web build output
├── ecosystem.config.js    # PM2 configuration
├── deploy.sh             # Deployment script
└── DEPLOYMENT.md         # Deployment guide
```

## Getting Started

### Prerequisites

- Node.js 18+ 
- Flutter 3.x
- Git

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git
   cd soliflextransportwebandmobile
   ```

2. **Setup Backend**
   ```bash
   cd backend
   npm install
   node server.js
   ```
   Backend runs on http://localhost:3000

3. **Setup Frontend**
   ```bash
   flutter pub get
   flutter run -d chrome
   ```
   Frontend runs on http://localhost:8080

### Production Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

Quick deployment commands (run on Ubuntu VM):

```bash
# Clone repository
git clone https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git soliflexweb
cd soliflexweb

# Run deployment script
chmod +x deploy.sh
./deploy.sh
```

## API Endpoints

- `GET /health` - Health check
- `POST /api/auth/login` - User login
- `GET /api/orders` - Get all orders
- `POST /api/orders` - Create order
- `POST /api/initialize-workflow` - Initialize workflow
- `POST /api/workflow-action` - Perform workflow action

See backend/routes/ for complete API documentation.

## Ports

- **Backend**: 3000
- **Frontend**: 4000

## PM2 Management

```bash
# Start apps
pm2 start ecosystem.config.js

# View logs
pm2 logs

# Restart apps
pm2 restart all

# Stop apps
pm2 stop all
```

## License

Proprietary - All rights reserved
