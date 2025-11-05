# Soliflex Backend API

Node.js Express backend server for Soliflex Packaging Transporter application.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Start the server:
```bash
npm start
```

For development with auto-reload:
```bash
npm run dev
```

The server will run on `http://localhost:3000`

## API Endpoints

### POST /api/register
Register a new user.

**Request Body:**
```json
{
  "fullName": "John Doe",
  "password": "SecurePass123!",
  "department": "Admin"
}
```

### POST /api/login
Authenticate a user.

**Request Body:**
```json
{
  "fullName": "John Doe",
  "password": "SecurePass123!"
}
```

### GET /api/departments
Get list of all departments.

### GET /api/user/:userId
Get user details by userId.

## Data Storage

User data is stored in `backend.csv` file in CSV format with the following structure:
- userId
- fullName
- passwordHash (argon2 hashed)
- department
- role

## Roles

- **SUPER_USER**: Admin department
- **APPROVAL_MANAGER**: Accounts Team department
- **RFQ_CREATOR**: All other departments

