import 'package:flutter/material.dart';

import '../../home/widgets/roleplay_section.dart';

/// A full-page version of the roleplay menu. For now it simply shows the
/// same horizontal scrollable cards that appear on the home page, plus a
/// title.
class RoleplayScreen extends StatelessWidget {
  const RoleplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roleplay Scenarios')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              RoleplaySection(
                useGrid: true,
                showCategoryTabs: true,
                showHeader: false,
              ),
              // additional content could go here later
            ],
          ),
        ),
      ),
    );
  }
}
