import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:savora/services/notifications_service.dart';

class BookingScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const BookingScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  final guestsController = TextEditingController(text: "2");
  final specialRequestController = TextEditingController();

  bool isLoading = false;

  // Variables pour la sélection de la table
  String? selectedTableId;
  String? selectedTableName;
  List<Map<String, dynamic>> availableTables = [];
  bool isLoadingTables = true;

  final Color primaryColor = const Color(0xFF6D1B2B);
  final Color lightPrimary = const Color(0xFFF7ECEF);

  @override
  void initState() {
    super.initState();
    _fetchAvailableTables();
  }

  Future<void> _fetchAvailableTables() async {
    try {
      final supabase = Supabase.instance.client;
      // Récupération des champs id, table_number, name et capacity
      final response = await supabase
          .from('tables')
          .select('id, table_number, name, capacity')
          .eq('restaurant_id', widget.restaurantId)
          .eq('status', 'libre');

      setState(() {
        availableTables = List<Map<String, dynamic>>.from(response);
        isLoadingTables = false;
      });
    } catch (e) {
      setState(() => isLoadingTables = false);
      debugPrint("Erreur chargement tables : $e");
    }
  }

  // Filtrer les tables selon la capacité et le nombre de convives actuel
  List<Map<String, dynamic>> get filteredTables {
    final currentGuests = int.tryParse(guestsController.text) ?? 1;
    return availableTables.where((table) {
      final capacity = table['capacity'] ?? 99; // Valeur par défaut si null
      return capacity >= currentGuests;
    }).toList();
  }

  // ============================================================
  // RESERVATION
  // ============================================================

  Future<void> makeReservation() async {
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Choisissez une date et une heure."),
        ),
      );
      return;
    }

    final guests = int.tryParse(guestsController.text.trim());

    if (guests == null || guests < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez indiquer un nombre de personnes valide."),
        ),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez vous connecter pour réserver une table."),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final reservationDate = selectedDate!.toIso8601String().split('T')[0];
      final reservationTime =
          "${selectedTime!.hour.toString().padLeft(2, '0')}:"
          "${selectedTime!.minute.toString().padLeft(2, '0')}:00";

      String clientName = "Un client";

      try {
        final profile = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null &&
            profile['full_name'] != null &&
            profile['full_name'].toString().trim().isNotEmpty) {
          clientName = profile['full_name'].toString().trim();
        }
      } catch (e) {
        debugPrint("Impossible de récupérer le nom du client : $e");
      }

      final reservation = await supabase
          .from('reservations')
          .insert({
            'user_id': user.id,
            'restaurant_id': widget.restaurantId,
            'reservation_date': reservationDate,
            'reservation_time': reservationTime,
            'guests': guests,
            'status': 'pending',
            'special_request': specialRequestController.text.trim(),
            'table_id': selectedTableId,
          })
          .select()
          .single();

      await NotificationService.notifyRestaurantNewReservation(
        restaurantId: widget.restaurantId,
        reservationId: reservation['id'].toString(),
        clientName: clientName,
        reservationDate: reservationDate,
        reservationTime: reservationTime,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Réservation envoyée avec succès ✅"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint("ERREUR RESERVATION : $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible d'envoyer la réservation : $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // DATE & HEURE
  // ============================================================

  Future<void> selectDate() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, now.month, now.day),
      initialDate: selectedDate ?? now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  Future<void> selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        selectedTime = time;
      });
    }
  }

  String get formattedDate {
    if (selectedDate == null) return "Choisir une date";
    return "${selectedDate!.day.toString().padLeft(2, '0')}/"
        "${selectedDate!.month.toString().padLeft(2, '0')}/"
        "${selectedDate!.year}";
  }

  void _updateGuests(int change) {
    int current = int.tryParse(guestsController.text) ?? 1;
    int updated = current + change;
    if (updated >= 1) {
      setState(() {
        guestsController.text = updated.toString();
        // Si la table sélectionnée ne correspond plus à la capacité, on la désélectionne
        if (selectedTableId != null) {
          final selectedTableObj = availableTables.firstWhere(
            (t) => t['id'].toString() == selectedTableId,
            orElse: () => <String, dynamic> {},
          );
          if (selectedTableObj.isNotEmpty) {
            final capacity = selectedTableObj['capacity'] ?? 99;
            if (capacity < updated) {
              selectedTableId = null;
              selectedTableName = null;
            }
          }
        }
      });
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final tablesToShow = filteredTables;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back_rounded, color: primaryColor, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Réserver une table",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ENTÊTE RESTAURANT
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: lightPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.restaurant_rounded,
                      color: primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "RÉSERVATION POUR",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.restaurantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // NOMBRE DE PERSONNES (Placé avant les tables pour filtrer dynamiquement)
            _buildSectionTitle(
              "Nombre de personnes",
              "Combien de convives seront présents ?",
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_alt_outlined, color: primaryColor),
                      const SizedBox(width: 10),
                      const Text(
                        "Couverts",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildCounterButton(
                        icon: Icons.remove,
                        onTap: () => _updateGuests(-1),
                      ),
                      Container(
                        width: 50,
                        alignment: Alignment.center,
                        child: TextField(
                          controller: guestsController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (val) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      _buildCounterButton(
                        icon: Icons.add,
                        onTap: () => _updateGuests(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // DATE ET HEURE
            _buildSectionTitle(
              "Date & Heure",
              "Sélectionnez le moment de votre visite",
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.calendar_today_rounded,
                    title: "Date",
                    value: formattedDate,
                    selected: selectedDate != null,
                    onTap: selectDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.access_time_rounded,
                    title: "Heure",
                    value: selectedTime == null
                        ? "Choisir l'heure"
                        : selectedTime!.format(context),
                    selected: selectedTime != null,
                    onTap: selectTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // CHOIX DE LA TABLE
            _buildSectionTitle(
              "Choix de la table",
              "Tables adaptées à votre nombre de convives",
            ),
            const SizedBox(height: 12),
            isLoadingTables
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : tablesToShow.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Text(
                          "Aucune table disponible pour ce nombre de personnes",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : SizedBox(
                        height: 65,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: tablesToShow.length,
                          itemBuilder: (context, index) {
                            final table = tablesToShow[index];
                            final tableId = table['id'].toString();
                            final tableName = table['name'] ?? 'Table';
                            final tableNum = table['table_number']?.toString() ?? '?';
                            final capacity = table['capacity']?.toString() ?? '?';
                            
                            final displayName = "$tableName (N° $tableNum)";
                            final isSelected = selectedTableId == tableId;

                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    selectedTableId = tableId;
                                    selectedTableName = "$displayName • $capacity pers.";
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected ? primaryColor : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? primaryColor : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Capacité : $capacity pers.",
                                        style: TextStyle(
                                          color: isSelected ? Colors.white70 : Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

            const SizedBox(height: 24),

            // DEMANDE SPÉCIALE
            _buildSectionTitle(
              "Demande spéciale",
              "Une préférence ou allergie particulière ?",
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: specialRequestController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Ex : Une table calme près de la fenêtre...",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // RÉSUMÉ
            if (selectedDate != null && selectedTime != null) ...[
              _buildSummaryCard(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
      // BOUTON FIXÉ EN BAS (Sticky Footer)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: isLoading ? null : makeReservation,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Confirmer la réservation",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Réservation instantanée sans frais",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WIDGETS DE DESIGN
  // ============================================================

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? lightPrimary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.shade200,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: selected ? primaryColor : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: primaryColor),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightPrimary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                "Récapitulatif",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Date & Heure :",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              Text("$formattedDate à ${selectedTime!.format(context)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Table :",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              Text(selectedTableName ?? "Non spécifiée",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Convives :",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              Text("${guestsController.text} personne(s)",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}