'use client';

import { useEffect, useState, useRef, useCallback } from 'react';
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
  lesson_id: number;
}

interface AssessmentResult {
  score: number;
  is_passed: boolean;
  feedback_text?: string;
  recognized_text?: string;
}

export default function PhonemePracticePage() {
  const router = useRouter();
  const params = useParams();
  const { user } = useAuth();
  
  const [phoneme, setPhoneme] = useState<Phoneme | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  
  const [isRecording, setIsRecording] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [assessmentResult, setAssessmentResult] = useState<AssessmentResult | null>(null);
  
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);

  const phonemeId = parseInt(params.id as string);

  const fetchPhoneme = useCallback(async () => {
    try {
      const data = await apiClient.get<Phoneme>(`/phonemes/${phonemeId}`);
      setPhoneme(data);
      
      // Fetch audio as blob to handle authentication
      const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api/v1';
      const response = await fetch(`${API_BASE_URL}/phonemes/${phonemeId}/audio`, {
        headers: apiClient.getAuthHeaders(),
      });
      
      if (response.ok) {
        const blob = await response.blob();
        const url = URL.createObjectURL(blob);
        setAudioUrl(url);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load phoneme');
    } finally {
      setIsLoading(false);
    }
  }, [phonemeId]);

  useEffect(() => {
    if (user?.role !== 'STUDENT') {
      router.push('/login');
      return;
    }
    fetchPhoneme();
    
    return () => {
      // Cleanup object URL on unmount
      if (audioUrl) {
        URL.revokeObjectURL(audioUrl);
      }
    };
  }, [user, router, fetchPhoneme]);

  const handleBack = () => {
    if (phoneme?.lesson_id) {
      router.push(`/student/lessons/${phoneme.lesson_id}`);
    } else {
      router.push('/student/lessons');
    }
  };

  const playAudio = () => {
    if (audioRef.current && audioUrl) {
      setIsPlaying(true);
      audioRef.current.play().catch(e => {
        console.error("Audio playback failed", e);
        setIsPlaying(false);
      });
    }
  };

  const startRecording = async () => {
    setAssessmentResult(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;
      audioChunksRef.current = [];

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data);
        }
      };

      mediaRecorder.onstop = async () => {
        const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/webm' });
        const file = new File([audioBlob], "recording.webm", { type: 'audio/webm' });
        
        // Stop all tracks to release microphone
        stream.getTracks().forEach(track => track.stop());
        
        await submitRecording(file);
      };

      mediaRecorder.start();
      setIsRecording(true);
    } catch (err) {
      console.error("Error accessing microphone:", err);
      setError("Microphone access denied or not available.");
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      setIsRecording(false);
    }
  };

  const submitRecording = async (file: File) => {
    setIsSubmitting(true);
    try {
      const result = await apiClient.upload<AssessmentResult>(`/phonemes/${phonemeId}/submit-pronunciation`, file);
      setAssessmentResult(result);
    } catch (err) {
      console.error("Failed to submit pronunciation", err);
      setError(err instanceof Error ? err.message : 'Failed to assess pronunciation');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-xl animate-pulse text-indigo-600 font-semibold">Loading Sound...</div>
      </div>
    );
  }

  if (error && !phoneme) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-red-600 font-bold bg-red-100 px-6 py-4 rounded-xl border border-red-200">Error: {error}</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-indigo-50 to-white pb-12">
      {/* Hidden audio element */}
      {audioUrl && (
        <audio 
          ref={audioRef} 
          src={audioUrl} 
          onEnded={() => setIsPlaying(false)}
        />
      )}

      {/* Header */}
      <header className="bg-white/80 backdrop-blur-md sticky top-0 z-10 border-b border-indigo-100">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 py-4 flex items-center">
          <button
            onClick={handleBack}
            className="text-indigo-600 hover:text-indigo-800 flex items-center gap-2 font-semibold bg-indigo-50 px-4 py-2 rounded-full transition"
          >
            <span>←</span>
            <span>Back to Lesson</span>
          </button>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-2xl mx-auto px-4 pt-12 text-center">
        {/* Error banner for submission errors */}
        {error && phoneme && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl mb-6">
            {error}
            <button onClick={() => setError('')} className="ml-4 font-bold">×</button>
          </div>
        )}

        {/* Phoneme Symbol Display */}
        <div className="mb-12">
          <div className="inline-block bg-white rounded-3xl shadow-xl shadow-indigo-100 border border-indigo-50 p-16 relative overflow-hidden">
            <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-50 rounded-bl-full -mr-16 -mt-16 opacity-50"></div>
            <div className="absolute bottom-0 left-0 w-24 h-24 bg-purple-50 rounded-tr-full -ml-12 -mb-12 opacity-50"></div>
            
            <h1 className="text-8xl md:text-9xl font-extrabold text-indigo-600 tracking-tighter relative z-10">
              {phoneme?.symbol}
            </h1>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex flex-col sm:flex-row gap-6 justify-center items-center mb-12">
          {/* Play Button */}
          <button
            onClick={playAudio}
            disabled={!audioUrl || isPlaying || isRecording}
            className={`
              flex flex-col items-center justify-center gap-2 w-48 h-48 rounded-3xl shadow-lg transition transform hover:-translate-y-1
              ${!audioUrl ? 'bg-gray-200 cursor-not-allowed opacity-50' : 
                isPlaying ? 'bg-indigo-200 border-4 border-indigo-400' : 'bg-gradient-to-br from-indigo-400 to-indigo-600 hover:shadow-indigo-300/50'}
            `}
          >
            <div className={`text-6xl ${isPlaying ? 'animate-bounce' : ''}`}>
              🔊
            </div>
            <span className={`text-xl font-bold ${isPlaying ? 'text-indigo-800' : 'text-white'}`}>
              {isPlaying ? 'Playing...' : 'Listen'}
            </span>
          </button>

          {/* Record Button */}
          <button
            onClick={isRecording ? stopRecording : startRecording}
            disabled={isPlaying || isSubmitting}
            className={`
              flex flex-col items-center justify-center gap-2 w-48 h-48 rounded-3xl shadow-lg transition transform hover:-translate-y-1
              ${isSubmitting ? 'bg-gray-200 cursor-not-allowed' : 
                isRecording ? 'bg-red-500 animate-pulse border-4 border-red-700 hover:bg-red-600' : 'bg-gradient-to-br from-purple-400 to-purple-600 hover:shadow-purple-300/50'}
            `}
          >
            <div className="text-6xl">
              {isSubmitting ? '⏳' : isRecording ? '⏹️' : '🎤'}
            </div>
            <span className="text-xl font-bold text-white">
              {isSubmitting ? 'Checking...' : isRecording ? 'Stop' : 'Say It!'}
            </span>
          </button>
        </div>

        {/* Assessment Feedback */}
        {assessmentResult && (
          <div className={`p-8 rounded-3xl shadow-xl border-2 transform transition animate-fade-in-up ${
            assessmentResult.is_passed 
              ? 'bg-green-50 border-green-200 shadow-green-100' 
              : 'bg-orange-50 border-orange-200 shadow-orange-100'
          }`}>
            <div className="text-5xl mb-4">
              {assessmentResult.is_passed ? '🌟' : '💡'}
            </div>
            <h3 className={`text-3xl font-extrabold mb-2 ${
              assessmentResult.is_passed ? 'text-green-700' : 'text-orange-700'
            }`}>
              Score: {assessmentResult.score}%
            </h3>
            
            {assessmentResult.feedback_text && (
              <p className="text-lg text-gray-700 font-medium">
                {assessmentResult.feedback_text}
              </p>
            )}
            
            {!assessmentResult.is_passed && (
              <p className="text-gray-500 mt-4 text-sm font-medium">
                Tip: Listen to the sound again and give it another try!
              </p>
            )}
          </div>
        )}
      </main>
    </div>
  );
}
