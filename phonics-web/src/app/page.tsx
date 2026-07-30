"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth/context";

export default function HomePage() {
  const router = useRouter();
  const { isAuthenticated, isParent, isStudent, isLoading } = useAuth();

  useEffect(() => {
    if (!isLoading) {
      if (isAuthenticated) {
        if (isParent) {
          router.push("/parent/dashboard");
        } else if (isStudent) {
          router.push("/student/lessons");
        }
      } else {
        router.push("/login");
      }
    }
  }, [isAuthenticated, isParent, isStudent, isLoading, router]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100">
      <div className="text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
        <p className="text-gray-600">Loading...</p>
      </div>
    </div>
  );
}
