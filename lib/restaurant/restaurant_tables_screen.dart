import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantTablesScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantSlug;
  final String restaurantName;

  const RestaurantTablesScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantSlug,
    required this.restaurantName,
  });

  @override
  State<RestaurantTablesScreen> createState() => _RestaurantTablesScreenState();
}

class _RestaurantTablesScreenState extends State<RestaurantTablesScreen> {
  final supabase = Supabase.instance.client;
  static const Color primaryColor = Color(0xFF800020);

  List<Map<String, dynamic>> tables = [];
  bool isLoading = true;
  String statusFilter = 'all'; // 'all', 'libre', 'reservee', 'occupee'

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from('tables')
          .select()
          .eq('restaurant_id', widget.restaurantId)
          .order('table_number', ascending: true);

      if (!mounted) return;
      setState(() {
        tables = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur chargement tables: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateTableStatus(String tableId, String newStatus) async {
    try {
      await supabase.from('tables').update({'status': newStatus}).eq('id', tableId);
      _loadTables();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de mise à jour : $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteTable(String tableId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer la table"),
        content: const Text("Êtes-vous sûr de vouloir supprimer cette table ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('tables').delete().eq('id', tableId);
      _loadTables();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Table supprimée avec succès", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'occupee':
      case 'occupied':
        return Colors.red.shade600;
      case 'reservee':
      case 'reserved':
        return Colors.amber.shade800;
      case 'libre':
      case 'available':
      default:
        return Colors.green.shade600;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'occupee':
      case 'occupied':
        return 'Occupée';
      case 'reservee':
      case 'reserved':
        return 'Réservée';
      case 'libre':
      case 'available':
      default:
        return 'Libre';
    }
  }

  void _showAddTableModal() {
    final tableNameController = TextEditingController();
    final tableNumberController = TextEditingController();
    final capacityController = TextEditingController(text: '4');
    String selectedStatus = 'libre';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Ajouter une nouvelle table", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: tableNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Numéro de table *",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tableNameController,
                      decoration: InputDecoration(
                        labelText: "Nom personnalisé (ex: Terrasse 1, VIP)",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Capacité (nombre de personnes)",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text("Statut initial", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatusChip('libre', 'Libre', Colors.green, selectedStatus, (val) => setModalState(() => selectedStatus = val)),
                        const SizedBox(width: 8),
                        _buildStatusChip('reservee', 'Réservée', Colors.amber.shade800, selectedStatus, (val) => setModalState(() => selectedStatus = val)),
                        const SizedBox(width: 8),
                        _buildStatusChip('occupee', 'Occupée', Colors.red, selectedStatus, (val) => setModalState(() => selectedStatus = val)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final numText = tableNumberController.text.trim();
                                if (numText.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Veuillez indiquer un numéro de table"), backgroundColor: Colors.orange),
                                  );
                                  return;
                                }

                                setModalState(() => isSaving = true);

                                try {
                                  final int tableNum = int.parse(numText);

                                  await supabase.from('tables').insert({
                                    'restaurant_id': widget.restaurantId,
                                    'table_number': tableNum,
                                    'name': tableNameController.text.trim().isEmpty 
                                        ? "Table $tableNum" 
                                        : tableNameController.text.trim(),
                                    'capacity': int.tryParse(capacityController.text.trim()) ?? 4,
                                    'status': selectedStatus,
                                  });

                                  if (!mounted) return;
                                  Navigator.pop(modalContext);
                                  _loadTables();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Table ajoutée avec succès", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
                                  );
                                } catch (e) {
                                  debugPrint("Erreur ajout table : $e");
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  setModalState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Enregistrer la table", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String value, String label, Color color, String currentStatus, Function(String) onSelected) {
    bool isSelected = currentStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelected(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
            border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calcul des statistiques rapides de la salle
    final int totalCount = tables.length;
    final int libreCount = tables.where((t) => (t['status'] ?? 'libre') == 'libre').length;
    final int reserveCount = tables.where((t) => (t['status'] ?? '') == 'reservee' || t['status'] == 'reserved').length;
    final int occupeCount = tables.where((t) => (t['status'] ?? '') == 'occupee' || t['status'] == 'occupied').length;

    // Filtrage des tables affichées
    final filteredTables = tables.where((t) {
      if (statusFilter == 'all') return true;
      final st = t['status'] ?? 'libre';
      if (statusFilter == 'libre') return st == 'libre' || st == 'available';
      if (statusFilter == 'reservee') return st == 'reservee' || st == 'reserved';
      if (statusFilter == 'occupee') return st == 'occupee' || st == 'occupied';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Gestion de salle : ${widget.restaurantName}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadTables,
            tooltip: "Actualiser",
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        elevation: 2,
        onPressed: _showAddTableModal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Ajouter une table", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. TABLEAU DE BORD RAPIDE DE LA SALLE (KPIs)
                Row(
                  children: [
                    Expanded(child: _buildKpiCard("Total", "$totalCount", Colors.blue.shade700, Colors.blue.shade50)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildKpiCard("Libres", "$libreCount", Colors.green.shade700, Colors.green.shade50)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildKpiCard("Réservées", "$reserveCount", Colors.amber.shade800, Colors.amber.shade50)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildKpiCard("Occupées", "$occupeCount", Colors.red.shade700, Colors.red.shade50)),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. FILTRES RAPIDES PAR STATUT
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterTab("Toutes ($totalCount)", "all"),
                      const SizedBox(width: 8),
                      _buildFilterTab("Libres ($libreCount)", "libre"),
                      const SizedBox(width: 8),
                      _buildFilterTab("Réservées ($reserveCount)", "reservee"),
                      const SizedBox(width: 8),
                      _buildFilterTab("Occupées ($occupeCount)", "occupee"),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. LISTE DES TABLES
                filteredTables.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_restaurant_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text("Aucune table trouvée pour ce filtre", style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredTables.length,
                        itemBuilder: (context, index) {
                          final table = filteredTables[index];
                          final tableId = table['id'].toString();
                          final tableNum = table['table_number'] ?? '?';
                          final tableName = table['name'] ?? 'Table N° $tableNum';
                          final capacity = table['capacity'] ?? '?';
                          final status = table['status'] ?? 'libre';
                          final statusColor = _getStatusColor(status);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Numéro de table encadré
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "$tableNum",
                                      style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  
                                  // Infos principales
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tableName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.people_outline, size: 13, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              "$capacity pers. max",
                                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Sélecteur de statut rapide (Menu déroulant propre)
                                  PopupMenuButton<String>(
                                    onSelected: (newStatus) => _updateTableStatus(tableId, newStatus),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'libre', child: Text('🟢 Marquer comme Libre', style: TextStyle(fontSize: 13))),
                                      const PopupMenuItem(value: 'reservee', child: Text('🟠 Marquer comme Réservée', style: TextStyle(fontSize: 13))),
                                      const PopupMenuItem(value: 'occupee', child: Text('🔴 Marquer comme Occupée', style: TextStyle(fontSize: 13))),
                                    ],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: statusColor.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _getStatusLabel(status),
                                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: statusColor),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Bouton Supprimer discret
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade400, size: 20),
                                    onPressed: () => _deleteTable(tableId),
                                    tooltip: "Supprimer la table",
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 80), // Espace bas pour le FAB
              ],
            ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    bool isSelected = statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? primaryColor : Colors.grey.shade300),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => statusFilter = value);
        }
      },
    );
  }
}