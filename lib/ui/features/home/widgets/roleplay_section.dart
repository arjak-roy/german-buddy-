import 'package:flutter/material.dart';

import '../../agentic/screens/tic_tac_toe_screen.dart';
import '../../agentic/screens/bread_shop_screen.dart';
import 'roleplay_card.dart';

class _ScenarioItem {
  final String title;
  final String subtitle;
  final String image;
  final WidgetBuilder? pageBuilder;

  const _ScenarioItem({
    required this.title,
    required this.subtitle,
    required this.image,
    this.pageBuilder,
  });
}

class RoleplaySection extends StatefulWidget {
  final bool useGrid;
  final bool showCategoryTabs;
  final bool showHeader;

  const RoleplaySection({
    this.useGrid = false,
    this.showCategoryTabs = false,
    this.showHeader = true,
    super.key,
  });

  @override
  State<RoleplaySection> createState() => _RoleplaySectionState();
}

class _RoleplaySectionState extends State<RoleplaySection> {
  bool _showAgentic = false;

  final List<_ScenarioItem> _roleplayItems = const [
    _ScenarioItem(
      title: 'In der Bäckerei',
      subtitle: 'Order bread and pastries',
      image: 'lib/assets/Bakery.png',
    ),
    _ScenarioItem(
      title: 'Am Bahnhof',
      subtitle: 'Find your train',
      image: 'lib/assets/RailwayStation.png',
    ),
    _ScenarioItem(
      title: 'Im Restaurant',
      subtitle: 'Order your meal',
      image: 'lib/assets/Restaurant.png',
    ),
  ];

  final List<_ScenarioItem> _agenticItems = const [
    _ScenarioItem(
      title: 'Agentic AI Bakery',
      subtitle: 'Negotiate bread prices',
      image: 'https://source.unsplash.com/900x700/?bakery,bread,pastry',
      pageBuilder: _buildBreadShopPage,
    ),
    _ScenarioItem(
      title: 'Escape the Room',
      subtitle: 'Solve puzzles as an agent',
      image: 'https://source.unsplash.com/900x700/?escape,room,puzzle',
    ),
    _ScenarioItem(
      title: 'Spy Mission',
      subtitle: 'Infiltrate a base',
      image: 'https://source.unsplash.com/900x700/?spy,agent,night',
    ),
    _ScenarioItem(
      title: 'Agentic AI Tic-Tac-Toe',
      subtitle: 'Play by speaking English or German',
      image: 'https://source.unsplash.com/900x700/?tic,tac,toe,game',
      pageBuilder: _buildTicTacToePage,
    ),
  ];

  static Widget _buildBreadShopPage(BuildContext context) {
    return const BreadShopScreen();
  }

  static Widget _buildTicTacToePage(BuildContext context) {
    return const TicTacToeScreen();
  }

  @override
  Widget build(BuildContext context) {
    final items = _showAgentic ? _agenticItems : _roleplayItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.showHeader)
                const Text(
                  'Roleplay Scenarios',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                )
              else
                const SizedBox.shrink(),
              if (widget.showHeader)
                Text(
                  'See all',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
        if (widget.showCategoryTabs) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Roleplay'),
                  selected: !_showAgentic,
                  onSelected: (_) {
                    if (_showAgentic) {
                      setState(() => _showAgentic = false);
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Agentic'),
                  selected: _showAgentic,
                  onSelected: (_) {
                    if (!_showAgentic) {
                      setState(() => _showAgentic = true);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (widget.useGrid) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return RoleplayCard(
                  title: item.title,
                  subtitle: item.subtitle,
                  imageUrl: item.image,
                  onTap: () => _openScenario(item),
                  margin: EdgeInsets.zero,
                );
              },
            ),
          ),
        ] else ...[
          SizedBox(
            height: 140,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return RoleplayCard(
                  title: item.title,
                  subtitle: item.subtitle,
                  imageUrl: item.image,
                  onTap: () => _openScenario(item),
                  margin: const EdgeInsets.only(right: 12),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _openScenario(_ScenarioItem item) {
    if (item.pageBuilder == null) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: item.pageBuilder!));
  }
}
