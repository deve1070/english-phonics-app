'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth/context';
import { apiClient } from '@/lib/api/client';
import { LessonsSkeleton } from '@/components/ui/LoadingSkeleton';

// GET /lessons already computes completed_exercises/total_exercises
// per-lesson for the current logged-in user server-side - there is no
// separate /progress endpoint on the backend, so this is the only
// (and correct) source of truth here.
interface Phoneme {
  id: number;
  symbol: string;
}

interface Lesson {
  id: number;
  order: number;
  level: string;
  created_at: string;
  total_exercises: number;
  completed_exercises: number;
  phonemes: Phoneme[];
}

export default function LessonsPage() {
  const router = useRouter();
  const { user, logout } = useAuth();
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [filter, setFilter] = useState<'all' | 'completed' | 'in-progress'>('all');

  useEffect(() => {
    if (user?.role !== 'STUDENT') {
      router.push('/login');
      return;
    }
    fetchLessons();
  }, [user, router]);

  const fetchLessons = async () => {
    try {
      const lessonsData = await apiClient.get<Lesson[]>('/lessons');
      setLessons(lessonsData);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load lessons');
    } finally {
      setIsLoading(false);
    }
  };

  const handleLogout = () => {
    logout();
    router.push('/login');
  };

  const handleLessonClick = (lessonId: number) => {
    router.push(`/student/lessons/${lessonId}`);
  };

  const isLessonCompleted = (lesson: Lesson) =>
    lesson.total_exercises > 0 && lesson.completed_exercises >= lesson.total_exercises;

  const getFilteredLessons = () => {
    let filtered = lessons;

    if (searchQuery) {
      filtered = filtered.filter(lesson =>
        lesson.level.toLowerCase().includes(searchQuery.toLowerCase()) ||
        `Lesson ${lesson.order}`.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }

    switch (filter) {
      case 'completed':
        filtered = filtered.filter(isLessonCompleted);
        break;
      case 'in-progress':
        filtered = filtered.filter(lesson => lesson.completed_exercises > 0 && !isLessonCompleted(lesson));
        break;
    }

    return filtered;
  };

  const getResumeLesson = () => {
    for (const lesson of lessons) {
      if (!isLessonCompleted(lesson)) {
        return lesson;
      }
    }
    return null;
  };

  if (isLoading) {
    return <LessonsSkeleton />;
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
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Phonics Lessons</h1>
            <p className="text-gray-600">Welcome, {user?.name}</p>
          </div>
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

        {/* Resume Learning Button */}
        {(() => {
          const resumeLesson = getResumeLesson();
          if (resumeLesson) {
            return (
              <div className="bg-gradient-to-r from-indigo-500 to-purple-600 rounded-xl shadow-lg p-6 mb-6 text-white flex justify-between items-center">
                <div>
                  <h3 className="text-xl font-bold mb-2">Continue Learning</h3>
                  <p className="text-white/90">Pick up where you left off</p>
                </div>
                <button
                  onClick={() => handleLessonClick(resumeLesson.id)}
                  className="bg-white text-indigo-600 px-6 py-3 rounded-lg font-bold shadow-md hover:bg-gray-100 transition"
                >
                  Start Lesson {resumeLesson.order}
                </button>
              </div>
            );
          }
          return null;
        })()}

        {/* Search and Filter Controls */}
        <div className="bg-white rounded-xl shadow-md p-4 mb-6">
          <div className="flex flex-col md:flex-row gap-4">
            <input
              type="text"
              placeholder="Search lessons..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
            />
            <div className="flex gap-2">
              <button
                onClick={() => setFilter('all')}
                className={`px-4 py-2 rounded-lg transition ${
                  filter === 'all' ? 'bg-indigo-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                }`}
              >
                All
              </button>
              <button
                onClick={() => setFilter('completed')}
                className={`px-4 py-2 rounded-lg transition ${
                  filter === 'completed' ? 'bg-indigo-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                }`}
              >
                Completed
              </button>
              <button
                onClick={() => setFilter('in-progress')}
                className={`px-4 py-2 rounded-lg transition ${
                  filter === 'in-progress' ? 'bg-indigo-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                }`}
              >
                In Progress
              </button>
            </div>
          </div>
        </div>

        {/* Phonemes Grid */}
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-6">
          {getFilteredLessons()
            .flatMap((lesson) => lesson.phonemes)
            .map((phoneme) => (
              <div
                key={phoneme.id}
                onClick={() => router.push(`/student/phonemes/${phoneme.id}`)}
                className="bg-white rounded-2xl shadow-md p-8 cursor-pointer hover:shadow-xl hover:-translate-y-1 transition transform flex items-center justify-center min-h-[160px]"
              >
                <span className="text-5xl font-extrabold text-indigo-600">
                  {phoneme.symbol}
                </span>
              </div>
            ))}
        </div>

        {getFilteredLessons().length === 0 && (
          <div className="bg-white rounded-xl shadow-md p-8 text-center">
            <p className="text-gray-600">
              {searchQuery || filter !== 'all' 
                ? 'No lessons match your search or filter' 
                : 'No lessons available yet'}
            </p>
          </div>
        )}
      </main>
    </div>
  );
}
