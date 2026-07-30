'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth/context';
import { apiClient } from '@/lib/api/client';
import { DashboardSkeleton } from '@/components/ui/LoadingSkeleton';
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';
import { useToast } from '@/components/ui/Toast';

// Matches backend ChildSummary exactly (schemas/schemas_parent.py).
// NOTE: there is no total_points/gamification field on the backend at
// all (no such model exists) - previously displayed a "Points" stat
// that was always undefined. Swapped for last_active, which the
// backend does provide.
interface ChildSummary {
  child_id: number;
  child_name: string;
  nickname?: string;
  lessons_completed: number;
  total_lessons: number;
  overall_progress_pct: number;
  minutes_today: number;
  max_daily_minutes: number;
  is_limit_reached: boolean;
  streak_days: number;
  last_active?: string;
}

// Matches backend ParentDashboardResponse exactly - no subscription
// concept exists on the backend (no subscriptions model at all).
interface DashboardData {
  parent_name: string;
  total_children: number;
  children: ChildSummary[];
}

function formatLastActive(iso?: string): string {
  if (!iso) return 'Never';
  const date = new Date(iso);
  const diffMs = Date.now() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d ago`;
}

export default function ParentDashboardPage() {
  const router = useRouter();
  const { user, logout, switchToChild, isLoading: isAuthLoading } = useAuth();
  const { showToast } = useToast();
  const [dashboardData, setDashboardData] = useState<DashboardData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState<'all' | 'active' | 'limit-reached'>('all');
  const [showAddChild, setShowAddChild] = useState(false);
  const [isAddingChild, setIsAddingChild] = useState(false);
  const [childName, setChildName] = useState('');
  const [childUserName, setChildUserName] = useState('');
  const [childNickname, setChildNickname] = useState('');

  useEffect(() => {
    if (isAuthLoading) return; // Wait for auth check to complete
    
    if (!user || user.role !== 'PARENT') {
      router.push('/login');
      return;
    }
    fetchDashboard();
  }, [user, isAuthLoading, router]);

  const fetchDashboard = async () => {
    try {
      const data = await apiClient.get<DashboardData>('/parents/dashboard');
      setDashboardData(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load dashboard');
    } finally {
      setIsLoading(false);
    }
  };

  const handleAddChild = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsAddingChild(true);
    try {
      await apiClient.post('/parents/children', {
        name: childName,
        user_name: childUserName,
        nickname: childNickname || undefined,
      });
      showToast('success', `${childName} was added!`);
      setChildName('');
      setChildUserName('');
      setChildNickname('');
      setShowAddChild(false);
      await fetchDashboard();
    } catch (err) {
      showToast('error', err instanceof Error ? err.message : 'Failed to add child');
    } finally {
      setIsAddingChild(false);
    }
  };

  const handleSwitchToChild = async (childId: number) => {
    try {
      await switchToChild(childId);
      router.push('/student/lessons');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to switch to child session');
    }
  };

  const handleLogout = () => {
    logout();
    router.push('/login');
  };

  const handleExport = () => {
    if (!dashboardData) return;
    
    const csvContent = [
      ['Child Name', 'Lessons Completed', 'Total Lessons', 'Progress %', 'Minutes Today', 'Streak Days', 'Last Active'],
      ...dashboardData.children.map(child => [
        child.nickname || child.child_name,
        child.lessons_completed,
        child.total_lessons,
        child.overall_progress_pct.toFixed(1),
        child.minutes_today.toFixed(0),
        child.streak_days,
        child.last_active || 'Never',
      ]),
    ].map(row => row.join(',')).join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `progress_report_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const getFilteredChildren = () => {
    if (!dashboardData) return [];
    
    switch (filter) {
      case 'active':
        return dashboardData.children.filter(child => !child.is_limit_reached);
      case 'limit-reached':
        return dashboardData.children.filter(child => child.is_limit_reached);
      default:
        return dashboardData.children;
    }
  };

  if (isLoading) {
    return <DashboardSkeleton />;
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-red-600">Error: {error}</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Parent Dashboard</h1>
            <p className="text-gray-600">Welcome, {dashboardData?.parent_name || user?.name}</p>
          </div>
          <button
            onClick={handleLogout}
            className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
          >
            Logout
          </button>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-6">
            {error}
          </div>
        )}

        {/* Children Grid */}
        <div className="mb-8">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-xl font-semibold text-gray-900">Your Children</h2>
            <button
              onClick={handleExport}
              className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition flex items-center gap-2"
            >
              <span>📊</span>
              <span>Export Report</span>
            </button>
          </div>

          {/* Filter Controls */}
          <div className="flex gap-2 mb-6">
            <button
              onClick={() => setFilter('all')}
              className={`px-4 py-2 rounded-lg transition ${
                filter === 'all' ? 'bg-indigo-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
              }`}
            >
              All
            </button>
            <button
              onClick={() => setFilter('active')}
              className={`px-4 py-2 rounded-lg transition ${
                filter === 'active' ? 'bg-indigo-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
              }`}
            >
              Active
            </button>
            <button
              onClick={() => setFilter('limit-reached')}
              className={`px-4 py-2 rounded-lg transition ${
                filter === 'limit-reached' ? 'bg-indigo-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
              }`}
            >
              Limit Reached
            </button>
          </div>
          
          {dashboardData?.children && dashboardData.children.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {getFilteredChildren().map((child) => (
                <div key={child.child_id} className="bg-white rounded-xl shadow-md p-6">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-semibold text-gray-900">
                      {child.nickname || child.child_name}
                    </h3>
                    <span className="text-2xl">👤</span>
                  </div>

                  {/* Progress Bar */}
                  <div className="mb-4">
                    <div className="flex justify-between text-sm text-gray-600 mb-1">
                      <span>Progress</span>
                      <span>{child.overall_progress_pct.toFixed(1)}%</span>
                    </div>
                    <div className="w-full bg-gray-200 rounded-full h-2">
                      <div
                        className="bg-indigo-600 h-2 rounded-full transition-all"
                        style={{ width: `${child.overall_progress_pct}%` }}
                      />
                    </div>
                  </div>

                  {/* Stats */}
                  <div className="grid grid-cols-2 gap-4 mb-4 text-sm">
                    <div className="bg-gray-50 rounded-lg p-3">
                      <div className="text-gray-600">Lessons</div>
                      <div className="text-xl font-bold text-indigo-600">
                        {child.lessons_completed}/{child.total_lessons}
                      </div>
                    </div>
                    <div className="bg-gray-50 rounded-lg p-3">
                      <div className="text-gray-600">Streak</div>
                      <div className="text-xl font-bold text-orange-600">{child.streak_days} days</div>
                    </div>
                    <div className="bg-gray-50 rounded-lg p-3">
                      <div className="text-gray-600">Today</div>
                      <div className="text-xl font-bold text-green-600">
                        {child.minutes_today.toFixed(0)}m
                      </div>
                    </div>
                    <div className="bg-gray-50 rounded-lg p-3">
                      <div className="text-gray-600">Last Active</div>
                      <div className="text-xl font-bold text-gray-700">
                        {formatLastActive(child.last_active)}
                      </div>
                    </div>
                  </div>

                  {/* Switch Button */}
                  <button
                    onClick={() => handleSwitchToChild(child.child_id)}
                    disabled={child.is_limit_reached}
                    className="w-full bg-indigo-600 text-white py-2 rounded-lg font-semibold hover:bg-indigo-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {child.is_limit_reached ? 'Daily Limit Reached' : 'Start Learning Session'}
                  </button>
                </div>
              ))}
            </div>
          ) : (
            <div className="bg-white rounded-xl shadow-md p-8 text-center">
              <p className="text-gray-600 mb-4">No children added yet</p>
            </div>
          )}
        </div>

        {/* Add Child Section */}
        <div className="bg-white rounded-xl shadow-md p-6">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-xl font-semibold text-gray-900">Add Another Child</h2>
            {!showAddChild && (
              <Button onClick={() => setShowAddChild(true)}>
                + Add Child
              </Button>
            )}
          </div>

          {showAddChild && (
            <form onSubmit={handleAddChild} className="space-y-4 max-w-md">
              <Input
                label="Child's Name"
                value={childName}
                onChange={(e) => setChildName(e.target.value)}
                placeholder="Enter your child's name"
                required
                minLength={2}
              />
              <Input
                label="Child's Username"
                value={childUserName}
                onChange={(e) => setChildUserName(e.target.value)}
                placeholder="Used to switch into their view"
                required
                minLength={3}
              />
              <Input
                label="Nickname (optional)"
                value={childNickname}
                onChange={(e) => setChildNickname(e.target.value)}
                placeholder="A pet name for the dashboard"
              />
              <div className="flex gap-4">
                <Button
                  type="button"
                  variant="secondary"
                  fullWidth
                  onClick={() => setShowAddChild(false)}
                  disabled={isAddingChild}
                >
                  Cancel
                </Button>
                <Button type="submit" fullWidth isLoading={isAddingChild}>
                  Add Child
                </Button>
              </div>
            </form>
          )}
        </div>
      </main>
    </div>
  );
}
