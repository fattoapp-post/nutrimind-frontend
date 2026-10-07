import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../core/chat_service.dart';
import '../../core/models.dart';
import '../../core/notification_service.dart';
import '../chat/conversations_screen.dart';
import '../nutritionist/patients_screen.dart';
import '../profile/profile_screen.dart';
import '../recipes/my_recipes_screen.dart';
import 'patient_shell.dart';

/// App del professionista: pazienti, messaggi, ricette e profilo.
/// Riusa [PatientShellScope] per far ricaricare le schede quando tornano
/// visibili (stessi indici: il profilo è sempre la scheda 3).
class NutritionistShell extends StatefulWidget {
  final Profile profile;

  const NutritionistShell({super.key, required this.profile});

  @override
  State<NutritionistShell> createState() => _NutritionistShellState();
}

abstract final class NutritionistTab {
  static const patients = 0;
  static const messages = 1;
  static const recipes = 2;
  static const profile = 3;
}

class _NutritionistShellState extends State<NutritionistShell> {

  final _tab = ValueNotifier<int>(NutritionistTab.patients);
  int _unread = 0;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
    // Ogni nuovo messaggio genera una notifica: aggiorna il badge
    _channel = NotificationService.subscribe(_refreshUnread);
    _tab.addListener(_refreshUnread);
  }

  @override
  void dispose() {
    NotificationService.unsubscribe(_channel);
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    try {
      final n = await ChatService.unreadCount();
      if (mounted) setState(() => _unread = n);
    } on AppError {
      // badge non essenziale
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watchTheme();
    return PatientShellScope(
      tab: _tab,
      child: ValueListenableBuilder<int>(
        valueListenable: _tab,
        builder: (context, index, _) => PopScope(
          canPop: index == NutritionistTab.patients,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _tab.value = NutritionistTab.patients;
          },
          child: Scaffold(
            body: IndexedStack(
              index: index,
              children: [
                PatientsScreen(profile: widget.profile),
                const ConversationsScreen(embedded: true, iAmNutritionist: true),
                const MyRecipesScreen(showReviewQueue: true, embedded: true),
                const ProfileScreen(embedded: true, showBottomNav: false),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              indicatorColor: primaryTeal.withValues(alpha: 0.15),
              onDestinationSelected: (i) => _tab.value = i,
              destinations: [
                const NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Pazienti'),
                NavigationDestination(
                  icon: Badge(isLabelVisible: _unread > 0, label: Text('$_unread'), child: const Icon(Icons.chat_bubble_outline)),
                  selectedIcon: Badge(isLabelVisible: _unread > 0, label: Text('$_unread'), child: const Icon(Icons.chat_bubble)),
                  label: 'Messaggi',
                ),
                const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Ricette'),
                const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profilo'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
