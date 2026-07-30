'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { useAuth } from '@/lib/auth/context';
import { apiClient } from '@/lib/api/client';
import { ProgressBar } from '@/components/ui';
import { CardSkeleton } from '@/components/ui/LoadingSkeleton';

// Matches backend ChildProgressResponse exactly
// (GET /parents/children/{id}/progress in schemas/schemas_parent.py).
// The previous version of this page stitched together GET /progress
// (doesn't exist on the backend) and GET /exercises (doesn't exist as
// a list endpoint either), and hardcoded the child's name as a
// placeholder ("Child"/"username" with a "would come from user
// endpoint" TODO). This one real endpoint already provides everything
// needed, including phoneme-level mastery, which the old version never
// showed at all.
interface PhonemeProgress {
  phoneme_id: number;
  symbol: string;
  order: number;
  is_mastered: boolean;
  avg_score: number | null;
  attempts: number;
}

interface ChildProgress {
  child_id: number;
  child_name: string;
  lessons_completed: number;
  total_lessons: number;
  exercises_completed: number;
  total_exercises: number;
  avg_pronunciation_score: number | null;
  streak_days: number;
  minutes_this_week: number;
  phoneme_progress: PhonemeProgress[];
  last_active: string | null;
}

function formatLastActive(iso?: string | null): string {
  if (!iso) return 'Never';
  const date = new Date(iso);
  const diffMs = Date.now() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d ago`;
}

export default function ChildDetailPage() {
  const router = useRouter();
  const params = useParams();
  const { user } = useAuth();
  const [progress, setProgress] = useState<ChildProgress | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  const childId = parseInt(params.id as string);

  const fetchProgress = useCallback(async () => {
    try {
      const data = await apiClient.get<ChildProgress>(`/parents/children/${childId}/progress`);
      setProgress(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load child progress');
    } finally {
      setIsLoading(false);
    }
  }, [childId]);

  useEffect(() => {
    if (user?.role !== 'PARENT') {
      router.push('/login');
      return;
    }
    fetchProgress();
  }, [user, router, fetchProgress]);

  const handleBack = () => {
    router.push('/parent/dashboard');
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50">
        <div className="bg-white shadow-sm h-16 mb-8" />
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 grid grid-cols-1 md:grid-cols-2 gap-6">
          {[1, 2, 3, 4].map((i) => <CardSkeleton key={i} />)}
        </div>
      </div>
    );
  }

  if (error || !progress) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-red-600">Error: {error || 'Child not found'}</div>
      </div>
    );
  }

  const lessonPct = progress.total_lessons > 0
    ? (progress.lessons_completed / progress.total_lessons) * 100
    : 0;
  const exercisePct = progress.total_exercises > 0
    ? (progress.exercises_completed / progress.total_exercises) * 100
    : 0;

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <button
            onClick={handleBack}
            className="text-gray-600 hover:text-gray-900 flex items-center gap-2"
          >
            <span>←</span>
            <span>Back to Dashboard</span>
          </button>
          <h1 className="text-2xl font-bold text-gray-900">{progress.child_name}</h1>
          <div className="w-32" />
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Summary Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="text-gray-600 mb-2 text-sm">Avg. Pronunciation</div>
            <div className="text-3xl font-bold text-indigo-600">
              {progress.avg_pronunciation_score != null ? progress.avg_pronunciation_score.toFixed(0) : '—'}
            </div>
          </div>
          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="text-gray-600 mb-2 text-sm">Streak</div>
            <div className="text-3xl font-bold text-orange-600">{progress.streak_days}d</div>
          </div>
          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="text-gray-600 mb-2 text-sm">This Week</div>
            <div className="text-3xl font-bold text-green-600">{progress.minutes_this_week.toFixed(0)}m</div>
          </div>
          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="text-gray-600 mb-2 text-sm">Last Active</div>
            <div className="text-2xl font-bold text-gray-700">{formatLastActive(progress.last_active)}</div>
          </div>
        </div>

        {/* Lesson & Exercise Progress */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <div className="bg-white rounded-xl shadow-md p-6">
            <ProgressBar
              progress={lessonPct}
              label={`Lessons: ${progress.lessons_completed}/${progress.total_lessons}`}
              showPercentage
            />
          </div>
          <div className="bg-white rounded-xl shadow-md p-6">
            <ProgressBar
              progress={exercisePct}
              label={`Exercises: ${progress.exercises_completed}/${progress.total_exercises}`}
              showPercentage
            />
          </div>
        </div>

        {/* Phoneme Mastery */}
        <div>
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Phoneme Mastery</h2>
          {progress.phoneme_progress.length === 0 ? (
            <div className="bg-white rounded-xl shadow-md p-8 text-center text-gray-600">
              No phoneme attempts yet.
            </div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
              {progress.phoneme_progress
                .slice()
                .sort((a, b) => a.order - b.order)
                .map((p) => (
                  <div
                    key={p.phoneme_id}
                    className={`bg-white rounded-xl shadow-md p-4 text-center border-2 ${
                      p.is_mastered ? 'border-green-400' : 'border-transparent'
                    }`}
                  >
                    <div className="text-2xl font-bold text-indigo-600 mb-1">/{p.symbol}/</div>
                    <div className="text-xs text-gray-600 mb-1">
                      {p.avg_score != null ? `${p.avg_score.toFixed(0)}%` : 'No attempts'}
                    </div>
                    <div className="text-xs text-gray-400">{p.attempts} attempt{p.attempts !== 1 ? 's' : ''}</div>
                    {p.is_mastered && <div className="text-xs text-green-600 font-semibold mt-1">Mastered</div>}
                  </div>
                ))}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
