import React, { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { 
  Lock, Plus, Settings, LogOut, LayoutDashboard, ListTodo, 
  CheckCircle2, Circle, AlertCircle, Clock, Tag, Search, Filter,
  ChevronDown, ChevronRight, MoreHorizontal, Trash2, Edit, Calendar as CalendarIcon,
  Download, Upload, Shield
} from 'lucide-react';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Badge } from '../components/ui/badge';
import { useAuth } from '../contexts/AuthContext';
import { useVault } from '../contexts/VaultContext';
import { useNavigate } from 'react-router-dom';
import TaskModal from '../components/TaskModal';
import SettingsModal from '../components/SettingsModal';
import BackupModal from '../components/BackupModal';
import { toast } from 'sonner';
import { format } from 'date-fns';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '../components/ui/dropdown-menu';

const PRIORITY_CONFIG = {
  low: { label: 'Low', color: 'text-[#A1A1AA]', bg: 'bg-[#A1A1AA]/10', border: 'border-[#A1A1AA]/30' },
  medium: { label: 'Medium', color: 'text-[#F59E0B]', bg: 'bg-[#F59E0B]/10', border: 'border-[#F59E0B]/30' },
  high: { label: 'High', color: 'text-[#F97316]', bg: 'bg-[#F97316]/10', border: 'border-[#F97316]/30' },
  critical: { label: 'Critical', color: 'text-[#EF4444]', bg: 'bg-[#EF4444]/10', border: 'border-[#EF4444]/30' }
};

const Dashboard = () => {
  const { user, logout } = useAuth();
  const { 
    tasks, categories, lock, isUnlocked, hasPassword,
    updateTask, deleteTask, addSubtask
  } = useVault();
  const navigate = useNavigate();
  
  const [view, setView] = useState('dashboard');
  const [showTaskModal, setShowTaskModal] = useState(false);
  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [showBackupModal, setShowBackupModal] = useState(false);
  const [editingTask, setEditingTask] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterPriority, setFilterPriority] = useState('all');
  const [filterCategory, setFilterCategory] = useState('all');
  const [expandedTasks, setExpandedTasks] = useState(new Set());

  // Stats
  const stats = useMemo(() => {
    const countTasks = (taskList, completed = false) => {
      let count = 0;
      taskList.forEach(task => {
        if (completed ? task.completed : !task.completed) count++;
        if (task.subtasks?.length) count += countTasks(task.subtasks, completed);
      });
      return count;
    };

    const countByPriority = (priority) => {
      let count = 0;
      const countRecursive = (taskList) => {
        taskList.forEach(task => {
          if (task.priority === priority && !task.completed) count++;
          if (task.subtasks?.length) countRecursive(task.subtasks);
        });
      };
      countRecursive(tasks);
      return count;
    };

    const getOverdue = () => {
      let count = 0;
      const now = new Date();
      const checkOverdue = (taskList) => {
        taskList.forEach(task => {
          if (!task.completed && task.dueDate && new Date(task.dueDate) < now) count++;
          if (task.subtasks?.length) checkOverdue(task.subtasks);
        });
      };
      checkOverdue(tasks);
      return count;
    };

    return {
      total: countTasks(tasks, false) + countTasks(tasks, true),
      pending: countTasks(tasks, false),
      completed: countTasks(tasks, true),
      critical: countByPriority('critical'),
      high: countByPriority('high'),
      overdue: getOverdue()
    };
  }, [tasks]);

  // Filtered tasks
  const filteredTasks = useMemo(() => {
    return tasks.filter(task => {
      const matchesSearch = !searchQuery || 
        task.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        task.description?.toLowerCase().includes(searchQuery.toLowerCase());
      
      const matchesPriority = filterPriority === 'all' || task.priority === filterPriority;
      const matchesCategory = filterCategory === 'all' || task.category === filterCategory;
      
      return matchesSearch && matchesPriority && matchesCategory;
    });
  }, [tasks, searchQuery, filterPriority, filterCategory]);

  const handleLock = () => {
    lock();
    navigate('/');
  };

  const handleLogout = async () => {
    lock();
    await logout();
    navigate('/');
  };

  const toggleTaskCompletion = async (taskId, parentPath = []) => {
    const findTask = (taskList, path, idx = 0) => {
      if (path.length === 0) {
        return taskList.find(t => t.id === taskId);
      }
      const parent = taskList.find(t => t.id === path[idx]);
      if (!parent) return null;
      if (idx === path.length - 1) {
        return parent.subtasks?.find(st => st.id === taskId);
      }
      return findTask(parent.subtasks || [], path, idx + 1);
    };

    const task = findTask(tasks, parentPath);
    if (task) {
      await updateTask(taskId, { completed: !task.completed }, parentPath);
      toast.success(task.completed ? 'Task reopened' : 'Task completed');
    }
  };

  const toggleExpanded = (taskId) => {
    setExpandedTasks(prev => {
      const next = new Set(prev);
      if (next.has(taskId)) {
        next.delete(taskId);
      } else {
        next.add(taskId);
      }
      return next;
    });
  };

  const handleEditTask = (task) => {
    setEditingTask(task);
    setShowTaskModal(true);
  };

  const handleDeleteTask = async (taskId, parentPath = []) => {
    await deleteTask(taskId, parentPath);
    toast.success('Task deleted');
  };

  // Check vault status
  if (!isUnlocked && hasPassword) {
    navigate('/');
    return null;
  }

  // Task item component
  const TaskItem = ({ task, depth = 0, parentPath = [] }) => {
    const isExpanded = expandedTasks.has(task.id);
    const hasSubtasks = task.subtasks && task.subtasks.length > 0;
    const priorityConfig = PRIORITY_CONFIG[task.priority] || PRIORITY_CONFIG.medium;
    const isOverdue = !task.completed && task.dueDate && new Date(task.dueDate) < new Date();

    return (
      <div className="animate-fade-in">
        <div 
          className={`group task-card bg-[#0A0A0A] border border-[#27272A] rounded-lg p-4 ${
            depth > 0 ? 'ml-6 border-l-2 border-l-[#8B5CF6]/30' : ''
          }`}
        >
          <div className="flex items-start gap-3">
            {/* Expand/collapse button for subtasks */}
            {hasSubtasks ? (
              <button
                onClick={() => toggleExpanded(task.id)}
                className="mt-1 text-[#52525B] hover:text-white transition-colors"
              >
                {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
              </button>
            ) : (
              <div className="w-4" />
            )}

            {/* Completion checkbox */}
            <button
              data-testid={`task-toggle-${task.id}`}
              onClick={() => toggleTaskCompletion(task.id, parentPath)}
              className="mt-1 transition-transform hover:scale-110"
            >
              {task.completed ? (
                <CheckCircle2 className="w-5 h-5 text-[#10B981]" />
              ) : (
                <Circle className="w-5 h-5 text-[#52525B] hover:text-[#8B5CF6]" />
              )}
            </button>

            {/* Task content */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1">
                <h4 
                  className={`font-medium truncate ${
                    task.completed ? 'text-[#52525B] line-through' : 'text-white'
                  }`}
                >
                  {task.title}
                </h4>
                <Badge 
                  variant="outline" 
                  className={`text-[10px] ${priorityConfig.color} ${priorityConfig.bg} ${priorityConfig.border}`}
                >
                  {priorityConfig.label}
                </Badge>
                {isOverdue && (
                  <Badge variant="destructive" className="text-[10px]">
                    Overdue
                  </Badge>
                )}
              </div>

              {task.description && (
                <p className="text-sm text-[#A1A1AA] mb-2 line-clamp-2">{task.description}</p>
              )}

              <div className="flex items-center gap-3 text-xs text-[#52525B]">
                {task.category && (
                  <span className="flex items-center gap-1">
                    <Tag size={12} />
                    {task.category}
                  </span>
                )}
                {task.dueDate && (
                  <span className={`flex items-center gap-1 ${isOverdue ? 'text-[#EF4444]' : ''}`}>
                    <CalendarIcon size={12} />
                    {format(new Date(task.dueDate), 'MMM d')}
                  </span>
                )}
                {hasSubtasks && (
                  <span className="flex items-center gap-1">
                    <ListTodo size={12} />
                    {task.subtasks.filter(st => st.completed).length}/{task.subtasks.length}
                  </span>
                )}
              </div>
            </div>

            {/* Actions */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button className="p-1 text-[#52525B] hover:text-white opacity-0 group-hover:opacity-100 transition-opacity">
                  <MoreHorizontal size={18} />
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="bg-[#0A0A0A] border-[#27272A]">
                <DropdownMenuItem 
                  onClick={() => handleEditTask(task)}
                  className="text-[#A1A1AA] hover:text-white hover:bg-[#27272A] cursor-pointer"
                >
                  <Edit size={14} className="mr-2" /> Edit
                </DropdownMenuItem>
                <DropdownMenuItem 
                  onClick={() => {
                    setEditingTask({ parentId: task.id, parentPath: [...parentPath, task.id] });
                    setShowTaskModal(true);
                  }}
                  className="text-[#A1A1AA] hover:text-white hover:bg-[#27272A] cursor-pointer"
                >
                  <Plus size={14} className="mr-2" /> Add Subtask
                </DropdownMenuItem>
                <DropdownMenuItem 
                  onClick={() => handleDeleteTask(task.id, parentPath)}
                  className="text-[#EF4444] hover:text-white hover:bg-[#EF4444]/20 cursor-pointer"
                >
                  <Trash2 size={14} className="mr-2" /> Delete
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>

        {/* Subtasks */}
        <AnimatePresence>
          {isExpanded && hasSubtasks && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="space-y-2 mt-2"
            >
              {task.subtasks.map(subtask => (
                <TaskItem 
                  key={subtask.id} 
                  task={subtask} 
                  depth={depth + 1}
                  parentPath={[...parentPath, task.id]}
                />
              ))}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-[#050505]">
      {/* Sidebar */}
      <aside className="fixed left-0 top-0 h-full w-64 bg-[#0A0A0A] border-r border-[#27272A] p-6 hidden lg:block">
        {/* Logo */}
        <div className="flex items-center gap-3 mb-8">
          <div className="p-2 rounded-lg bg-[#8B5CF6]/20 border border-[#8B5CF6]/30">
            <Lock className="w-5 h-5 text-[#8B5CF6]" strokeWidth={1.5} />
          </div>
          <h1 className="font-mono text-lg font-bold text-white">Obsidian Vault</h1>
        </div>

        {/* Encryption indicator */}
        <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-[#050505] border border-[#27272A] mb-6">
          <div className="w-2 h-2 rounded-full bg-[#00FF94] encryption-indicator" />
          <span className="font-mono text-[10px] text-[#A1A1AA] tracking-widest uppercase">
            AES-256-GCM
          </span>
        </div>

        {/* Navigation */}
        <nav className="space-y-2 mb-8">
          <button
            data-testid="nav-dashboard"
            onClick={() => setView('dashboard')}
            className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg transition-colors ${
              view === 'dashboard' 
                ? 'bg-[#8B5CF6]/20 text-[#8B5CF6] border border-[#8B5CF6]/30' 
                : 'text-[#A1A1AA] hover:text-white hover:bg-white/5'
            }`}
          >
            <LayoutDashboard size={18} />
            <span className="font-medium">Dashboard</span>
          </button>
          <button
            data-testid="nav-tasks"
            onClick={() => setView('tasks')}
            className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg transition-colors ${
              view === 'tasks' 
                ? 'bg-[#8B5CF6]/20 text-[#8B5CF6] border border-[#8B5CF6]/30' 
                : 'text-[#A1A1AA] hover:text-white hover:bg-white/5'
            }`}
          >
            <ListTodo size={18} />
            <span className="font-medium">Tasks</span>
            {stats.pending > 0 && (
              <Badge className="ml-auto bg-[#8B5CF6] text-white text-xs">{stats.pending}</Badge>
            )}
          </button>
        </nav>

        {/* Categories */}
        <div className="mb-8">
          <h3 className="text-xs text-[#52525B] uppercase tracking-widest mb-3">Categories</h3>
          <div className="space-y-1">
            {categories.map(cat => (
              <button
                key={cat}
                onClick={() => {
                  setFilterCategory(cat);
                  setView('tasks');
                }}
                className={`w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-colors ${
                  filterCategory === cat ? 'bg-white/5 text-white' : 'text-[#A1A1AA] hover:text-white hover:bg-white/5'
                }`}
              >
                <Tag size={14} />
                {cat}
              </button>
            ))}
          </div>
        </div>

        {/* Bottom actions */}
        <div className="absolute bottom-6 left-6 right-6 space-y-2">
          <button
            data-testid="backup-btn"
            onClick={() => setShowBackupModal(true)}
            className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-[#A1A1AA] hover:text-white hover:bg-white/5 transition-colors"
          >
            <Shield size={18} />
            <span>Backup</span>
          </button>
          <button
            data-testid="settings-btn"
            onClick={() => setShowSettingsModal(true)}
            className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-[#A1A1AA] hover:text-white hover:bg-white/5 transition-colors"
          >
            <Settings size={18} />
            <span>Settings</span>
          </button>
          <button
            data-testid="lock-btn"
            onClick={handleLock}
            className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-[#A1A1AA] hover:text-white hover:bg-white/5 transition-colors"
          >
            <Lock size={18} />
            <span>Lock Vault</span>
          </button>
          <button
            data-testid="logout-btn"
            onClick={handleLogout}
            className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-[#EF4444] hover:bg-[#EF4444]/10 transition-colors"
          >
            <LogOut size={18} />
            <span>Logout</span>
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className="lg:ml-64 p-6 md:p-12">
        {/* Header */}
        <header className="flex items-center justify-between mb-8">
          <div>
            <h2 className="font-mono text-2xl md:text-3xl font-bold text-white mb-1">
              {view === 'dashboard' ? 'Dashboard' : 'Tasks'}
            </h2>
            <p className="text-[#A1A1AA]">
              {user?.name ? `Welcome back, ${user.name}` : 'Your encrypted task vault'}
            </p>
          </div>
          <Button
            data-testid="add-task-btn"
            onClick={() => {
              setEditingTask(null);
              setShowTaskModal(true);
            }}
            className="bg-[#8B5CF6] hover:bg-[#7C3AED] text-white btn-glow"
          >
            <Plus className="w-4 h-4 mr-2" />
            Add Task
          </Button>
        </header>

        {view === 'dashboard' ? (
          // Dashboard view with bento grid
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6">
            {/* Total tasks */}
            <div className="bg-[#0A0A0A] border border-[#27272A] rounded-xl p-6 hover:border-[#8B5CF6]/50 transition-colors">
              <div className="flex items-center justify-between mb-4">
                <ListTodo className="w-8 h-8 text-[#8B5CF6]" />
                <span className="font-mono text-3xl font-bold text-white">{stats.total}</span>
              </div>
              <p className="text-sm text-[#A1A1AA]">Total Tasks</p>
            </div>

            {/* Pending */}
            <div className="bg-[#0A0A0A] border border-[#27272A] rounded-xl p-6 hover:border-[#F59E0B]/50 transition-colors">
              <div className="flex items-center justify-between mb-4">
                <Clock className="w-8 h-8 text-[#F59E0B]" />
                <span className="font-mono text-3xl font-bold text-white">{stats.pending}</span>
              </div>
              <p className="text-sm text-[#A1A1AA]">Pending</p>
            </div>

            {/* Completed */}
            <div className="bg-[#0A0A0A] border border-[#27272A] rounded-xl p-6 hover:border-[#10B981]/50 transition-colors">
              <div className="flex items-center justify-between mb-4">
                <CheckCircle2 className="w-8 h-8 text-[#10B981]" />
                <span className="font-mono text-3xl font-bold text-white">{stats.completed}</span>
              </div>
              <p className="text-sm text-[#A1A1AA]">Completed</p>
            </div>

            {/* Critical */}
            <div className="bg-[#0A0A0A] border border-[#27272A] rounded-xl p-6 hover:border-[#EF4444]/50 transition-colors">
              <div className="flex items-center justify-between mb-4">
                <AlertCircle className="w-8 h-8 text-[#EF4444]" />
                <span className="font-mono text-3xl font-bold text-white">{stats.critical}</span>
              </div>
              <p className="text-sm text-[#A1A1AA]">Critical</p>
            </div>

            {/* Recent tasks - spans 2 columns */}
            <div className="md:col-span-2 bg-[#0A0A0A] border border-[#27272A] rounded-xl p-6">
              <h3 className="font-mono text-lg font-bold text-white mb-4">Recent Tasks</h3>
              <div className="space-y-3">
                {tasks.slice(0, 5).map(task => (
                  <div 
                    key={task.id}
                    className="flex items-center gap-3 p-3 rounded-lg bg-[#050505] border border-[#27272A] hover:border-[#8B5CF6]/30 transition-colors cursor-pointer"
                    onClick={() => handleEditTask(task)}
                  >
                    {task.completed ? (
                      <CheckCircle2 className="w-4 h-4 text-[#10B981] flex-shrink-0" />
                    ) : (
                      <Circle className="w-4 h-4 text-[#52525B] flex-shrink-0" />
                    )}
                    <span className={`flex-1 truncate ${task.completed ? 'text-[#52525B] line-through' : 'text-white'}`}>
                      {task.title}
                    </span>
                    <Badge 
                      variant="outline" 
                      className={`text-[10px] ${PRIORITY_CONFIG[task.priority]?.color} ${PRIORITY_CONFIG[task.priority]?.bg}`}
                    >
                      {PRIORITY_CONFIG[task.priority]?.label}
                    </Badge>
                  </div>
                ))}
                {tasks.length === 0 && (
                  <div className="text-center py-8">
                    <ListTodo className="w-12 h-12 text-[#27272A] mx-auto mb-3" />
                    <p className="text-[#52525B]">No tasks yet</p>
                    <Button
                      variant="ghost"
                      onClick={() => {
                        setEditingTask(null);
                        setShowTaskModal(true);
                      }}
                      className="mt-2 text-[#8B5CF6] hover:text-[#7C3AED]"
                    >
                      Create your first task
                    </Button>
                  </div>
                )}
              </div>
            </div>

            {/* Priority breakdown */}
            <div className="md:col-span-2 bg-[#0A0A0A] border border-[#27272A] rounded-xl p-6">
              <h3 className="font-mono text-lg font-bold text-white mb-4">By Priority</h3>
              <div className="space-y-3">
                {Object.entries(PRIORITY_CONFIG).map(([key, config]) => {
                  const count = tasks.filter(t => t.priority === key && !t.completed).length;
                  const percentage = stats.pending > 0 ? (count / stats.pending) * 100 : 0;
                  return (
                    <div key={key}>
                      <div className="flex items-center justify-between mb-1">
                        <span className={`text-sm ${config.color}`}>{config.label}</span>
                        <span className="font-mono text-sm text-white">{count}</span>
                      </div>
                      <div className="h-2 bg-[#27272A] rounded-full overflow-hidden">
                        <div 
                          className={`h-full ${config.bg.replace('/10', '')} transition-all duration-500`}
                          style={{ width: `${percentage}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        ) : (
          // Tasks list view
          <div>
            {/* Filters */}
            <div className="flex flex-col md:flex-row gap-4 mb-6">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#52525B]" />
                <Input
                  data-testid="search-input"
                  placeholder="Search tasks..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10 bg-[#0A0A0A] border-[#27272A] focus:border-[#8B5CF6]"
                />
              </div>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="outline" className="border-[#27272A] bg-[#0A0A0A] text-white hover:bg-white/5">
                    <Filter size={16} className="mr-2" />
                    Priority: {filterPriority === 'all' ? 'All' : PRIORITY_CONFIG[filterPriority]?.label}
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent className="bg-[#0A0A0A] border-[#27272A]">
                  <DropdownMenuItem 
                    onClick={() => setFilterPriority('all')}
                    className="text-[#A1A1AA] hover:text-white hover:bg-[#27272A] cursor-pointer"
                  >
                    All
                  </DropdownMenuItem>
                  {Object.entries(PRIORITY_CONFIG).map(([key, config]) => (
                    <DropdownMenuItem 
                      key={key}
                      onClick={() => setFilterPriority(key)}
                      className={`${config.color} hover:bg-[#27272A] cursor-pointer`}
                    >
                      {config.label}
                    </DropdownMenuItem>
                  ))}
                </DropdownMenuContent>
              </DropdownMenu>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="outline" className="border-[#27272A] bg-[#0A0A0A] text-white hover:bg-white/5">
                    <Tag size={16} className="mr-2" />
                    Category: {filterCategory === 'all' ? 'All' : filterCategory}
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent className="bg-[#0A0A0A] border-[#27272A]">
                  <DropdownMenuItem 
                    onClick={() => setFilterCategory('all')}
                    className="text-[#A1A1AA] hover:text-white hover:bg-[#27272A] cursor-pointer"
                  >
                    All
                  </DropdownMenuItem>
                  {categories.map(cat => (
                    <DropdownMenuItem 
                      key={cat}
                      onClick={() => setFilterCategory(cat)}
                      className="text-[#A1A1AA] hover:text-white hover:bg-[#27272A] cursor-pointer"
                    >
                      {cat}
                    </DropdownMenuItem>
                  ))}
                </DropdownMenuContent>
              </DropdownMenu>
            </div>

            {/* Task list */}
            <div className="space-y-3">
              {filteredTasks.map(task => (
                <TaskItem key={task.id} task={task} />
              ))}
              {filteredTasks.length === 0 && (
                <div className="text-center py-12">
                  <ListTodo className="w-16 h-16 text-[#27272A] mx-auto mb-4" />
                  <h3 className="font-mono text-xl text-white mb-2">No tasks found</h3>
                  <p className="text-[#52525B] mb-4">
                    {searchQuery || filterPriority !== 'all' || filterCategory !== 'all'
                      ? 'Try adjusting your filters'
                      : 'Create your first task to get started'}
                  </p>
                  <Button
                    onClick={() => {
                      setEditingTask(null);
                      setShowTaskModal(true);
                    }}
                    className="bg-[#8B5CF6] hover:bg-[#7C3AED] text-white btn-glow"
                  >
                    <Plus className="w-4 h-4 mr-2" />
                    Add Task
                  </Button>
                </div>
              )}
            </div>
          </div>
        )}
      </main>

      {/* Modals */}
      <TaskModal
        open={showTaskModal}
        onClose={() => {
          setShowTaskModal(false);
          setEditingTask(null);
        }}
        task={editingTask}
      />
      <SettingsModal
        open={showSettingsModal}
        onClose={() => setShowSettingsModal(false)}
      />
      <BackupModal
        open={showBackupModal}
        onClose={() => setShowBackupModal(false)}
      />

      {/* Mobile nav */}
      <nav className="lg:hidden fixed bottom-0 left-0 right-0 bg-[#0A0A0A] border-t border-[#27272A] p-4">
        <div className="flex items-center justify-around">
          <button
            onClick={() => setView('dashboard')}
            className={`p-3 rounded-lg ${view === 'dashboard' ? 'bg-[#8B5CF6]/20 text-[#8B5CF6]' : 'text-[#52525B]'}`}
          >
            <LayoutDashboard size={24} />
          </button>
          <button
            onClick={() => setView('tasks')}
            className={`p-3 rounded-lg ${view === 'tasks' ? 'bg-[#8B5CF6]/20 text-[#8B5CF6]' : 'text-[#52525B]'}`}
          >
            <ListTodo size={24} />
          </button>
          <button
            onClick={() => {
              setEditingTask(null);
              setShowTaskModal(true);
            }}
            className="p-3 rounded-full bg-[#8B5CF6] text-white btn-glow"
          >
            <Plus size={24} />
          </button>
          <button
            onClick={() => setShowSettingsModal(true)}
            className="p-3 rounded-lg text-[#52525B]"
          >
            <Settings size={24} />
          </button>
          <button
            onClick={handleLock}
            className="p-3 rounded-lg text-[#52525B]"
          >
            <Lock size={24} />
          </button>
        </div>
      </nav>
    </div>
  );
};

export default Dashboard;
