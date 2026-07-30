'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { useAuth } from '@/lib/auth/context';
import { apiClient } from '@/lib/api/client';

interface Phoneme {
  id: number;
  symbol: string;
  description?: string;
  audio_url?: string;
  order: number;
  type: string;
}

interface Exercise {
  id: number;
  content: string;
  type: string;
  difficulty: number;
}

// GET /lessons/{id} - no 'exercises' field, only 'phonemes'
interface Lesson {
  id: number;
  order: number;
  level: string;
  phonemes: Phoneme[];
  total_exercises: number;
}

// GET /lessons/{id}/exercises - separate endpoint
interface LessonExercisesResponse {
  lesson_id: number;
  level: string;
  exercises: Exercise[];
}

export default function LessonDetailPage() {
  const router = useRouter();
  const params = useParams();
  const { user } = useAuth();
  const [lesson, setLesson] = useState<Lesson | null>(null);
  const [exercises, setExercises] = useState<Exercise[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  const lessonId = parseInt(params.id as string);

  const fetchLesson = useCallback(async () => {
    try {
      const [lessonData, exercisesData] = await Promise.all([
        apiClient.get<Lesson>(`/lessons/${lessonId}`),
        apiClient.get<LessonExercisesResponse>(`/lessons/${lessonId}/exercises`),
      ]);
      setLesson(lessonData);
      setExercises(exercisesData.exercises);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load lesson');
    } finally {
      setIsLoading(false);
    }
  }, [lessonId]);

  useEffect(() => {
    if (user?.role !== 'STUDENT') {
      router.push('/login');
      return;
    }
    fetchLesson();
  }, [user, router, lessonId, fetchLesson]);

  const handleExerciseClick = (exerciseId: number) => {
    router.push(`/student/exercises/${exerciseId}`);
  };

  const handleBack = () => {
    router.push('/student/lessons');
  };

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
            onClick={handleBack}
            className="text-gray-600 hover:text-gray-900 flex items-center gap-2"
          >
            <span>←</span>
            <span>Back to Lessons</span>
          </button>
          <h1 className="text-2xl font-bold text-gray-900">Lesson {lesson?.order}</h1>
          <div className="w-20" />
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-6">
            {error}
          </div>
        )}

        {/* Phonemes Section */}
        <div className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Phonemes</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
            {lesson?.phonemes.map((phoneme) => (
              <div
                key={phoneme.id}
                onClick={() => router.push(`/student/phonemes/${phoneme.id}`)}
                className="bg-white rounded-xl shadow-md p-4 text-center cursor-pointer hover:shadow-lg hover:scale-105 transition transform"
              >
                <div className="text-3xl font-bold text-indigo-600 mb-2">
                  /{phoneme.symbol}/
                </div>
                <div className="text-sm text-gray-600">{phoneme.type}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Exercises Section */}
        <div>
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Exercises</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {exercises.map((exercise) => (
              <div
                key={exercise.id}
                onClick={() => handleExerciseClick(exercise.id)}
                className="bg-white rounded-xl shadow-md p-6 cursor-pointer hover:shadow-lg transition"
              >
                <div className="flex items-center justify-between mb-4">
                  <span className="text-2xl">
                    {exercise.type === 'PHONEME' && '🔊'}
                    {exercise.type === 'WORD' && '📝'}
                    {exercise.type === 'SENTENCE' && '💬'}
                    {exercise.type === 'PARAGRAPH' && '📄'}
                  </span>
                  <span className="text-sm text-gray-600">Difficulty: {exercise.difficulty}</span>
                </div>

                <h3 className="text-lg font-semibold text-gray-900 mb-2">
                  {exercise.type}
                </h3>
                <p className="text-gray-600 mb-4 line-clamp-2">{exercise.content}</p>

                <button className="w-full bg-indigo-600 text-white py-2 rounded-lg font-semibold hover:bg-indigo-700 transition">
                  Start Exercise
                </button>
              </div>
            ))}
          </div>

          {exercises.length === 0 && (
            <div className="bg-white rounded-xl shadow-md p-8 text-center">
              <p className="text-gray-600">
                No exercises available for this lesson yet. Check back soon!
              </p>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
