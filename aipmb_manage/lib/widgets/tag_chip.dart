import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  final String name;
  final String reasoning;
  final bool selected;

  const TagChip({
    super.key,
    required this.name,
    required this.reasoning,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: reasoning,
      child: Chip(
        label: Text(name),
        backgroundColor: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
    );
  }
}