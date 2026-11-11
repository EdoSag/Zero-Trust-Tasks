import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// Debounced search field for the tasks list (items 1 & 24).
class TaskSearchBar extends StatefulWidget {
  const TaskSearchBar({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<TaskSearchBar> createState() => _TaskSearchBarState();
}

class _TaskSearchBarState extends State<TaskSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      widget.onChanged(value);
    });
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _handleChanged,
      decoration: InputDecoration(
        hintText: context.l10n.searchTasksDescriptionsCategories,
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: context.l10n.clearSearch,
                onPressed: _clear,
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
