import 'package:flutter/material.dart';

import '../widgets/home_app_bar.dart';
import '../widgets/roleplay_section.dart';
import '../widgets/home_mic_button.dart';
import '../widgets/pronunciation_section.dart';
import '../widgets/resources_section.dart';
import '../../buddy/screens/buddy_screen.dart';
import '../../buddy/widgets/buddy_app_bar.dart';
import '../../profile/screens/profile_screen.dart';
import '../../pronunciation/screens/pronunciation_screen.dart';
import '../../roleplay/screens/roleplay_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  PreferredSizeWidget _buildAppBar() {
    switch (_selectedIndex) {
      case 1:
        // roleplay page uses its own scaffold with app bar
        return const HomeAppBar();
      case 2:
        return const BuddyAppBar();
      case 3:
        return AppBar(title: const Text('Pronunciation Lab'));
      case 4:
        return AppBar(title: const Text('Profile'));
      default:
        return const HomeAppBar();
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 1:
        return const RoleplayScreen();
      case 2:
        // embedded version avoids nested scaffold
        return const BuddyScreen(embedded: true);
      case 3:
        return const PronunciationScreen(embedded: true);
      case 4:
        return const ProfileScreen();
      default:
        return _HomeContent(onMicTap: () => _onItemTapped(2));
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Roleplay',
          ),
          NavigationDestination(
            icon: const _BuddyNavIcon(selected: false),
            selectedIcon: const _BuddyNavIcon(selected: true),
            label: 'Buddy',
          ),
          const NavigationDestination(
            icon: Icon(Icons.record_voice_over_outlined),
            selectedIcon: Icon(Icons.record_voice_over_rounded),
            label: 'Pronounce',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// The actual long-scrolling home page content separated from the
/// navigation scaffolding to keep the stateful widget clean.
class _HomeContent extends StatelessWidget {
  final VoidCallback onMicTap;
  const _HomeContent({required this.onMicTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 12),
          RoleplaySection(),
          SizedBox(height: 24),
          Center(child: HomeMicButton(onTap: onMicTap)),
          SizedBox(height: 24),
          PronunciationSection(),
          SizedBox(height: 24),
          ResourcesSection(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BuddyNavIcon extends StatelessWidget {
  final bool selected;

  const _BuddyNavIcon({required this.selected});

  @override
  Widget build(BuildContext context) {
    final shadowColor = selected
        ? const Color(0x332563EB)
        : const Color(0x222563EB);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: selected ? 10 : 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        selected ? Icons.mic_rounded : Icons.mic_none_rounded,
        size: 20,
        color: Colors.white,
      ),
    );
  }
}
