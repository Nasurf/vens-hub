import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/presentation/screens/home/home_page/home_page.mobile.dart';
import 'package:vens_hub/presentation/screens/profile/profile_screen.dart';
import 'package:vens_hub/presentation/screens/schedule/schedule_page.mobile.dart';
import 'package:vens_hub/presentation/screens/hub/hub_page.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/themed_hub_icon.dart';
import 'package:vens_hub/presentation/widgets/home/bottom_navigationbar.dart';

class MobileMainScreen extends StatefulWidget {
  const MobileMainScreen({super.key});

  @override
  State<MobileMainScreen> createState() => _MobileMainScreenState();
}

class _MobileMainScreenState extends State<MobileMainScreen>
    with SingleTickerProviderStateMixin {
  final HomeController _homeController = Get.find<HomeController>();
  final List<Widget> _pages = [
    MobileHomePage(),
    MobileScheduleScreen(),
    MobileHubPage(),
    ProfileScreen(),
  ];
  late final PageController _pageController;
  late final Worker _pageNavigationWorker;
  late final AnimationController _drawerController;
  late final Animation<double> _drawerAnimation;
  bool _isWebDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    // Ensure HubController is available
    if (!Get.isRegistered<HubController>()) {
      Get.put(HubController());
    }

    _pageController = PageController(
      initialPage: _homeController.currentPage.value,
    );

    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _drawerAnimation = CurvedAnimation(
      parent: _drawerController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _homeController.setPageNavigationCallback((int pageIndex) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(pageIndex);
      }
    });

    _pageNavigationWorker = ever(_homeController.currentPage, (pageIndex) {
      if (_pageController.hasClients &&
          _pageController.page?.round() != pageIndex) {
        _pageController.jumpToPage(pageIndex);
      }
    });
  }

  @override
  void dispose() {
    _homeController.setPageNavigationCallback(null);
    _pageNavigationWorker.dispose();
    _pageController.dispose();
    _drawerController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    setState(() => _isWebDrawerOpen = !_isWebDrawerOpen);
    if (_isWebDrawerOpen) {
      _drawerController.forward();
    } else {
      _drawerController.reverse();
    }
  }

  void _closeDrawer() {
    if (_isWebDrawerOpen) {
      setState(() => _isWebDrawerOpen = false);
      _drawerController.reverse();
    }
  }

  void _selectPage(int index) {
    _closeDrawer();
    _homeController.currentPage.value = index;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool useWebDrawer = kIsWeb;

    return Scaffold(
      extendBody: !useWebDrawer,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                if (useWebDrawer) _buildWebTopBar(colorScheme),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      _homeController.currentPage.value = index;
                    },
                    physics: const ClampingScrollPhysics(),
                    children: _pages,
                  ),
                ),
              ],
            ),

            // Scrim overlay
            if (useWebDrawer)
              AnimatedBuilder(
                animation: _drawerAnimation,
                builder: (context, child) {
                  if (_drawerAnimation.value == 0) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: _closeDrawer,
                    child: Container(
                      color: Colors.black.withValues(
                        alpha: 0.4 * _drawerAnimation.value,
                      ),
                    ),
                  );
                },
              ),

            // Animated drawer
            if (useWebDrawer)
              AnimatedBuilder(
                animation: _drawerAnimation,
                builder: (context, child) {
                  // Drawer width is 320
                  final slideOffset = -320 * (1 - _drawerAnimation.value);
                  return Positioned(
                    top: 0,
                    bottom: 0,
                    left: slideOffset,
                    child: child!,
                  );
                },
                child: _WebMobileDrawer(
                  selectedIndex: _homeController.currentPage.value,
                  onSelect: _selectPage,
                  onClose: _closeDrawer,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar:
          useWebDrawer
              ? null
              : buildAppBottomNavigationBar(
                context,
                colorScheme,
                onTap: _selectPage,
              ),
    );
  }

  Widget _buildWebTopBar(ColorScheme colorScheme) {
    return Container(
      height: 64, // Taller header for modern look
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.1),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            tooltip: _isWebDrawerOpen ? 'Close menu' : 'Open menu',
            icon: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _drawerAnimation,
              color: colorScheme.onSurface,
            ),
            onPressed: _toggleDrawer,
          ),
          const SizedBox(width: 16),
          Text(
            'Engineering Hub',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebMobileDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;

  const _WebMobileDrawer({
    required this.selectedIndex,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final homeController = Get.find<HomeController>();

    return Material(
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      color:
          Colors
              .transparent, // For glassmorphism if we added blur, but keeping solid for performance/consistency
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          border: Border(
            right: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            // Modern Header with Gradient Mesh-like effect
            Obx(() {
              final user = homeController.currentUser.value;
              final String? photoUrl = user?.photoUrl;
              final String name =
                  '${user?.firstName ?? "User"} ${user?.lastName ?? ""}';
              final String email = user?.email ?? '';
              final String initials =
                  (user?.firstName.isNotEmpty == true)
                      ? user!.firstName[0].toUpperCase()
                      : 'U';

              return Container(
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primaryContainer, cs.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: cs.primary,
                            foregroundImage:
                                (photoUrl != null && photoUrl.isNotEmpty)
                                    ? NetworkImage(photoUrl)
                                    : null,
                            child:
                                (photoUrl == null || photoUrl.isEmpty)
                                    ? Text(
                                      initials,
                                      style: TextStyle(
                                        color: cs.onPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                      ),
                                    )
                                    : null,
                          ),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: onClose,
                          tooltip: 'Close menu',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                children: [
                  _NavTile(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: 'Home',
                    selected: selectedIndex == 0,
                    onTap: () => onSelect(0),
                  ),
                  _NavTile(
                    icon: Icons.calendar_month_outlined,
                    selectedIcon: Icons.calendar_month_rounded,
                    label: 'Schedule',
                    selected: selectedIndex == 1,
                    onTap: () => onSelect(1),
                  ),
                  _HubNavTile(
                    label: 'Hub',
                    selected: selectedIndex == 2,
                    onTap: () => onSelect(2),
                  ),
                  _NavTile(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person_rounded,
                    label: 'Profile',
                    selected: selectedIndex == 4,
                    onTap: () => onSelect(4),
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 20, color: cs.error),
                  const SizedBox(width: 12),
                  Text(
                    'Log Out',
                    style: TextStyle(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? cs.onPrimaryContainer : cs.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                if (selected) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cs.onPrimaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubNavTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HubNavTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                ThemedHubIcon(selected: selected, size: 24),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? cs.onPrimaryContainer : cs.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                if (selected) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cs.onPrimaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
