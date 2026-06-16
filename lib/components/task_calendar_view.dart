import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:zero_trust_tasks/components/task_card.dart';
import 'package:zero_trust_tasks/models/task.dart';

/// Month-calendar view with due-date markers and a day-agenda list (item 34).
class TaskCalendarView extends StatefulWidget {
  const TaskCalendarView({super.key, required this.tasks});

  final List<Task> tasks;

  @override
  State<TaskCalendarView> createState() => _TaskCalendarViewState();
}

class _TaskCalendarViewState extends State<TaskCalendarView> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late Map<DateTime, List<Task>> _tasksByDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _normalise(DateTime.now());
    _buildTaskMap();
  }

  @override
  void didUpdateWidget(TaskCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      _buildTaskMap();
    }
  }

  static DateTime _normalise(DateTime d) => DateTime(d.year, d.month, d.day);

  void _buildTaskMap() {
    final map = <DateTime, List<Task>>{};
    for (final task in widget.tasks) {
      if (task.dueDate != null) {
        final key = _normalise(task.dueDate!);
        (map[key] ??= []).add(task);
      }
    }
    _tasksByDay = map;
  }

  List<Task> _tasksForDay(DateTime day) =>
      _tasksByDay[_normalise(day)] ?? const [];

  @override
  Widget build(BuildContext context) {
    final selectedTasks = _tasksForDay(_selectedDay);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        TableCalendar<Task>(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _tasksForDay,
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = _normalise(selectedDay);
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() => _focusedDay = focusedDay);
          },
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            markerSize: 5,
            markersMaxCount: 3,
            todayDecoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            selectedDecoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(color: colorScheme.onPrimary),
            outsideDaysVisible: false,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: selectedTasks.isEmpty
              ? Center(
                  child: Text(
                    'No tasks due on this day',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: selectedTasks.length,
                  itemBuilder: (context, index) =>
                      TaskCard(task: selectedTasks[index]),
                ),
        ),
      ],
    );
  }
}
