import 'package:flutter/material.dart';
import 'luxury_app_bar.dart';
import '../../services/auth_service.dart';

/// Centralized configuration for the unified AppBar across the entire application
class AppBarConfig {
  /// Creates a standard LuxuryAppBar with dynamic user greeting
  static Future<LuxuryAppBar> createStandardAppBar({
    required String title,
    String? subtitle,
    List<Widget>? actions,
    Widget? leading,
    bool showBackButton = true,
    VoidCallback? onBackPress,
    bool floating = false,
    ScrollController? scrollController,
  }) async {
    final greetingName = await AuthService.getGreetingName();
    final dynamicSubtitle = subtitle ?? 'Good evening, $greetingName';
    
    return LuxuryAppBar(
      title: title,
      subtitle: dynamicSubtitle,
      actions: actions,
      leading: leading,
      showBackButton: showBackButton,
      onBackPress: onBackPress,
      floating: floating,
      scrollController: scrollController,
    );
  }

  /// Standard actions for main navigation pages
  static List<Widget> getStandardActions(BuildContext context) {
    return [
      LuxuryAppBarAction(
        icon: Icons.notifications_outlined,
        onPressed: () {
          // Handle notifications
        },
      ),
      const SizedBox(width: 8),
      LuxuryAppBarAction(
        icon: Icons.settings_outlined,
        onPressed: () {
          Navigator.pushNamed(context, '/settings');
        },
      ),
    ];
  }

  /// Actions for data management pages
  static List<Widget> getDataActions({
    VoidCallback? onAdd,
    VoidCallback? onSearch,
    VoidCallback? onFilter,
  }) {
    final actions = <Widget>[];
    
    if (onSearch != null) {
      actions.add(
        LuxuryAppBarAction(
          icon: Icons.search_outlined,
          onPressed: onSearch,
        ),
      );
      if (onAdd != null || onFilter != null) {
        actions.add(const SizedBox(width: 8));
      }
    }
    
    if (onAdd != null) {
      actions.add(
        LuxuryAppBarAction(
          icon: Icons.add_outlined,
          onPressed: onAdd,
        ),
      );
      if (onFilter != null) {
        actions.add(const SizedBox(width: 8));
      }
    }
    
    if (onFilter != null) {
      actions.add(
        LuxuryAppBarAction(
          icon: Icons.filter_list_outlined,
          onPressed: onFilter,
        ),
      );
    }
    
    return actions;
  }
}