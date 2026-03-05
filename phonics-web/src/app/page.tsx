"use client";

import BookPageLayout from "@/components/BookPageLayout";
import Image from "next/image"; // For future illustrations

export default function LessonPage() {
  // In real app, fetch from backend (lesson id from params)
  return (
    <BookPageLayout
      unitNumber={1}
      unitLetters="Aa"
      unitColor="bg-green-600" // Change per unit (book uses green→purple→orange→red...)
      pageNumber={14}
    >
      {/* Activity Section A – Listen and repeat */}
      <div className="flex items-start gap-8">
        <div className="bg-green-500 text-white rounded-full w-20 h-20 flex-shrink-0 flex items-center justify-center text-5xl font-bold shadow-xl">
          A
        </div>
        <div className="flex-1">
          <h2 className="text-4xl font-bold text-gray-800 mb-6">
            Listen and repeat 🔊
          </h2>
          {/* Large central illustration placeholder */}
          <div className="bg-gradient-to-br from-green-200 to-green-100 rounded-3xl p-12 text-center shadow-2xl">
            <div className="text-9xl mb-12">A a</div>
            {/* Future: real illustration here */}
          </div>
        </div>
      </div>
      {/* Activity Section B – Point and say */}

      {/* Add more sections C, D, E as needed */}
    </BookPageLayout>
  );
}
