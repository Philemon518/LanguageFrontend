import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../progress/progress_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          HomeScreen(),
          LibraryScreen(embedded: true),
          ProgressScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded, color: AppTheme.green),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded, color: AppTheme.purple),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded, color: AppTheme.blue),
            label: 'Skills',
          ),
        ],
      ),
    );
  }
}
