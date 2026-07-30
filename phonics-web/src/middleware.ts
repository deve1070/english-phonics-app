import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const publicPaths = ['/login', '/register'];

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  
  // Allow exact public paths
  if (publicPaths.includes(pathname)) {
    // If user is already authenticated and tries to access login/register, redirect to dashboard
    const token = request.cookies.get('access_token');
    const role = request.cookies.get('user_role');
    
    if (token && role) {
      if (role.value === 'PARENT') {
        return NextResponse.redirect(new URL('/parent/dashboard', request.url));
      } else if (role.value === 'STUDENT') {
        return NextResponse.redirect(new URL('/student/lessons', request.url));
      }
    }
    
    return NextResponse.next();
  }

  // Check authentication for protected routes
  const token = request.cookies.get('access_token');
  const role = request.cookies.get('user_role');

  if (!token) {
    // Redirect to login if not authenticated
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Role-based routing
  if (pathname.startsWith('/parent')) {
    if (role?.value !== 'PARENT') {
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }

  if (pathname.startsWith('/student')) {
    if (role?.value !== 'STUDENT') {
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    /*
     * Match all request paths except:
     * - api routes
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - public files
     */
    '/((?!api|_next/static|_next/image|favicon.ico|public).*)',
  ],
};
