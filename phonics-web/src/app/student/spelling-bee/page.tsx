'use client';

import { useEffect, useState, useRef, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth/context';
import { apiClient } from '@/lib/api/client';

export default function SpellingBeePage() {
  const router = useRouter();
  const { user, logout } = useAuth();
  const [word, setWord] = useState('');
  const [userSpelling, setUserSpelling] = useState('');
  const [isPlaying, setIsPlaying] = useState(false);
  const [score, setScore] = useState(0);
  const [round, setRound] = useState(1);
  const [feedback, setFeedback] = useState('');
  const [showFeedback, setShowFeedback] = useState(false);
  const [difficulty, setDifficulty] = useState<'easy' | 'medium' | 'hard'>('easy');
  const [streak, setStreak] = useState(0);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  const wordsByDifficulty = {
    easy: ['apple', 'cat', 'dog', 'fish', 'house', 'ice', 'ball', 'book', 'tree', 'bird'],
    medium: ['banana', 'elephant', 'grape', 'jungle', 'orange', 'purple', 'yellow', 'school', 'friend', 'happy'],
    hard: ['beautiful', 'adventure', 'knowledge', 'mysterious', 'extraordinary', 'consciousness', 'responsibility', 'opportunity', 'experience', 'achievement'],
  };

  const loadNewWord = useCallback(() => {
    const words = wordsByDifficulty[difficulty];
    const randomIndex = Math.floor(Math.random() * words.length);
    setWord(words[randomIndex]);
    setUserSpelling('');
    setShowFeedback(false);
    // wordsByDifficulty is a stable inline constant, safe to omit
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [difficulty]);

  useEffect(() => {
    if (user?.role !== 'STUDENT') {
      router.push('/login');
      return;
    }
  }, [user, router]);

  // Single source of truth for loading a word: runs on mount and whenever
  // difficulty changes. Previously there were two separate effects that
  // both called loadNewWord() independently, firing it twice on mount.
  useEffect(() => {
    loadNewWord();
  }, [loadNewWord]);

  const playWordAudio = async () => {
    setIsPlaying(true);
    try {
      const response = await fetch(`${apiClient.baseURL}/tts/synthesize`, {
        method: 'POST',
        headers: {
          ...apiClient.getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text: word }),
      });

      if (!response.ok) {
        throw new Error('Failed to get audio');
      }

      const audioBlob = await response.blob();
      const audioUrl = URL.createObjectURL(audioBlob);
      
      if (audioRef.current) {
        audioRef.current.src = audioUrl;
        audioRef.current.onended = () => setIsPlaying(false);
        audioRef.current.play();
      }
    } catch (err) {
      console.error('Failed to play audio:', err);
      setIsPlaying(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    const isCorrect = userSpelling.toLowerCase() === word.toLowerCase();
    
    if (isCorrect) {
      const pointsByDifficulty = { easy: 10, medium: 15, hard: 20 };
      const basePoints = pointsByDifficulty[difficulty];
      const streakBonus = Math.floor(streak / 3) * 5; // Bonus every 3 correct answers
      const totalPoints = basePoints + streakBonus;
      
      setScore(score + totalPoints);
      setStreak(streak + 1);
      setFeedback(`Correct! +${totalPoints} points 🎉${streakBonus > 0 ? ` (Streak bonus: +${streakBonus})` : ''}`);
    } else {
      setStreak(0);
      setFeedback(`Wrong! The word was: ${word}`);
    }
    
    setShowFeedback(true);
  };

  const handleNextRound = () => {
    setRound(round + 1);
    loadNewWord();
  };

  const handleLogout = () => {
    logout();
    router.push('/login');
  };

  const handleBack = () => {
    router.push('/student/lessons');
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-yellow-50 to-orange-100">
      <audio ref={audioRef} />
      
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
          <h1 className="text-2xl font-bold text-gray-900">🐝 Spelling Bee</h1>
          <button
            onClick={handleLogout}
            className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
          >
            Logout
          </button>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Score, Round, and Streak */}
        <div className="grid grid-cols-3 gap-4 mb-8">
          <div className="bg-white rounded-xl shadow-md px-6 py-4">
            <div className="text-sm text-gray-600">Score</div>
            <div className="text-3xl font-bold text-yellow-600">{score}</div>
          </div>
          <div className="bg-white rounded-xl shadow-md px-6 py-4">
            <div className="text-sm text-gray-600">Round</div>
            <div className="text-3xl font-bold text-orange-600">{round}</div>
          </div>
          <div className="bg-white rounded-xl shadow-md px-6 py-4">
            <div className="text-sm text-gray-600">Streak</div>
            <div className="text-3xl font-bold text-purple-600">{streak} 🔥</div>
          </div>
        </div>

        {/* Difficulty Selection */}
        <div className="bg-white rounded-xl shadow-md p-4 mb-6">
          <div className="text-sm text-gray-600 mb-2">Difficulty</div>
          <div className="flex gap-2">
            <button
              onClick={() => setDifficulty('easy')}
              className={`flex-1 py-2 rounded-lg transition ${
                difficulty === 'easy' ? 'bg-green-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
              }`}
            >
              Easy
            </button>
            <button
              onClick={() => setDifficulty('medium')}
              className={`flex-1 py-2 rounded-lg transition ${
                difficulty === 'medium' ? 'bg-yellow-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
              }`}
            >
              Medium
            </button>
            <button
              onClick={() => setDifficulty('hard')}
              className={`flex-1 py-2 rounded-lg transition ${
                difficulty === 'hard' ? 'bg-red-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
              }`}
            >
              Hard
            </button>
          </div>
        </div>

        {/* Game Area */}
        <div className="bg-white rounded-2xl shadow-xl p-8 text-center">
          {!showFeedback ? (
            <>
              <div className="mb-8">
                <button
                  onClick={playWordAudio}
                  disabled={isPlaying}
                  className="bg-yellow-500 text-white px-8 py-4 rounded-full text-lg font-semibold hover:bg-yellow-600 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2 mx-auto"
                >
                  <span className="text-2xl">{isPlaying ? '🔊' : '🎵'}</span>
                  {isPlaying ? 'Playing...' : 'Listen to the Word'}
                </button>
              </div>

              <form onSubmit={handleSubmit} className="space-y-6">
                <div>
                  <label htmlFor="spelling" className="block text-sm font-medium text-gray-700 mb-2">
                    Type the word you heard
                  </label>
                  <input
                    id="spelling"
                    type="text"
                    value={userSpelling}
                    onChange={(e) => setUserSpelling(e.target.value)}
                    placeholder="Type your answer here..."
                    className="w-full px-4 py-3 text-2xl text-center border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-transparent outline-none transition"
                    autoFocus
                  />
                </div>

                <button
                  type="submit"
                  disabled={!userSpelling}
                  className="w-full bg-orange-600 text-white py-3 rounded-lg font-semibold hover:bg-orange-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Submit Answer
                </button>
              </form>
            </>
          ) : (
            <div className="space-y-6">
              <div className={`text-4xl font-bold ${feedback.includes('Correct') ? 'text-green-600' : 'text-red-600'}`}>
                {feedback}
              </div>

              <button
                onClick={handleNextRound}
                className="bg-yellow-500 text-white px-8 py-3 rounded-lg font-semibold hover:bg-yellow-600 transition"
              >
                Next Word
              </button>
            </div>
          )}
        </div>

        {/* Instructions */}
        <div className="mt-8 bg-white rounded-xl shadow-md p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">How to Play</h3>
          <ul className="space-y-2 text-gray-600">
            <li>🎵 Click &quot;Listen to the Word&quot; to hear the word</li>
            <li>✍️ Type the word you heard</li>
            <li>✅ Get 10 points for each correct answer</li>
            <li>🔄 Continue to improve your score!</li>
          </ul>
        </div>
      </main>
    </div>
  );
}
