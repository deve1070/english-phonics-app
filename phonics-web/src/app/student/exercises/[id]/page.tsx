'use client';

import { useEffect, useState, useRef, useCallback } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { useAuth } from '@/lib/auth/context';
import { apiClient } from '@/lib/api/client';
import { ExerciseSkeleton } from '@/components/ui/LoadingSkeleton';

interface Exercise {
  id: number;
  content: string;
  type: string;
  difficulty: number;
  lesson_id: number;
}

interface PronunciationResult {
  score_id: number;
  score: number;
  accuracy: number;
  fluency: number;
  feedback: string;
  your_speech: string;
}

export default function ExercisePage() {
  const router = useRouter();
  const params = useParams();
  const { user } = useAuth();
  const [exercise, setExercise] = useState<Exercise | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [result, setResult] = useState<PronunciationResult | null>(null);
  const [error, setError] = useState('');
  const [referenceAudio, setReferenceAudio] = useState<string | null>(null);
  const [recordedAudio, setRecordedAudio] = useState<string | null>(null);
  const [recordingTime, setRecordingTime] = useState(0);
  const [isPlayingReference, setIsPlayingReference] = useState(false);
  const [isPlayingRecorded, setIsPlayingRecorded] = useState(false);
  
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const recordingTimerRef = useRef<NodeJS.Timeout | null>(null);
  const referenceAudioRef = useRef<HTMLAudioElement | null>(null);
  const recordedAudioRef = useRef<HTMLAudioElement | null>(null);

  const exerciseId = parseInt(params.id as string);
  const MAX_RECORDING_TIME = 30; // 30 seconds max

  const fetchExercise = useCallback(async () => {
    try {
      const data = await apiClient.get<Exercise>(`/exercises/${exerciseId}`);
      setExercise(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load exercise');
    }
  }, [exerciseId]);

  const fetchReferenceAudio = useCallback(async () => {
    try {
      const response = await fetch(`${apiClient.baseURL}/exercises/${exerciseId}/reference-audio`, {
        headers: apiClient.getAuthHeaders(),
      });
      
      if (response.ok) {
        const blob = await response.blob();
        const url = URL.createObjectURL(blob);
        setReferenceAudio(url);
      }
    } catch (err) {
      console.error('Failed to load reference audio:', err);
    }
  }, [exerciseId]);

  useEffect(() => {
    if (user?.role !== 'STUDENT') {
      router.push('/login');
      return;
    }
    fetchExercise();
    fetchReferenceAudio();
  }, [user, router, exerciseId, fetchExercise, fetchReferenceAudio]);

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaRecorderRef.current = new MediaRecorder(stream);
      audioChunksRef.current = [];
      setRecordingTime(0);

      mediaRecorderRef.current.ondataavailable = (event) => {
        audioChunksRef.current.push(event.data);
      };

      mediaRecorderRef.current.onstop = async () => {
        const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/wav' });
        const audioUrl = URL.createObjectURL(audioBlob);
        setRecordedAudio(audioUrl);
        
        // Stop all tracks
        stream.getTracks().forEach(track => track.stop());
        
        // Clear timer
        if (recordingTimerRef.current) {
          clearInterval(recordingTimerRef.current);
        }
      };

      mediaRecorderRef.current.start();
      setIsRecording(true);

      // Start timer
      recordingTimerRef.current = setInterval(() => {
        setRecordingTime(prev => {
          if (prev >= MAX_RECORDING_TIME) {
            stopRecording();
            return prev;
          }
          return prev + 1;
        });
      }, 1000);
    } catch {
      setError('Failed to access microphone. Please grant permission.');
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      setIsRecording(false);
    }
  };

  const playRecordedAudio = () => {
    if (recordedAudioRef.current) {
      setIsPlayingRecorded(true);
      recordedAudioRef.current.play();
      recordedAudioRef.current.onended = () => setIsPlayingRecorded(false);
    }
  };

  const playReferenceAudio = () => {
    if (referenceAudioRef.current) {
      setIsPlayingReference(true);
      referenceAudioRef.current.play();
      referenceAudioRef.current.onended = () => setIsPlayingReference(false);
    }
  };

  const submitPronunciation = async (audioBlob: Blob) => {
    setIsProcessing(true);
    setError('');
    try {
      const audioFile = new File([audioBlob], 'recording.wav', { type: 'audio/wav' });
      const data = await apiClient.upload<PronunciationResult>(
        `/exercises/${exerciseId}/submit-pronunciation`,
        audioFile,
      );
      setResult(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to submit pronunciation');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleBack = () => {
    router.push(`/student/lessons/${exercise?.lesson_id}`);
  };

  const handleRetry = () => {
    setResult(null);
    setError('');
    setRecordedAudio(null);
    setRecordingTime(0);
  };

  if (!exercise) {
    return <ExerciseSkeleton />;
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
            <span>Back to Lesson</span>
          </button>
          <h1 className="text-2xl font-bold text-gray-900">{exercise.type} Exercise</h1>
          <div className="w-20" />
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-6">
            {error}
          </div>
        )}

        {/* Exercise Content */}
        <div className="bg-white rounded-xl shadow-md p-8 mb-6">
          <div className="flex items-center justify-between mb-4">
            <span className="text-2xl">
              {exercise.type === 'PHONEME' && '🔊'}
              {exercise.type === 'WORD' && '📝'}
              {exercise.type === 'SENTENCE' && '💬'}
              {exercise.type === 'PARAGRAPH' && '📄'}
            </span>
            <span className="text-sm text-gray-600">Difficulty: {exercise.difficulty}</span>
          </div>

          <h2 className="text-3xl font-bold text-gray-900 mb-6 text-center">
            {exercise.content}
          </h2>

          {/* Reference Audio */}
          {referenceAudio && (
            <div className="mb-6">
              <p className="text-sm text-gray-600 mb-2">Listen to the pronunciation:</p>
              <div className="flex items-center gap-4">
                <button
                  onClick={playReferenceAudio}
                  disabled={isPlayingReference}
                  className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition disabled:opacity-50"
                >
                  {isPlayingReference ? 'Playing...' : '▶ Play Reference'}
                </button>
                <audio
                  ref={referenceAudioRef}
                  src={referenceAudio}
                  className="hidden"
                />
              </div>
            </div>
          )}

          {/* Recording Section */}
          {!result && (
            <div className="text-center">
              <p className="text-gray-600 mb-6">
                Record yourself saying the text above
              </p>

              {/* Recording Timer */}
              {isRecording && (
                <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
                  <div className="text-3xl font-bold text-red-600 mb-2">
                    {recordingTime}s / {MAX_RECORDING_TIME}s
                  </div>
                  <div className="w-full bg-red-200 rounded-full h-2">
                    <div
                      className="bg-red-600 h-2 rounded-full transition-all"
                      style={{ width: `${(recordingTime / MAX_RECORDING_TIME) * 100}%` }}
                    />
                  </div>
                </div>
              )}

              {!isRecording && !isProcessing && !recordedAudio && (
                <button
                  onClick={startRecording}
                  className="bg-red-600 text-white px-8 py-4 rounded-full text-lg font-semibold hover:bg-red-700 transition flex items-center gap-2 mx-auto"
                >
                  <span className="text-2xl">🎤</span>
                  Start Recording
                </button>
              )}

              {isRecording && (
                <button
                  onClick={stopRecording}
                  className="bg-gray-600 text-white px-8 py-4 rounded-full text-lg font-semibold hover:bg-gray-700 transition flex items-center gap-2 mx-auto animate-pulse"
                >
                  <span className="text-2xl">⏹️</span>
                  Stop Recording
                </button>
              )}

              {recordedAudio && !isRecording && (
                <div className="space-y-4">
                  <div className="flex items-center justify-center gap-4">
                    <button
                      onClick={playRecordedAudio}
                      disabled={isPlayingRecorded}
                      className="px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition disabled:opacity-50"
                    >
                      {isPlayingRecorded ? 'Playing...' : '▶ Play Recording'}
                    </button>
                    <audio
                      ref={recordedAudioRef}
                      src={recordedAudio}
                      className="hidden"
                    />
                  </div>
                  <div className="flex justify-center gap-4">
                    <button
                      onClick={() => submitPronunciation(new Blob(audioChunksRef.current, { type: 'audio/wav' }))}
                      className="bg-indigo-600 text-white px-6 py-3 rounded-lg hover:bg-indigo-700 transition"
                    >
                      ✓ Submit
                    </button>
                    <button
                      onClick={handleRetry}
                      className="bg-gray-600 text-white px-6 py-3 rounded-lg hover:bg-gray-700 transition"
                    >
                      🔄 Re-record
                    </button>
                  </div>
                </div>
              )}

              {isProcessing && (
                <div className="flex items-center justify-center gap-2">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" />
                  <span className="text-gray-600">Processing your pronunciation...</span>
                </div>
              )}
            </div>
          )}

          {/* Results Section */}
          {result && (
            <div className="space-y-6">
              <div className="bg-green-50 border border-green-200 rounded-xl p-6">
                <h3 className="text-xl font-semibold text-green-800 mb-4">Your Results</h3>
                
                <div className="grid grid-cols-3 gap-4 mb-4">
                  <div className="text-center">
                    <div className="text-3xl font-bold text-green-600">{result.score}</div>
                    <div className="text-sm text-gray-600">Overall Score</div>
                  </div>
                  <div className="text-center">
                    <div className="text-3xl font-bold text-blue-600">{result.accuracy}%</div>
                    <div className="text-sm text-gray-600">Accuracy</div>
                  </div>
                  <div className="text-center">
                    <div className="text-3xl font-bold text-purple-600">{result.fluency}%</div>
                    <div className="text-sm text-gray-600">Fluency</div>
                  </div>
                </div>

                <div className="bg-white rounded-lg p-4 mb-4">
                  <p className="text-sm text-gray-600 mb-1">What you said:</p>
                  <p className="text-lg font-semibold text-gray-900">{result.your_speech}</p>
                </div>

                <div className="bg-white rounded-lg p-4">
                  <p className="text-sm text-gray-600 mb-1">Feedback:</p>
                  <p className="text-gray-900">{result.feedback}</p>
                </div>
              </div>

              <div className="flex gap-4">
                <button
                  onClick={handleRetry}
                  className="flex-1 bg-indigo-600 text-white py-3 rounded-lg font-semibold hover:bg-indigo-700 transition"
                >
                  Try Again
                </button>
                <button
                  onClick={handleBack}
                  className="flex-1 bg-gray-200 text-gray-700 py-3 rounded-lg font-semibold hover:bg-gray-300 transition"
                >
                  Next Exercise
                </button>
              </div>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
