export function CardSkeleton() {
  return (
    <div className="bg-white rounded-xl shadow-md p-6 animate-pulse">
      <div className="flex items-center justify-between mb-4">
        <div className="h-8 w-24 bg-gray-200 rounded" />
        <div className="h-8 w-8 bg-gray-200 rounded-full" />
      </div>
      <div className="h-4 w-32 bg-gray-200 rounded mb-2" />
      <div className="h-3 w-24 bg-gray-200 rounded mb-4" />
      <div className="h-10 w-full bg-gray-200 rounded" />
    </div>
  );
}

export function DashboardSkeleton() {
  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-white shadow-sm h-16 mb-8" />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          {[1, 2, 3].map((i) => (
            <div key={i} className="bg-white rounded-xl shadow-md p-6 animate-pulse">
              <div className="h-4 w-24 bg-gray-200 rounded mb-2" />
              <div className="h-8 w-16 bg-gray-200 rounded" />
            </div>
          ))}
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <CardSkeleton key={i} />
          ))}
        </div>
      </div>
    </div>
  );
}

export function LessonsSkeleton() {
  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-white shadow-sm h-16 mb-8" />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <CardSkeleton key={i} />
          ))}
        </div>
      </div>
    </div>
  );
}

export function ExerciseSkeleton() {
  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-white shadow-sm h-16 mb-8" />
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-white rounded-xl shadow-md p-8 animate-pulse">
          <div className="h-8 w-32 bg-gray-200 rounded mb-4" />
          <div className="h-12 w-3/4 bg-gray-200 rounded mb-6 mx-auto" />
          <div className="h-16 w-full bg-gray-200 rounded mb-6" />
          <div className="h-12 w-48 bg-gray-200 rounded mx-auto" />
        </div>
      </div>
    </div>
  );
}
