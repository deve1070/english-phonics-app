'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';
import { apiClient } from '../api/client';

interface User {
  id: number;
  name: string;
  email?: string;
  phone_number?: string;
  age_group?: number;
  role: string;
  user_name?: string;
}

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  isParent: boolean;
  isStudent: boolean;
  login: (phoneNumber: string) => Promise<void>;
  register: (data: RegisterData) => Promise<void>;
  logout: () => void;
  switchToChild: (childId: number) => Promise<void>;
  switchToParent: () => Promise<void>;
}

interface RegisterData {
  name: string;
  phone_number: string;
  child_name: string;
  child_user_name: string;
  child_nickname?: string;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Matches the 2-hour expiry the backend actually issues for child-login
// tokens (POST /parents/child-login/{id} -> expires_in_seconds: 7200).
const CHILD_TOKEN_MAX_AGE_SECONDS = 60 * 60 * 2;

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Check if user is authenticated on mount
    if (apiClient.isAuthenticated()) {
      fetchCurrentUser();
    } else {
      setIsLoading(false);
    }
  }, []);

  const fetchCurrentUser = async () => {
    try {
      const userData = await apiClient.get<User>('/users/me');
      // Normalize role to uppercase to match frontend checks ('PARENT', 'STUDENT')
      if (userData.role) {
        userData.role = userData.role.toUpperCase();
        apiClient.setRole(userData.role);
      }
      setUser(userData);
    } catch (error) {
      console.error('Failed to fetch current user:', error);
      apiClient.clearToken();
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (phoneNumber: string) => {
    setIsLoading(true);
    try {
      // Single-step login: phone number → access token + biometric token.
      // The backend /auth/login endpoint handles everything in one call.
      // There's no password or PIN - the backend is intentionally
      // passwordless for this version.
      const loginResponse = await apiClient.post<{
        access_token: string;
        biometric_token: string;
        token_type: string;
      }>('/auth/login', { phone_number: phoneNumber });

      apiClient.setToken(loginResponse.access_token);

      // Role is resolved by fetchCurrentUser() via /users/me — never hardcoded.
      await fetchCurrentUser();
    } catch (error) {
      setIsLoading(false);
      throw error;
    }
  };

  const register = async (data: RegisterData) => {
    setIsLoading(true);
    try {
      // POST /parents/register creates the parent + first child in one
      // step and returns only { parent_id, parent_phone, child,
      // access_token, token_type } - no full parent User object, so we
      // fetch it the same way login() does rather than trusting the
      // response shape to match our User type.
      const response = await apiClient.post<{
        parent_id: number;
        parent_phone: string;
        access_token: string;
        token_type: string;
      }>('/parents/register', {
        name: data.name,
        phone_number: data.phone_number,
        child: {
          name: data.child_name,
          user_name: data.child_user_name,
          nickname: data.child_nickname || undefined,
        },
      });

      apiClient.setToken(response.access_token);
      apiClient.setRole('PARENT');
      await fetchCurrentUser();
    } catch (error) {
      setIsLoading(false);
      throw error;
    }
  };

  const logout = () => {
    apiClient.clearToken();
    setUser(null);
  };

  const switchToChild = async (childId: number) => {
    setIsLoading(true);
    try {
      const parentToken = apiClient.getToken();
      if (parentToken) {
        document.cookie = `parent_access_token=${parentToken}; path=/; max-age=3600; SameSite=Strict; ${process.env.NODE_ENV === 'production' ? 'Secure;' : ''}`;
      }

      // Response shape from POST /parents/child-login/{id}:
      // { access_token, token_type, child_id, child_name, expires_in_seconds }
      const response = await apiClient.post<{
        access_token: string;
        token_type: string;
        expires_in_seconds: number;
      }>(`/parents/child-login/${childId}`);

      apiClient.setToken(response.access_token, response.expires_in_seconds || CHILD_TOKEN_MAX_AGE_SECONDS);
      apiClient.setRole('STUDENT', response.expires_in_seconds || CHILD_TOKEN_MAX_AGE_SECONDS);

      await fetchCurrentUser();
    } catch (error) {
      setIsLoading(false);
      throw error;
    }
  };

  const switchToParent = async () => {
    setIsLoading(true);
    try {
      const parentTokenMatch = document.cookie.match(/(^|;) *parent_access_token=([^;]*)/);
      const parentToken = parentTokenMatch ? parentTokenMatch[2] : null;

      if (parentToken) {
        apiClient.setToken(parentToken);
        // Role is resolved by fetchCurrentUser() via /users/me — never hardcoded.
        await fetchCurrentUser();

        // Clear the stashed parent token now that we've switched back
        document.cookie = 'parent_access_token=; path=/; max-age=0; SameSite=Strict';
      } else {
        // No parent token found — clear loading state to avoid infinite spinner.
        console.warn('switchToParent: no parent token found in cookie. User may need to log in again.');
        setIsLoading(false);
      }
    } catch (error) {
      setIsLoading(false);
      throw error;
    }
  };

  const value: AuthContextType = {
    user,
    isLoading,
    isAuthenticated: !!user,
    isParent: user?.role === 'PARENT',
    isStudent: user?.role === 'STUDENT',
    login,
    register,
    logout,
    switchToChild,
    switchToParent,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
