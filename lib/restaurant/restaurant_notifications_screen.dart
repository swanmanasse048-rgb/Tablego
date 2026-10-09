import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:savora/services/fcm_service.dart';

class RestaurantNotificationsScreen extends StatefulWidget {
  const RestaurantNotificationsScreen({super.key});

  @override
  State<RestaurantNotificationsScreen> createState() =>
      _RestaurantNotificationsScreenState();
}

class _RestaurantNotificationsScreenState
    extends State<RestaurantNotificationsScreen> {
  final supabase = Supabase.instance.client;

  static const Color primaryColor = Color(0xFF6D1B2B);
  static const Color backgroundColor = Color(0xFFF7F7F8);

  List<Map<String, dynamic>> notifications = [];

  bool isLoading = true;
  bool isMarkingAll = false;

  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();

    _loadNotifications();
    _listenToNotifications();
    FCMService.setupFCMToken();
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      supabase.removeChannel(_notificationChannel!);
    }

    super.dispose();
  }

  // ============================================================
  // CHARGER LES NOTIFICATIONS
  // ============================================================

  Future<void> _loadNotifications() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // 1. Récupérer le restaurant appartenant à cet utilisateur
      final restaurantData = await supabase
          .from('restaurants')
          .select('id')
          .eq('owner_id', user.id) // Ajuste 'owner_id' si ta colonne s'appelle différemment (ex: user_id)
          .maybeSingle();

      final restaurantId = restaurantData?['id'];

      // 2. Construire la requête pour chercher par user_id OU par restaurant_id
      var query = supabase.from('notifications').select();

      if (restaurantId != null) {
        query = query.or('user_id.eq.${user.id},restaurant_id.eq.$restaurantId');
      } else {
        query = query.eq('user_id', user.id);
      }

      final data = await query.order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        notifications = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("ERREUR CHARGEMENT NOTIFICATIONS RESTAURANT : $e");

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });

      _showError("Impossible de charger les notifications.");
    }
  }
  // ============================================================
  // TEMPS RÉEL (CORRIGÉ AVEC FILTRE PAR USER_ID)
  // ============================================================

  void _listenToNotifications() {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    _notificationChannel = supabase
        .channel('restaurant-notifications-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            // Recharge la liste pour afficher la nouvelle notification
            _loadNotifications();

            // Affiche un bandeau visuel pour le restaurateur en direct
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          payload.newRecord['title']?.toString() ?? "Nouvelle notification reçue !",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: primaryColor,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 10),
                ),
              );
            }
          },
        )
        .subscribe();
  }

  // ============================================================
  // MARQUER UNE NOTIFICATION COMME LUE
  // ============================================================

  Future<void> _markAsRead(
    String notificationId,
  ) async {
    try {
      await supabase
          .from('notifications')
          .update({
        'is_read': true,
      }).eq(
        'id',
        notificationId,
      );

      if (!mounted) return;

      setState(() {
        final index = notifications.indexWhere(
          (notification) =>
              notification['id'].toString() ==
              notificationId,
        );

        if (index != -1) {
          notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      debugPrint(
        "ERREUR NOTIFICATION LUE : $e",
      );
    }
  }

  // ============================================================
  // TOUT MARQUER COMME LU
  // ============================================================

  Future<void> _markAllAsRead() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    setState(() {
      isMarkingAll = true;
    });

    try {
      await supabase
          .from('notifications')
          .update({
        'is_read': true,
      })
          .eq(
            'user_id',
            user.id,
          )
          .eq(
            'is_read',
            false,
          );

      if (!mounted) return;

      setState(() {
        for (final notification in notifications) {
          notification['is_read'] = true;
        }

        isMarkingAll = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Toutes les notifications sont lues.",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isMarkingAll = false;
      });

      _showError(
        "Impossible de marquer les notifications.",
      );
    }
  }

  // ============================================================
  // SUPPRIMER UNE NOTIFICATION
  // ============================================================

  Future<void> _deleteNotification(
    String notificationId,
  ) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq(
            'id',
            notificationId,
          );

      if (!mounted) return;

      setState(() {
        notifications.removeWhere(
          (notification) =>
              notification['id'].toString() ==
              notificationId,
        );
      });
    } catch (e) {
      debugPrint(
        "ERREUR SUPPRESSION NOTIFICATION : $e",
      );

      _showError(
        "Impossible de supprimer la notification.",
      );
    }
  }

  // ============================================================
  // SUPPRIMER TOUTES LES NOTIFICATIONS
  // ============================================================

  Future<void> _deleteAllNotifications() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    if (notifications.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Supprimer les notifications ?",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "Toutes vos notifications seront supprimées.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                "Annuler",
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                "Supprimer",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('notifications')
          .delete()
          .eq(
        'user_id',
        user.id,
      );

      if (!mounted) return;

      setState(() {
        notifications.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Notifications supprimées.",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError(
        "Impossible de supprimer les notifications.",
      );
    }
  }

  // ============================================================
  // ICÔNE NOTIFICATION
  // ============================================================

  IconData _getNotificationIcon(
    String? type,
  ) {
    switch (type) {
      case 'reservation':
      case 'new_reservation':
        return Icons.calendar_month;

      case 'reservation_accepted':
      case 'accepted':
        return Icons.check_circle;

      case 'reservation_rejected':
      case 'rejected':
        return Icons.cancel;

      case 'reservation_cancelled':
      case 'cancelled':
        return Icons.event_busy;

      case 'review':
      case 'new_review':
        return Icons.star;

      case 'restaurant':
        return Icons.restaurant;

      default:
        return Icons.notifications;
    }
  }

  // ============================================================
  // COULEUR
  // ============================================================

  Color _getNotificationColor(
    String? type,
  ) {
    switch (type) {
      case 'reservation':
      case 'new_reservation':
        return Colors.blue;

      case 'reservation_accepted':
      case 'accepted':
        return Colors.green;

      case 'reservation_rejected':
      case 'rejected':
      case 'reservation_cancelled':
      case 'cancelled':
        return Colors.red;

      case 'review':
      case 'new_review':
        return Colors.amber.shade700;

      default:
        return primaryColor;
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    try {
      final date = DateTime.parse(
        value.toString(),
      ).toLocal();

      final now = DateTime.now();

      final difference =
          now.difference(date);

      if (difference.inMinutes < 1) {
        return "À l'instant";
      }

      if (difference.inMinutes < 60) {
        return "Il y a ${difference.inMinutes} min";
      }

      if (difference.inHours < 24) {
        return "Il y a ${difference.inHours} h";
      }

      if (difference.inDays == 1) {
        return "Hier";
      }

      if (difference.inDays < 7) {
        return "Il y a ${difference.inDays} jours";
      }

      return "${date.day.toString().padLeft(2, '0')}/"
          "${date.month.toString().padLeft(2, '0')}/"
          "${date.year}";
    } catch (_) {
      return value.toString();
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications
        .where(
          (notification) =>
              notification['is_read'] != true,
        )
        .length;

    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,

        toolbarHeight: 72,

        titleSpacing: 20,

        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              "Notifications",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.3,
              ),
            ),

            if (unreadCount > 0)
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 3,
                ),
                child: Text(
                  "$unreadCount notification${unreadCount > 1 ? 's' : ''} non lue${unreadCount > 1 ? 's' : ''}",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),

        actions: [
          if (unreadCount > 0)
            Container(
              margin:
                  const EdgeInsets.only(
                right: 4,
              ),
              child: IconButton(
                tooltip:
                    "Tout marquer comme lu",
                onPressed:
                    isMarkingAll
                        ? null
                        : _markAllAsRead,
                icon: isMarkingAll
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(
                          color: primaryColor
                              .withOpacity(.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.done_all_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
              ),
            ),

          if (notifications.isNotEmpty)
            Container(
              margin:
                  const EdgeInsets.only(
                right: 14,
              ),
              child: IconButton(
                tooltip:
                    "Supprimer tout",
                onPressed:
                    _deleteAllNotifications,
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.red.withOpacity(.07),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: primaryColor,
                  backgroundColor: Colors.white,
                  onRefresh:
                      _loadNotifications,
                  child:
                      ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      18,
                      16,
                      30,
                    ),
                    itemCount:
                        notifications.length,
                    itemBuilder:
                        (context, index) {
                      return _buildNotificationCard(
                        notifications[index],
                      );
                    },
                  ),
                ),
    );
  }

  // ============================================================
  // CARTE NOTIFICATION
  // ============================================================

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
  ) {
    final bool isRead =
        notification['is_read'] == true;

    final String type =
        notification['type']?.toString() ??
            '';

    final String title =
        notification['title']?.toString() ??
            "Notification";

    final String message =
        notification['message']?.toString() ??
            "";

    final String date =
        _formatDate(
      notification['created_at'],
    );

    final color =
        _getNotificationColor(type);

    final icon =
        _getNotificationIcon(type);

    return Dismissible(
      key: Key(
        notification['id'].toString(),
      ),

      direction:
          DismissDirection.endToStart,

      background: Container(
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets.only(
          right: 25,
        ),
        alignment:
            Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius:
              BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),

      onDismissed: (_) {
        _deleteNotification(
          notification['id'].toString(),
        );
      },

      child: GestureDetector(
        onTap: () {
          if (!isRead) {
            _markAsRead(
              notification['id'].toString(),
            );
          }
        },

        child: Container(
          margin:
              const EdgeInsets.only(
            bottom: 14,
          ),

          padding:
              const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.circular(20),

            border: Border.all(
              color: isRead
                  ? Colors.grey.shade200
                  : primaryColor.withOpacity(.18),
              width: isRead ? 1 : 1.2,
            ),

            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withOpacity(.045),
                blurRadius: 18,
                offset:
                    const Offset(0, 6),
              ),
            ],
          ),

          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ICÔNE
              Stack(
                clipBehavior:
                    Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration:
                        BoxDecoration(
                      gradient:
                          LinearGradient(
                        begin:
                            Alignment.topLeft,
                        end:
                            Alignment.bottomRight,
                        colors: [
                          color.withOpacity(.16),
                          color.withOpacity(.07),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 25,
                    ),
                  ),

                  if (!isRead)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration:
                            BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 14),

              // CONTENU
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              height: 1.25,
                              fontWeight:
                                  isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                              color:
                                  const Color(
                                0xFF222222,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Icon(
                          Icons
                              .chevron_right_rounded,
                          size: 20,
                          color:
                              Colors.grey.shade400,
                        ),
                      ],
                    ),

                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 7),

                      Text(
                        message,
                        maxLines: 3,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color:
                              Colors.grey.shade700,
                        ),
                      ),
                    ],

                    const SizedBox(height: 11),

                    Row(
                      children: [
                        Icon(
                          Icons
                              .schedule_rounded,
                          size: 14,
                          color:
                              Colors.grey.shade500,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 11.5,
                            color:
                                Colors.grey.shade500,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),

                        const Spacer(),

                        if (!isRead)
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  primaryColor
                                      .withOpacity(.08),
                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                            ),
                            child:
                                const Text(
                              "Nouveau",
                              style: TextStyle(
                                color:
                                    primaryColor,
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ),
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

  // ============================================================
  // AUCUNE NOTIFICATION
  // ============================================================

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: primaryColor,
      backgroundColor: Colors.white,
      onRefresh: _loadNotifications,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height:
                MediaQuery.of(context).size.height *
                    .20,
          ),

          Center(
            child: Container(
              width: 110,
              height: 110,
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topLeft,
                  end:
                      Alignment.bottomRight,
                  colors: [
                    primaryColor.withOpacity(.14),
                    primaryColor.withOpacity(.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Container(
                margin:
                    const EdgeInsets.all(13),
                decoration:
                    const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .notifications_none_rounded,
                  size: 46,
                  color: primaryColor,
                ),
              ),
            ),
          ),

          const SizedBox(height: 26),

          const Center(
            child: Text(
              "Aucune notification",
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF222222),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 45,
            ),
            child: Text(
              "Les nouvelles réservations, avis et informations importantes apparaîtront ici.",
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                height: 1.55,
                fontSize: 13.5,
              ),
            ),
          ),

          const SizedBox(height: 25),

          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 9,
              ),
              decoration:
                  BoxDecoration(
                color:
                    primaryColor.withOpacity(.07),
                borderRadius:
                    BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .notifications_active_outlined,
                    size: 16,
                    color: primaryColor,
                  ),
                  SizedBox(width: 7),
                  Text(
                    "Vous serez averti ici",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}