import React from 'react';

interface CardProps {
  children: React.ReactNode;
  className?: string;
  onClick?: () => void;
}

export function Card({ children, className = '', onClick }: CardProps) {
  return (
    <div
      className={`bg-white rounded-xl shadow-md p-6 ${onClick ? 'cursor-pointer hover:shadow-lg transition' : ''} ${className}`}
      onClick={onClick}
    >
      {children}
    </div>
  );
}
