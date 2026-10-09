import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final supabase = Supabase.instance.client;
  RealtimeChannel? _notificationChannel;

  static const Color primaryColor = Color(0xFF6D1B2B);
  static const Color backgroundColor = Color(0xFFF7F7F8);

  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  bool isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _listenToNotifications();
    _setupFCM();
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      supabase.removeChannel(_notificationChannel!);
    }
    super.dispose();
  }

  // ============================================================
  // ENREGISTRER LE TOKEN FCM DANS SUPABASE
  // ============================================================

  Future<void> _setupFCM() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();

        if (token != null) {
          await supabase.from('push_tokens').upsert(
            {
              'user_id': user.id,
              'token': token,
              'device_type': kIsWeb ? 'web' : 'mobile',
            },
            onConflict: 'user_id, token',
          );
        }
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await supabase.from('push_tokens').upsert(
          {
            'user_id': user.id,
            'token': newToken,
            'device_type': kIsWeb ? 'web' : 'mobile',
          },
          onConflict: 'user_id, token',
        );
      });
    } catch (e) {
      debugPrint("ERREUR SETUP FCM : $e");
    }
  }

  // ============================================================
  // ECOUTER LES NOTIFICATIONS EN TEMPS RÉEL
  // ============================================================

  void _listenToNotifications() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _notificationChannel = supabase
        .channel('public:notifications:user_${user.id}')
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
            _loadNotifications();
          },
        )
        .subscribe();
  }

  // ============================================================
  // CHARGER LES NOTIFICATIONS
  // ============================================================

  Future<void> _loadNotifications() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        notifications = [];
        isLoading = false;
      });
      return;
    }

    try {
      final data = await supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        notifications = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("ERREUR NOTIFICATIONS : $e");
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showError("Impossible de charger les notifications.");
    }
  }

  // ============================================================
  // MARQUER COMME LUE
  // ============================================================

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final id = notification['id'];
    if (id == null) return;

    final isRead = notification['is_read'] == true;
    if (isRead) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);

      if (!mounted) return;

      setState(() {
        final index = notifications.indexWhere((item) => item['id'] == id);
        if (index != -1) {
          notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      debugPrint("ERREUR MARQUAGE NOTIFICATION : $e");
    }
  }

  // ============================================================
  // TOUT MARQUER COMME LU
  // ============================================================

  Future<void> _markAllAsRead() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final unreadExists = notifications.any((n) => n['is_read'] != true);
    if (!unreadExists) return;

    setState(() {
      isMarkingAll = true;
    });

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);

      if (!mounted) return;

      setState(() {
        for (final notification in notifications) {
          notification['is_read'] = true;
        }
        isMarkingAll = false;
      });
    } catch (e) {
      debugPrint("ERREUR TOUT MARQUER LU : $e");
      if (!mounted) return;

      setState(() {
        isMarkingAll = false;
      });

      _showError("Impossible de marquer les notifications.");
    }
  }

  // ============================================================
  // SUPPRIMER UNE NOTIFICATION
  // ============================================================

  Future<void> _deleteNotification(String id) async {
    try {
      await supabase.from('notifications').delete().eq('id', id);

      if (!mounted) return;

      setState(() {
        notifications.removeWhere(
          (notification) => notification['id'].toString() == id,
        );
      });
    } catch (e) {
      debugPrint("ERREUR SUPPRESSION NOTIFICATION : $e");
      _showError("Impossible de supprimer la notification.");
    }
  }

  // ============================================================
  // HELPER STYLES & DATES
  // ============================================================

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'reservation':
        return Icons.calendar_month_rounded;
      case 'reservation_accepted':
        return Icons.check_circle_rounded;
      case 'reservation_rejected':
        return Icons.cancel_rounded;
      case 'reservation_cancelled':
        return Icons.event_busy_rounded;
      case 'review':
        return Icons.star_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'system':
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'reservation':
        return Colors.blue;
      case 'reservation_accepted':
        return Colors.green;
      case 'reservation_rejected':
        return Colors.red;
      case 'reservation_cancelled':
        return Colors.orange;
      case 'review':
        return Colors.amber.shade700;
      case 'restaurant':
      default:
        return primaryColor;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    try {
      final date = DateTime.parse(value.toString()).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) return "À l'instant";
      if (difference.inMinutes < 60) return "Il y a ${difference.inMinutes} min";
      if (difference.inHours < 24) return "Il y a ${difference.inHours} h";
      if (difference.inDays == 1) return "Hier";
      if (difference.inDays < 7) return "Il y a ${difference.inDays} jours";

      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (_) {
      return '';
    }
  }

  String _getTitle(Map<String, dynamic> notification) {
    final title = notification['title']?.toString().trim();
    return (title != null && title.isNotEmpty) ? title : "Notification TableGO";
  }

  String _getMessage(Map<String, dynamic> notification) {
    final msg = notification['message']?.toString().trim();
    return (msg != null && msg.isNotEmpty) ? msg : "Vous avez reçu une nouvelle notification.";
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Row(
          children: [
            const Text(
              "Notifications",
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minWidth: 25),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  unreadCount.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton(
                onPressed: isMarkingAll ? null : _markAllAsRead,
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: isMarkingAll
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      )
                    : const Text(
                        "Tout lire",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (notifications.isEmpty) {
      return RefreshIndicator(
        color: primaryColor,
        onRefresh: _loadNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * .18),
            Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(.08),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 45,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Center(
              child: Text(
                "Tout est calme ici",
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 45),
              child: Text(
                "Les notifications concernant vos réservations et votre activité apparaîtront ici.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  height: 1.5,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _loadNotifications,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          return _buildNotificationCard(notifications[index]);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] == true;
    final type = notification['type']?.toString();
    final color = _getNotificationColor(type);
    final icon = _getNotificationIcon(type);
    final id = notification['id']?.toString();

    return Dismissible(
      key: ValueKey(notification['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 25),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade500,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 25,
        ),
      ),
      confirmDismiss: (_) async => true,
      onDismissed: (_) {
        if (id != null) {
          _deleteNotification(id);
        }
      },
      child: GestureDetector(
        onTap: () => _markAsRead(notification),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : primaryColor.withOpacity(.045),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRead ? Colors.grey.shade200 : primaryColor.withOpacity(.13),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.025),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _getTitle(notification),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 8, top: 5),
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _getMessage(notification),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(notification['created_at']),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "Nouveau",
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}