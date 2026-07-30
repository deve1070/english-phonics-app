import { z } from 'zod';

export const loginSchema = z.object({
  phone_number: z.string().min(10, 'Phone number must be at least 10 characters'),
});

export type LoginFormData = z.infer<typeof loginSchema>;

export const registerSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  phone_number: z.string().min(10, 'Phone number must be at least 10 characters'),
  child_name: z.string().min(2, 'Child name must be at least 2 characters'),
  child_user_name: z.string().min(3, 'Child username must be at least 3 characters'),
  child_nickname: z.string().optional(),
});

export type RegisterFormData = z.infer<typeof registerSchema>;
