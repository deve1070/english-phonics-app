'use client';

import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/lib/auth/context';
import { useForm } from 'react-hook-form';
import { registerSchema, type RegisterFormData } from '@/lib/validation/auth';
import { useToast } from '@/components/ui/Toast';
import { StepWizard } from '@/components/ui/StepWizard';
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';
import type { StepProps } from '@/components/ui/StepWizard';

export default function RegisterPage() {
  const router = useRouter();
  const { register: registerAuth } = useAuth();
  const { showToast } = useToast();

  const handleComplete = async (data: Record<string, unknown>) => {
    const result = registerSchema.safeParse(data);
    if (!result.success) {
      showToast('error', result.error.issues[0]?.message || 'Please check your details and try again.');
      return;
    }

    try {
      await registerAuth(result.data as RegisterFormData);
      router.push('/parent/dashboard');
      showToast('success', 'Account created successfully!');
    } catch (err) {
      showToast('error', err instanceof Error ? err.message : 'Registration failed');
    }
  };

  const steps = [
    {
      title: 'Parent Info',
      render: (props: StepProps) => (
        <ParentInfoStep {...props} />
      ),
    },
    {
      title: 'Child Info',
      render: (props: StepProps) => (
        <ChildInfoStep {...props} />
      ),
    },
  ];

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100 px-4 py-8">
      <div className="max-w-2xl w-full">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Create Account</h1>
          <p className="text-gray-600">Register as a parent and add your child</p>
        </div>

        <StepWizard steps={steps} onComplete={handleComplete} />

        <div className="mt-6 text-center">
          <p className="text-gray-600">
            Already have an account?{' '}
            <Link href="/login" className="text-indigo-600 hover:text-indigo-700 font-medium">
              Sign In
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}

function ParentInfoStep({ onNext, formData }: StepProps) {
  const { register, handleSubmit, formState: { errors } } = useForm({
    defaultValues: {
      name: formData.name as string || '',
      phone_number: formData.phone_number as string || '',
    },
  });

  const onSubmit = (data: Record<string, unknown>) => {
    onNext(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <h2 className="text-xl font-semibold text-gray-800 mb-4">Parent Information</h2>
      <Input
        label="Full Name"
        {...register('name', { required: 'Name is required' })}
        error={errors.name?.message as string}
        placeholder="Enter your full name"
      />
      <Input
        label="Phone Number"
        {...register('phone_number', { required: 'Phone number is required', minLength: { value: 10, message: 'Phone number must be at least 10 characters' } })}
        error={errors.phone_number?.message as string}
        type="tel"
        placeholder="Enter your phone number"
      />
      <Button type="submit" fullWidth>
        Next
      </Button>
    </form>
  );
}

function ChildInfoStep({ onNext, onBack, formData, isLastStep }: StepProps) {
  const { register, handleSubmit, formState: { errors } } = useForm({
    defaultValues: {
      child_name: formData.child_name as string || '',
      child_user_name: formData.child_user_name as string || '',
      child_nickname: formData.child_nickname as string || '',
    },
  });

  const onSubmit = (data: Record<string, unknown>) => {
    onNext(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <h2 className="text-xl font-semibold text-gray-800 mb-4">Child Information</h2>
      <Input
        label="Child's Name"
        {...register('child_name', { required: 'Child name is required' })}
        error={errors.child_name?.message as string}
        placeholder="Enter your child's name"
      />
      <Input
        label="Child's Username"
        {...register('child_user_name', { required: 'Child username is required', minLength: { value: 3, message: 'Username must be at least 3 characters' } })}
        error={errors.child_user_name?.message as string}
        placeholder="Create a username for your child (used to switch into their view)"
      />
      <Input
        label="Nickname (optional)"
        {...register('child_nickname')}
        placeholder="A pet name you'd like to see on the dashboard"
      />
      <div className="flex gap-4">
        <Button type="button" variant="secondary" onClick={onBack} fullWidth>
          Back
        </Button>
        <Button type="submit" fullWidth>
          {isLastStep ? 'Create Account' : 'Next'}
        </Button>
      </div>
    </form>
  );
}
