import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () {},
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'WunderbarAI',
                style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
              ),
              SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x1A2563EB),
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  child: Text(
                    'v0.0.1',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            'Speak. Learn. Repeat.',
            style: TextStyle(fontSize: 11, color: Colors.orangeAccent),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () {},
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
