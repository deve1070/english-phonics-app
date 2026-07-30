import React from 'react';

interface ProgressBarProps {
  progress: number;
  label?: string;
  showPercentage?: boolean;
  className?: string;
}

export function ProgressBar({ progress, label, showPercentage = true, className = '' }: ProgressBarProps) {
  const clampedProgress = Math.min(100, Math.max(0, progress));

  return (
    <div className={className}>
      {label && (
        <div className="flex justify-between text-sm text-gray-600 mb-1">
          <span>{label}</span>
          {showPercentage && <span>{clampedProgress.toFixed(1)}%</span>}
        </div>
      )}
      <div className="w-full bg-gray-200 rounded-full h-2">
        <div
          className="bg-indigo-600 h-2 rounded-full transition-all"
          style={{ width: `${clampedProgress}%` }}
        />
      </div>
    </div>
  );
}
