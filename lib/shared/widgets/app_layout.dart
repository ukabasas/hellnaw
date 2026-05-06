import 'package:flutter/material.dart';
import 'package:nova3d_frontend/core/theme.dart';
import 'package:nova3d_frontend/shared/widgets/app_sidebar.dart';

class AppLayout extends StatelessWidget {
  const AppLayout({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final showSidebar = width >= 768;

    if (showSidebar) {
      return Scaffold(
        backgroundColor: kBgDark,
        body: Row(
          children: [
            const AppSidebar(),
            const VerticalDivider(color: kBorderColor, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // Mobile: drawer-based sidebar
    return _MobileLayout(child: child);
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBgDark,
        drawer: const Drawer(
          backgroundColor: kBgSecondary,
          child: AppSidebar(),
        ),
        appBar: AppBar(
          backgroundColor: kBgSecondary,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: kTextSecondary),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: const Text(
            'Nova3D',
            style: TextStyle(
              color: kTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: child,
      );
}
