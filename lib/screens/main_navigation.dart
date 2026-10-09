import 'package:savora/client/home_screen.dart';
import 'package:savora/client/orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:savora/screens/favorites_screen.dart';
import 'my_reservations_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final supabase = Supabase.instance.client;

  int currentIndex = 0;

  int unreadNotifications = 0;

  RealtimeChannel? _notificationChannel;

  final List<Widget> pages = const [
    HomeScreen(),
    MyReservationsScreen(),
    ProfileScreen(),
    FavoritesScreen(),
    ClientOrdersScreen()
  ];

  @override
  void initState() {
    super.initState();

    _loadUnreadNotifications();
    _listenToNotifications();
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      supabase.removeChannel(_notificationChannel!);
    }

    super.dispose();
  }

  // ============================================================
  // CHARGER LES NOTIFICATIONS NON LUES
  // ============================================================

  Future<void> _loadUnreadNotifications() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      if (!mounted) return;

      setState(() {
        unreadNotifications = response.length;
      });
    } catch (e) {
      debugPrint(
        "ERREUR NOTIFICATIONS NON LUES : $e",
      );
    }
  }

  // ============================================================
  // ÉCOUTE EN TEMPS RÉEL
  // ============================================================

  void _listenToNotifications() {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    _notificationChannel = supabase
        .channel('user-notifications-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            _loadUnreadNotifications();
          },
        )
        .subscribe();
  }

  // ============================================================
  // OUVRIR LES NOTIFICATIONS
  // ============================================================

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>  NotificationsScreen(),
      ),
    );

    // Quand on revient de NotificationsScreen,
    // on actualise le badge.
    _loadUnreadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          pages[currentIndex],

          // ======================================================
          // BOUTON NOTIFICATIONS
          // ======================================================

          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 10,
                  right: 16,
                ),
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  shadowColor:
                      Colors.black.withOpacity(.12),
                  borderRadius:
                      BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(14),
                    onTap: _openNotifications,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.notifications_outlined,
                            color: Color(0xFF6D1B2B),
                            size: 25,
                          ),

                          // =================================================
                          // BADGE
                          // =================================================

                          if (unreadNotifications > 0)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: Container(
                                constraints:
                                    const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: Colors.red,
                                  borderRadius:
                                      BorderRadius.circular(
                                    20,
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    unreadNotifications > 99
                                        ? '99+'
                                        : unreadNotifications
                                            .toString(),
                                    style:
                                        const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ============================================================
      // NAVIGATION
      // ============================================================

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor:
            const Color(0xFF6D1B2B),
        unselectedItemColor:
            Colors.grey.shade500,

        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Accueil",
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.calendar_today_outlined,
            ),
            activeIcon: Icon(
              Icons.calendar_today,
            ),
            label: "Réservations",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Profil",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: "Favoris",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.takeout_dining),
            activeIcon: Icon(Icons.takeout_dining_outlined),
            label: "Mes commandes"
          )
        ],
      ),
    );
  }
}