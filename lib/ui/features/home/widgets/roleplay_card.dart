import 'package:flutter/material.dart';

class RoleplayCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const RoleplayCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.margin,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isAssetImage =
        imageUrl.startsWith('assets/') || imageUrl.startsWith('lib/assets/');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 200,
          margin: margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isAssetImage)
                  Image.asset(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.blueGrey.shade300,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  )
                else
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return Container(
                        color: Colors.blueGrey.shade200,
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.blueGrey.shade300,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black26, Colors.black54],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
