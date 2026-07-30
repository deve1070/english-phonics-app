# English Phonics App

A comprehensive English phonics learning platform designed to help children master pronunciation, spelling, and reading skills through interactive exercises and games.

## Overview

The English Phonics App is a full-stack educational platform consisting of:
- **Backend API**: RESTful API built with Python/FastAPI for authentication, content management, and speech processing
- **Frontend Web App**: Next.js 14 application with modern UI for parents and students
- **Mobile App**: React Native application for on-the-go learning

## Features

### For Parents
- **Account Management**: Secure registration and authentication
- **Child Profiles**: Add and manage multiple children
- **Progress Tracking**: Monitor learning progress with detailed statistics
- **Dashboard**: View child performance, streaks, and activity
- **Export Reports**: Download progress data in CSV format
- **Session Management**: Switch between parent and child accounts

### For Students
- **Interactive Lessons**: Structured phonics lessons with audio pronunciation
- **Pronunciation Exercises**: Record and compare pronunciation with AI feedback
- **Spelling Bee Game**: Fun spelling practice with difficulty levels and streak bonuses
- **Progress Visualization**: Track improvement with score trends and charts
- **Resume Learning**: Pick up where you left off with smart progress tracking
- **Audio Playback**: Listen to reference pronunciations before attempting exercises

### Technical Features
- **Cookie-based Authentication**: Secure JWT token storage with refresh token rotation
- **Token Refresh**: Automatic token refresh for seamless session management
- **Error Boundaries**: Graceful error handling throughout the application
- **Form Validation**: Robust validation using react-hook-form and Zod
- **Toast Notifications**: User-friendly feedback for all actions
- **Loading States**: Skeleton loaders for better UX during data fetching
- **Responsive Design**: Mobile-first design that works on all devices

## Tech Stack

### Frontend
- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **State Management**: React Context API
- **Form Validation**: react-hook-form + Zod
- **UI Components**: Custom component library (Button, Input, Card, ProgressBar, etc.)
- **HTTP Client**: Custom API client with cookie-based authentication

### Backend
- **Framework**: FastAPI (Python)
- **Database**: PostgreSQL
- **Authentication**: JWT with refresh tokens
- **Speech Processing**: Text-to-Speech and Speech-to-Text integration
- **API Documentation**: OpenAPI/Swagger

### Mobile
- **Framework**: Flutter (Dart)
- **State Management**: Provider/GetX
- **Biometric Authentication**: Device-level biometric support

## Project Structure

```
english-phonics-app/
├── phonics-web/              # Next.js frontend application
│   ├── src/
│   │   ├── app/             # Next.js App Router pages
│   │   │   ├── (auth)/      # Authentication pages (login, register)
│   │   │   ├── parent/      # Parent dashboard and features
│   │   │   └── student/     # Student learning pages
│   │   ├── components/      # Reusable UI components
│   │   │   ├── ui/         # Base UI components
│   │   │   └── ErrorBoundary.tsx
│   │   ├── lib/
│   │   │   ├── api/        # API client with token management
│   │   │   ├── auth/       # Authentication context
│   │   │   └── validation/ # Zod schemas
│   │   └── middleware.ts   # Route protection middleware
│   └── package.json
├── backend/                 # FastAPI backend (Python)
├── mobile/                  # Flutter mobile app
└── README.md
```

## Getting Started

### Prerequisites
- Node.js 18+ and npm/yarn/pnpm
- Python 3.9+
- Flutter SDK
- PostgreSQL database
- Backend API running on configured port

### Frontend Setup

1. **Install dependencies**:
```bash
cd phonics-web
npm install
# or
yarn install
# or
pnpm install
```

2. **Configure environment variables**:
Create a `.env.local` file in the `phonics-web` directory:
```env
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
```

3. **Run development server**:
```bash
npm run dev
# or
yarn dev
# or
pnpm dev
```

4. **Open in browser**:
Navigate to [http://localhost:3000](http://localhost:3000)

### Backend Setup

1. **Install Python dependencies**:
```bash
cd backend
pip install -r requirements.txt
```

2. **Configure database**:
Update database connection in `.env` file

3. **Run backend server**:
```bash
uvicorn main:app --reload
```

### Mobile Setup

1. **Install Flutter**: Download and install Flutter SDK from [flutter.dev](https://flutter.dev/docs/get-started/install)

2. **Install dependencies**:
```bash
cd mobile
flutter pub get
```

3. **Configure environment**:
Update API base URL in configuration files

4. **Run on device/simulator**:
```bash
flutter run
# or for specific device
flutter run -d <device-id>
```

## API Integration

The frontend uses a custom API client (`src/lib/api/client.ts`) that handles:
- Cookie-based JWT token storage
- Automatic token refresh on 401 errors
- Request/response interceptors
- Error handling

### Example Usage

```typescript
import { apiClient } from '@/lib/api/client';

// GET request
const data = await apiClient.get('/lessons');

// POST request
const result = await apiClient.post('/auth/login', { username, password });
```

## Authentication Flow

1. **Login/Register**: User credentials sent to backend
2. **Token Storage**: Access and refresh tokens stored in HTTP-only cookies
3. **Session Management**: Tokens automatically refreshed when expired
4. **Route Protection**: Middleware checks authentication status
5. **Role-based Access**: Parents and students have different access patterns

## Development Guidelines

### Code Style
- Use TypeScript for type safety
- Follow React best practices
- Use functional components with hooks
- Implement proper error handling
- Add loading states for async operations

### Component Development
- Extract reusable components to `src/components/ui/`
- Use the existing component library when possible
- Follow the established naming conventions
- Implement proper TypeScript interfaces

### State Management
- Use React Context for global state (authentication)
- Use local state for component-specific data
- Avoid unnecessary re-renders with proper memoization

## Deployment

### Frontend (Vercel)
1. Connect repository to Vercel
2. Configure environment variables
3. Deploy automatically on push to main branch

### Backend (Docker/Cloud)
1. Build Docker image
2. Deploy to cloud provider (AWS, GCP, Azure)
3. Configure environment variables
4. Set up database and migrations

### Mobile (App Store/Play Store)
1. Build production bundles
2. Submit to app stores
3. Configure app signing and provisioning

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write tests for new features
5. Submit a pull request

## License

This project is proprietary software. All rights reserved.

## Support

For support and questions, please contact the development team.
