/**
 * API Client with JWT handling
 * Handles authentication and API requests to the backend.
 *
 * NOTE on sessions: the backend issues a single access_token (JWT, valid
 * 7 days by default - see ACCESS_TOKEN_EXPIRE_MINUTES) and does not have
 * a /auth/refresh endpoint or a refresh_token concept. There is a
 * biometric_token returned by /auth/login and /auth/register, used only
 * for the mobile app's "stay signed in on this device" flow via
 * POST /auth/passkey-login - it's not a web session mechanism. When the
 * access token expires, the cookie itself expires at the same time and
 * the user is redirected to /login by middleware.ts - that's the whole
 * "refresh" story on web for now, and it's fine given login is just a
 * phone number, no password.
 */

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api/v1';

// Matches backend ACCESS_TOKEN_EXPIRE_MINUTES default (7 days). Keep in
// sync if that setting changes.
const ACCESS_TOKEN_MAX_AGE_SECONDS = 60 * 60 * 24 * 7;

interface ApiClientConfig {
  baseURL?: string;
  headers?: Record<string, string>;
}

class ApiClient {
  public baseURL: string;
  private defaultHeaders: Record<string, string>;

  constructor(config: ApiClientConfig = {}) {
    this.baseURL = config.baseURL || API_BASE_URL;
    this.defaultHeaders = {
      'Content-Type': 'application/json',
      ...config.headers,
    };
  }

  public getAuthHeaders(): Record<string, string> {
    if (typeof window === 'undefined') return {};

    const token = this.getToken();
    if (token) {
      return { Authorization: `Bearer ${token}` };
    }
    return {};
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {},
  ): Promise<T> {
    const url = `${this.baseURL}${endpoint}`;
    const headers = {
      ...this.defaultHeaders,
      ...this.getAuthHeaders(),
      ...options.headers,
    };

    try {
      const response = await fetch(url, {
        ...options,
        headers,
      });

      if (!response.ok) {
        if (response.status === 401) {
          // No refresh mechanism on web - the token is gone or expired,
          // so clear it and let middleware.ts send the user to /login on
          // their next navigation.
          this.clearToken();
        }

        const error = await response.json().catch(() => ({ detail: response.statusText }));
        throw new Error(error.detail || 'Request failed');
      }

      return await response.json();
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('An unexpected error occurred');
    }
  }

  async get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'GET' });
  }

  async post<T>(endpoint: string, data?: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async put<T>(endpoint: string, data?: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async delete<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE' });
  }

  async upload<T>(endpoint: string, file: File): Promise<T> {
    const url = `${this.baseURL}${endpoint}`;
    const formData = new FormData();
    formData.append('audio', file);

    const headers = {
      ...this.getAuthHeaders(),
    };

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: formData,
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: response.statusText }));
      throw new Error(error.detail || 'Upload failed');
    }

    return await response.json();
  }

  /**
   * @param maxAgeSeconds defaults to the backend's normal 7-day access
   *   token lifetime. Pass a shorter value for tokens with a different
   *   real expiry (e.g. the 2-hour child-login token from
   *   POST /parents/child-login/{id}) so the cookie doesn't outlive or
   *   undercut the actual JWT.
   */
  setToken(token: string, maxAgeSeconds: number = ACCESS_TOKEN_MAX_AGE_SECONDS): void {
    if (typeof window !== 'undefined') {
      document.cookie = `access_token=${token}; path=/; max-age=${maxAgeSeconds}; SameSite=Strict; ${process.env.NODE_ENV === 'production' ? 'Secure;' : ''}`;
    }
  }

  getToken(): string | null {
    if (typeof window === 'undefined') return null;
    const match = document.cookie.match(/(^|;) *access_token=([^;]*)/);
    return match ? match[2] : null;
  }

  clearToken(): void {
    if (typeof window !== 'undefined') {
      document.cookie = 'access_token=; path=/; max-age=0; SameSite=Strict';
      document.cookie = 'user_role=; path=/; max-age=0; SameSite=Strict';
    }
  }

  setRole(role: string, maxAgeSeconds: number = ACCESS_TOKEN_MAX_AGE_SECONDS): void {
    if (typeof window !== 'undefined') {
      document.cookie = `user_role=${role}; path=/; max-age=${maxAgeSeconds}; SameSite=Strict; ${process.env.NODE_ENV === 'production' ? 'Secure;' : ''}`;
    }
  }

  getRole(): string | null {
    if (typeof window === 'undefined') return null;
    const match = document.cookie.match(/(^|;) *user_role=([^;]*)/);
    return match ? match[2] : null;
  }

  isAuthenticated(): boolean {
    const token = this.getToken();
    if (!token) return false;

    try {
      // Simple JWT expiry check
      const payload = JSON.parse(atob(token.split('.')[1]));
      const now = Math.floor(Date.now() / 1000);
      return payload.exp > now;
    } catch {
      return false;
    }
  }
}

export const apiClient = new ApiClient();
