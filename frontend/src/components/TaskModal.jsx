import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Lock, LockOpen } from 'lucide-react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Textarea } from './ui/textarea';
import { Label } from './ui/label';
import { Calendar } from './ui/calendar';
import { Popover, PopoverContent, PopoverTrigger } from './ui/popover';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from './ui/dialog';
import { useVault } from '../contexts/VaultContext';
import { toast } from 'sonner';
import { format } from 'date-fns';
import { Calendar as CalendarIcon } from 'lucide-react';
import { sanitizeText } from '../lib/sanitize';

const PRIORITIES = [
  { value: 'low', label: 'Low', color: 'text-[#A1A1AA]' },
  { value: 'medium', label: 'Medium', color: 'text-[#F59E0B]' },
  { value: 'high', label: 'High', color: 'text-[#F97316]' },
  { value: 'critical', label: 'Critical', color: 'text-[#EF4444]' }
];

const TaskModal = ({ open, onClose, task }) => {
  const { addTask, updateTask, addSubtask, categories, addCategory } = useVault();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showLockAnimation, setShowLockAnimation] = useState(false);
  
  const isEditing = task && !task.parentId;
  const isAddingSubtask = task?.parentId;
  
  const [form, setForm] = useState({
    title: '',
    description: '',
    priority: 'medium',
    category: '',
    dueDate: null,
    tags: []
  });
  
  const [newCategory, setNewCategory] = useState('');

  // Reset form when modal opens/closes
  useEffect(() => {
    if (open) {
      if (isEditing && task) {
        setForm({
          title: task.title || '',
          description: task.description || '',
          priority: task.priority || 'medium',
          category: task.category || '',
          dueDate: task.dueDate ? new Date(task.dueDate) : null,
          tags: task.tags || []
        });
      } else {
        setForm({
          title: '',
          description: '',
          priority: 'medium',
          category: '',
          dueDate: null,
          tags: []
        });
      }
    }
  }, [open, task, isEditing]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    const title = sanitizeText(form.title.trim());
    if (!title) {
      toast.error('Task title is required');
      return;
    }
    
    setIsSubmitting(true);
    setShowLockAnimation(true);
    
    try {
      const taskData = {
        title,
        description: sanitizeText(form.description),
        priority: form.priority,
        category: form.category,
        dueDate: form.dueDate?.toISOString() || null,
        tags: form.tags.map(t => sanitizeText(t))
      };
      
      if (isAddingSubtask) {
        await addSubtask(task.parentId, taskData, task.parentPath || []);
        toast.success('Subtask added');
      } else if (isEditing) {
        await updateTask(task.id, taskData);
        toast.success('Task updated');
      } else {
        await addTask(taskData);
        toast.success('Task created');
      }
      
      setTimeout(() => {
        setShowLockAnimation(false);
        onClose();
      }, 500);
    } catch (error) {
      console.error('Task error:', error);
      toast.error('Failed to save task');
      setShowLockAnimation(false);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleAddCategory = () => {
    if (newCategory.trim()) {
      addCategory(sanitizeText(newCategory.trim()));
      setForm(f => ({ ...f, category: newCategory.trim() }));
      setNewCategory('');
      toast.success('Category added');
    }
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="bg-[#0A0A0A] border-[#27272A] text-white max-w-lg glass">
        <DialogHeader>
          <DialogTitle className="font-mono text-xl">
            {isAddingSubtask ? 'Add Subtask' : isEditing ? 'Edit Task' : 'Create Task'}
          </DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4 mt-4">
          {/* Title */}
          <div>
            <Label className="text-[#A1A1AA] mb-2 block">Title *</Label>
            <Input
              data-testid="task-title-input"
              value={form.title}
              onChange={(e) => setForm(f => ({ ...f, title: e.target.value }))}
              placeholder="Enter task title"
              className="bg-black/50 border-[#27272A] focus:border-[#8B5CF6] text-white"
              maxLength={200}
            />
          </div>

          {/* Description */}
          <div>
            <Label className="text-[#A1A1AA] mb-2 block">Description</Label>
            <Textarea
              data-testid="task-description-input"
              value={form.description}
              onChange={(e) => setForm(f => ({ ...f, description: e.target.value }))}
              placeholder="Add a description (optional)"
              className="bg-black/50 border-[#27272A] focus:border-[#8B5CF6] text-white min-h-[80px] resize-none"
              maxLength={2000}
            />
          </div>

          {/* Priority & Category row */}
          <div className="grid grid-cols-2 gap-4">
            {/* Priority */}
            <div>
              <Label className="text-[#A1A1AA] mb-2 block">Priority</Label>
              <Select 
                value={form.priority} 
                onValueChange={(v) => setForm(f => ({ ...f, priority: v }))}
              >
                <SelectTrigger 
                  data-testid="task-priority-select"
                  className="bg-black/50 border-[#27272A] focus:border-[#8B5CF6] text-white"
                >
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className="bg-[#0A0A0A] border-[#27272A]">
                  {PRIORITIES.map(p => (
                    <SelectItem 
                      key={p.value} 
                      value={p.value}
                      className={`${p.color} hover:bg-[#27272A] cursor-pointer`}
                    >
                      {p.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Category */}
            <div>
              <Label className="text-[#A1A1AA] mb-2 block">Category</Label>
              <Select 
                value={form.category || 'none'} 
                onValueChange={(v) => setForm(f => ({ ...f, category: v === 'none' ? '' : v }))}
              >
                <SelectTrigger 
                  data-testid="task-category-select"
                  className="bg-black/50 border-[#27272A] focus:border-[#8B5CF6] text-white"
                >
                  <SelectValue placeholder="Select category" />
                </SelectTrigger>
                <SelectContent className="bg-[#0A0A0A] border-[#27272A]">
                  <SelectItem value="none" className="text-[#A1A1AA] hover:bg-[#27272A] cursor-pointer">
                    None
                  </SelectItem>
                  {categories.map(cat => (
                    <SelectItem 
                      key={cat} 
                      value={cat}
                      className="text-white hover:bg-[#27272A] cursor-pointer"
                    >
                      {cat}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* New category input */}
          <div className="flex gap-2">
            <Input
              value={newCategory}
              onChange={(e) => setNewCategory(e.target.value)}
              placeholder="Add new category..."
              className="bg-black/50 border-[#27272A] focus:border-[#8B5CF6] text-white text-sm"
              maxLength={50}
            />
            <Button
              type="button"
              variant="outline"
              onClick={handleAddCategory}
              disabled={!newCategory.trim()}
              className="border-[#27272A] text-white hover:bg-white/5 shrink-0"
            >
              Add
            </Button>
          </div>

          {/* Due Date */}
          <div>
            <Label className="text-[#A1A1AA] mb-2 block">Due Date</Label>
            <Popover>
              <PopoverTrigger asChild>
                <Button
                  data-testid="task-duedate-trigger"
                  variant="outline"
                  className="w-full justify-start text-left font-normal bg-black/50 border-[#27272A] text-white hover:bg-white/5"
                >
                  <CalendarIcon className="mr-2 h-4 w-4 text-[#52525B]" />
                  {form.dueDate ? format(form.dueDate, 'PPP') : <span className="text-[#52525B]">Pick a date</span>}
                </Button>
              </PopoverTrigger>
              <PopoverContent className="w-auto p-0 bg-[#0A0A0A] border-[#27272A]" align="start">
                <Calendar
                  mode="single"
                  selected={form.dueDate}
                  onSelect={(date) => setForm(f => ({ ...f, dueDate: date }))}
                  initialFocus
                  className="bg-[#0A0A0A] text-white"
                />
              </PopoverContent>
            </Popover>
          </div>

          {/* Actions */}
          <div className="flex gap-3 pt-4">
            <Button
              type="button"
              variant="outline"
              onClick={onClose}
              className="flex-1 border-[#27272A] text-white hover:bg-white/5"
            >
              Cancel
            </Button>
            <Button
              data-testid="task-submit-btn"
              type="submit"
              disabled={isSubmitting}
              className="flex-1 bg-[#8B5CF6] hover:bg-[#7C3AED] text-white btn-glow relative overflow-hidden"
            >
              <AnimatePresence mode="wait">
                {showLockAnimation ? (
                  <motion.span
                    key="locking"
                    initial={{ opacity: 0, scale: 0.8 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.8 }}
                    className="flex items-center gap-2"
                  >
                    <Lock className="w-4 h-4 lock-animate" />
                    Encrypting...
                  </motion.span>
                ) : (
                  <motion.span
                    key="save"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                  >
                    {isEditing ? 'Update Task' : 'Create Task'}
                  </motion.span>
                )}
              </AnimatePresence>
            </Button>
          </div>
        </form>

        {/* Encryption indicator */}
        <div className="mt-4 pt-4 border-t border-[#27272A] flex items-center justify-center gap-2 text-xs text-[#52525B]">
          <div className="w-2 h-2 rounded-full bg-[#00FF94] encryption-indicator" />
          <span className="font-mono">Data will be encrypted locally before saving</span>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default TaskModal;
