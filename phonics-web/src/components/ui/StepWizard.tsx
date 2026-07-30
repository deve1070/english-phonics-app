'use client';

import React, { useState, ReactNode } from 'react';

interface Step {
  title: string;
  render: (props: StepProps) => ReactNode;
}

export interface StepProps {
  onNext: (data: Record<string, unknown>) => void;
  onBack: () => void;
  isLastStep: boolean;
  isFirstStep: boolean;
  formData: Record<string, unknown>;
}

interface StepWizardProps {
  steps: Step[];
  onComplete: (data: Record<string, unknown>) => void;
}

export function StepWizard({ steps, onComplete }: StepWizardProps) {
  const [currentStep, setCurrentStep] = useState(0);
  const [formData, setFormData] = useState<Record<string, unknown>>({});

  const handleNext = (stepData: Record<string, unknown>) => {
    const newData = { ...formData, ...stepData };
    setFormData(newData);

    if (currentStep < steps.length - 1) {
      setCurrentStep(currentStep + 1);
    } else {
      onComplete(newData);
    }
  };

  const handleBack = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1);
    }
  };

  const currentStepData = steps[currentStep];

  return (
    <div>
      {/* Progress Indicator */}
      <div className="mb-8">
        <div className="flex items-center justify-between">
          {steps.map((step, index) => (
            <div key={index} className="flex items-center flex-1">
              <div
                className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold ${
                  index <= currentStep
                    ? 'bg-indigo-600 text-white'
                    : 'bg-gray-200 text-gray-600'
                }`}
              >
                {index + 1}
              </div>
              {index < steps.length - 1 && (
                <div
                  className={`flex-1 h-1 mx-2 ${
                    index < currentStep ? 'bg-indigo-600' : 'bg-gray-200'
                  }`}
                />
              )}
            </div>
          ))}
        </div>
        <div className="flex justify-between mt-2">
          {steps.map((step, index) => (
            <div key={index} className="flex-1 text-center">
              <span
                className={`text-xs ${
                  index <= currentStep ? 'text-indigo-600' : 'text-gray-400'
                }`}
              >
                {step.title}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Current Step Content */}
      <div className="bg-white rounded-xl shadow-md p-8">
        {currentStepData.render({
          onNext: handleNext,
          onBack: handleBack,
          isLastStep: currentStep === steps.length - 1,
          isFirstStep: currentStep === 0,
          formData,
        })}
      </div>
    </div>
  );
}
