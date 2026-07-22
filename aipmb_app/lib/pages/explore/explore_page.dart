import 'package:flutter/material.dart';
import 'package:aipmb_app/pages/explore/widgets/profile_tags_section.dart';
import 'package:aipmb_app/pages/explore/widgets/history_today_section.dart';
import 'package:aipmb_app/pages/explore/widgets/neighborhood_section.dart';
import 'package:aipmb_app/pages/explore/widgets/hidden_habits_section.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('探索', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: const [
          SizedBox(height: 4),
          ProfileTagsSection(),
          SizedBox(height: 24),
          HistoryTodaySection(),
          SizedBox(height: 24),
          NeighborhoodSection(),
          SizedBox(height: 24),
          HiddenHabitsSection(),
          SizedBox(height: 80),
        ],
      ),
    );
  }
}
