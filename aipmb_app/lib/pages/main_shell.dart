import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            activeIcon: Icon(Icons.auto_awesome, size: 28),
            label: '此刻',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.travel_explore),
            activeIcon: Icon(Icons.travel_explore, size: 28),
            label: '探索',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person, size: 28),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
