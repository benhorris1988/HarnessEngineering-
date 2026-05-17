import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'api/api_client.dart';
import 'screens/agent_run_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/new_incident_screen.dart';
import 'screens/work_item_detail_screen.dart';
import 'screens/work_items_screen.dart';
import 'theme/app_theme.dart';

class HarnessApp extends StatefulWidget {
  const HarnessApp({super.key});

  @override
  State<HarnessApp> createState() => _HarnessAppState();
}

class _HarnessAppState extends State<HarnessApp> {
  late final ApiClient _api = ApiClient();
  late final GoRouter _router = _buildRouter();

  GoRouter _buildRouter() {
    return GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              _Shell(api: _api, location: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => DashboardScreen(api: _api),
            ),
            GoRoute(
              path: '/work-items',
              builder: (_, __) => WorkItemsScreen(api: _api),
            ),
            GoRoute(
              path: '/work-items/new',
              builder: (_, __) => NewIncidentScreen(api: _api),
            ),
            GoRoute(
              path: '/work-items/:id',
              builder: (_, state) => WorkItemDetailScreen(
                api: _api,
                workItemId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/runs/:id',
              builder: (_, state) => AgentRunScreen(
                api: _api,
                runId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Harness Engineering',
      debugShowCheckedModeBanner: false,
      theme: buildHarnessTheme(),
      routerConfig: _router,
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.api, required this.location, required this.child});
  final ApiClient api;
  final String location;
  final Widget child;

  static const _items = <_NavItem>[
    _NavItem(icon: Icons.dashboard_outlined, label: 'Overview', path: '/'),
    _NavItem(icon: Icons.bug_report_outlined, label: 'Work items', path: '/work-items'),
    _NavItem(icon: Icons.add_circle_outline, label: 'New incident', path: '/work-items/new'),
  ];

  bool _isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.precision_manufacturing_outlined,
                color: Colors.white),
            const SizedBox(width: 10),
            Text(
              'Harness Engineering',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 24),
            Text(
              'agentic DevOps assistant',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
      drawer: wide ? null : _drawer(context),
      body: Row(
        children: [
          if (wide) _SideNav(location: location, items: _items),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _drawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: _SideNav(location: location, items: _items, inDrawer: true),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.path});
  final IconData icon;
  final String label;
  final String path;
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.location,
    required this.items,
    this.inDrawer = false,
  });

  final String location;
  final List<_NavItem> items;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView(
        children: items.map((item) {
          final selected = location == item.path ||
              (item.path != '/' && location.startsWith(item.path));
          return ListTile(
            leading: Icon(item.icon,
                color: selected ? Colors.white : Colors.white60),
            title: Text(
              item.label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            selected: selected,
            selectedTileColor: const Color(0xFF1F2937),
            onTap: () {
              if (inDrawer) Navigator.of(context).pop();
              GoRouter.of(context).go(item.path);
            },
          );
        }).toList(),
      ),
    );
  }
}
