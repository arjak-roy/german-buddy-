import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/home_app_bar.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/profile_provider.dart';
import '../widgets/roleplay_section.dart';
import '../widgets/home_mic_button.dart';
import '../widgets/pronunciation_section.dart';
import '../widgets/resources_section.dart';
import '../widgets/exercises_section.dart';
import '../../buddy/screens/buddy_screen.dart';
import '../../buddy/widgets/buddy_app_bar.dart';
import '../../profile/screens/profile_screen.dart';
import '../../pronunciation/screens/pronunciation_screen.dart';
import '../../roleplay/screens/roleplay_screen.dart';
import '../../../shared/widgets/theme_mode_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  bool _languageLevelDialogShown = false;

  PreferredSizeWidget _buildAppBar() {
    switch (_selectedIndex) {
      case 1:
        // roleplay page uses its own scaffold with app bar
        return const HomeAppBar();
      case 2:
        return const BuddyAppBar();
      case 3:
        return AppBar(
          title: const Text('Pronunciation Lab'),
          actions: const [ThemeModeButton()],
        );
      case 4:
        return AppBar(
          title: const Text('Profile'),
          actions: const [ThemeModeButton()],
        );
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
    // If leaving Buddy tab (2), stop TTS
    if (_selectedIndex == 2 && index != 2) {
      BuddyScreen.stopTtsIfActive();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _showGermanLevelDialog(String currentLevel) async {
    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Select German level',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation1, animation2) {
        final levels = ['A1', 'A2', 'B1', 'B2'];
        String localSelected = currentLevel;
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Material(
                color: Colors.transparent,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select your German level',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          ...levels.map(
                            (level) => RadioListTile<String>(
                              value: level,
                              groupValue: localSelected,
                              title: Text(level),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    localSelected = value;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(null),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(localSelected),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.90, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (selected != null && selected != currentLevel) {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        await ref
            .read(userProfileRepositoryProvider)
            .setLanguageLevel(user.id, selected);
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Map<String, dynamic>?>>(currentUserProfileProvider, (
      previous,
      next,
    ) async {
      if (_languageLevelDialogShown) return;
      final profile = next.asData?.value;
      if (profile == null) return;
      final level = (profile['languageLevel'] as String?)?.trim();
      if (level != null && level.isNotEmpty) {
        _languageLevelDialogShown = true;
        return;
      }
      _languageLevelDialogShown = true;
      await _showGermanLevelDialog(level ?? 'B1');
    });
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
          ),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.0, 0.08),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        ),
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
          ExercisesSection(),
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
