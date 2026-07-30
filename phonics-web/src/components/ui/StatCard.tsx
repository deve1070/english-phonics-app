import React from 'react';

interface StatCardProps {
  label: string;
  value: string | number;
  icon?: string;
  className?: string;
}

export function StatCard({ label, value, icon, className = '' }: StatCardProps) {
  return (
    <div className={`bg-white rounded-xl shadow-md p-6 ${className}`}>
      <div className="text-gray-600 mb-2">{label}</div>
      <div className="text-3xl font-bold text-indigo-600 flex items-center gap-2">
        {icon && <span>{icon}</span>}
        {value}
      </div>
    </div>
  );
}
