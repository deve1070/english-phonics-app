'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth/context';
import { apiClient } from '@/lib/api/client';
import { ProgressBar } from '@/components/ui';

// GET /lessons already includes completed_exercises/total_exercises for
// the current user. There is no separate /progress or /exercises list
// endpoint on the backend - a per-attempt score history/trend for the
// student's own view doesn't exist yet, so this page shows what's
// actually available rather than calling endpoints that don't exist.
interface Lesson {
  id: number;
  order: number;
  level: string;
  total_exercises: number;
  completed_exercises: number;
}

export default function ProgressPage() {
  const router = useRouter();
  const { user, logout } = useAuth();
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (user?.role !== 'STUDENT') {
      router.push('/login');
      return;
    }
    fetchProgress();
  }, [user, router]);

  const fetchProgress = async () => {
    try {
      const lessonsData = await apiClient.get<Lesson[]>('/lessons');
      setLessons(lessonsData);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load progress');
    } finally {
      setIsLoading(false);
    }
  };

  const handleLogout = () => {
    logout();
    router.push('/login');
  };

  const totalExercises = lessons.reduce((sum, l) => sum + l.total_exercises, 0);
  const completedExercises = lessons.reduce((sum, l) => sum + l.completed_exercises, 0);
  const lessonsStarted = lessons.filter(l => l.completed_exercises > 0).length;
  const lessonsCompleted = lessons.filter(l => l.total_exercises > 0 && l.completed_exercises >= l.total_exercises).length;
  const overallPct = totalExercises > 0 ? (completedExercises / totalExercises) * 100 : 0;

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-xl">Loading...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-red-600">Error: {error}</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <button
            onClick={() => router.push('/student/lessons')}
            className="text-gray-600 hover:text-gray-900 flex items-center gap-2"
          >
            <span>←</span>
            <span>Back to Lessons</span>
          </button>
          <h1 className="text-2xl font-bold text-gray-900">My Progress</h1>
          <button
            onClick={handleLogout}
            className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
          >
            Logout
          </button>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-6">
            {error}
          </div>
        )}

        {/* Summary Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="text-gray-600 mb-2">Total Exercises</div>
            <div className="text-3xl font-bold text-indigo-600">{totalExercises}</div>
          </div>
          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="text-gray-600 mb-2">Completed</div>
            <div className="text-3xl font-bold text-green-600">{completedExercises}</div>
          </div>
          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="text-gray-600 mb-2">Overall Progress</div>
            <div className="text-3xl font-bold text-purple-600">{overallPct.toFixed(0)}%</div>
          </div>
          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="text-gray-600 mb-2">Lessons Completed</div>
            <div className="text-3xl font-bold text-orange-600">{lessonsCompleted}/{lessons.length}</div>
          </div>
        </div>

        {/* Lessons Progress */}
        <div>
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Lesson Progress</h2>
          {lessonsStarted === 0 ? (
            <div className="bg-white rounded-xl shadow-md p-8 text-center text-gray-600">
              You haven&apos;t started any lessons yet - head back to Lessons to get going!
            </div>
          ) : (
            <div className="space-y-4">
              {lessons.map((lesson) => {
                const progressPercent = lesson.total_exercises > 0
                  ? (lesson.completed_exercises / lesson.total_exercises) * 100
                  : 0;

                return (
                  <div key={lesson.id} className="bg-white rounded-xl shadow-md p-6">
                    <div className="flex items-center justify-between mb-4">
                      <div>
                        <h3 className="text-lg font-semibold text-gray-900">
                          Lesson {lesson.order}
                        </h3>
                        <p className="text-sm text-gray-600">Level: {lesson.level}</p>
                      </div>
                    </div>

                    <ProgressBar
                      progress={progressPercent}
                      label={`${lesson.completed_exercises}/${lesson.total_exercises} exercises`}
                      showPercentage
                    />
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
