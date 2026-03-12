import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:css/css.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Purchase Log',
      theme: CSS.changeTheme(LsiThemes.light),
      home: const PurchaseLogPage(),
    );
  }
}

// MODEL
class Purchase {
  final String itemName;
  final String date;
  final String dateLogged;
  final String timeLogged;
  final String purchaserName;
  final String vendor;
  final double price;
  final String category;
  final String details;
  final List<String> uploadedFiles;

  Purchase({
    required this.itemName,
    required this.date,
    required this.dateLogged,
    required this.timeLogged,
    required this.purchaserName,
    required this.vendor,
    required this.price,
    required this.category,
    required this.details,
    required this.uploadedFiles,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      itemName:      json['itemName']      ?? '',
      date:          json['date']          ?? '',
      dateLogged:    json['dateLogged']    ?? '',
      timeLogged:    json['timeLogged']    ?? '',
      purchaserName: json['purchaserName'] ?? '',
      vendor:        json['vendor']        ?? '',
      price:         (json['price'] as num? ?? 0).toDouble(),
      category:      json['category']      ?? '',
      details:       json['details']       ?? '',
      uploadedFiles: List<String>.from(json['uploadedFiles'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'itemName':      itemName,
    'date':          date,
    'dateLogged':    dateLogged,
    'timeLogged':    timeLogged,
    'purchaserName': purchaserName,
    'vendor':        vendor,
    'price':         price,
    'category':      category,
    'details':       details,
    'uploadedFiles': uploadedFiles,
  };
}

// PURCHASE LOG PAGE
class PurchaseLogPage extends StatefulWidget {
  const PurchaseLogPage({super.key});
  @override
  State<PurchaseLogPage> createState() => _PurchaseLogPageState();
}

class _PurchaseLogPageState extends State<PurchaseLogPage> {
  final TextEditingController searchController = TextEditingController();
  List<Purchase> allPurchases      = [];
  List<Purchase> filteredPurchases = [];
  bool loading = true;
  String? errorMessage;
  int? _sortColumnIndex;
  bool _isAscending = true;
  bool _hoveringAdd = false;

  @override
  void initState() {
    super.initState();
    loadPurchases();
  }

  Future<void> loadPurchases() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/json/fake_purchase_log.json');
      final List<dynamic> data = json.decode(jsonString);
      setState(() {
        allPurchases = data.map((j) => Purchase.fromJson(j)).toList();
        filteredPurchases = List.from(allPurchases);
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() { loading = false; errorMessage = 'Error loading data: $e'; });
    }
  }

  void filterSearch(String query) {
    setState(() {
      filteredPurchases = allPurchases.where((p) =>
        p.itemName.toLowerCase().contains(query.toLowerCase()) ||
        p.purchaserName.toLowerCase().contains(query.toLowerCase()) ||
        p.date.contains(query) ||
        p.vendor.toLowerCase().contains(query.toLowerCase())
      ).toList();
      if (_sortColumnIndex != null) sortPurchases(_sortColumnIndex!, _isAscending, updateState: false);
    });
  }

  void addPurchase(Purchase purchase) {
    setState(() {
      allPurchases.add(purchase);
      filterSearch(searchController.text);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Purchase saved!', style: TextStyle(color: Colors.white))]),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void sortPurchases(int columnIndex, bool ascending, {bool updateState = true}) {
    if (updateState) setState(() { _sortColumnIndex = columnIndex; _isAscending = ascending; });
    switch (columnIndex) {
      case 0: filteredPurchases.sort((a, b) => ascending ? a.itemName.compareTo(b.itemName) : b.itemName.compareTo(a.itemName)); break;
      case 1:
        filteredPurchases.sort((a, b) {
          try {
            final da = DateTime.parse(a.date), db = DateTime.parse(b.date);
            return ascending ? da.compareTo(db) : db.compareTo(da);
          } catch (_) { return 0; }
        });
        break;
      case 2: filteredPurchases.sort((a, b) => ascending ? a.purchaserName.compareTo(b.purchaserName) : b.purchaserName.compareTo(a.purchaserName)); break;
      case 3: filteredPurchases.sort((a, b) => ascending ? a.vendor.compareTo(b.vendor) : b.vendor.compareTo(a.vendor)); break;
    }
  }

  void _openAddPurchaseDialog() async {
    final results = await showDialog<List<Purchase>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AddPurchaseDialog(),
    );
    if (results != null) {
      for (final p in results) addPurchase(p);
    }
  }

  @override
  void dispose() { searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A94D4),
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), 
            borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.receipt_long, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text("Purchase Log", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.4)),
        ]),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildError()
              : _buildBody(theme),
    );
  }

  Widget _buildError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 48, color: Colors.red),
    const SizedBox(height: 16),
    Text(errorMessage!, style: const TextStyle(fontSize: 16, color: Colors.red), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: () { setState(() { loading = true; errorMessage = null; }); loadPurchases(); }, child: const Text('Retry')),
  ]));

  Widget _buildBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        //Main table area
        Expanded(
          flex: 3,
          child: Column(children: [
            // Search bar
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF616161), width: 1),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: TextField(
                controller: searchController,
                onChanged: filterSearch,
                decoration: InputDecoration(
                  hintText: "Search by item, purchaser, date, or vendor...",
                  hintStyle: TextStyle(fontSize: 14),
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF616161), width: 1),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: filteredPurchases.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.inbox_outlined, size: 52, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text("No purchases found", style: TextStyle(color: Colors.grey[400], fontSize: 15)),
                      ]))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              sortColumnIndex: _sortColumnIndex,
                              sortAscending: _isAscending,
                              headingTextStyle: const TextStyle(
                                color: Color(0xFF2A94D4),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 56,
                              columns: [
                                DataColumn(label: const Text("Item Name"), onSort: (i, a) => sortPurchases(i, a)),
                                DataColumn(label: const Text("Date"), onSort: (i, a) => sortPurchases(i, a)),
                                DataColumn(label: const Text("Purchaser"), onSort: (i, a) => sortPurchases(i, a)),
                                DataColumn(label: const Text("Vendor"), onSort: (i, a) => sortPurchases(i, a)),
                              ],
                              rows: filteredPurchases.map((p) {
                                return DataRow(
                                  cells: [
                                    _tapCell(p, Text(p.itemName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    _tapCell(p, Text(p.date, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
                                    _tapCell(p, Row(mainAxisSize: MainAxisSize.min, children: [
                                      CircleAvatar(radius: 13, backgroundColor: const Color(0xFFE8EAF6),
                                        child: Text(p.purchaserName.isNotEmpty ? p.purchaserName[0].toUpperCase() : '?',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF3949AB), fontWeight: FontWeight.bold))),
                                      const SizedBox(width: 8),
                                      Text(p.purchaserName),
                                    ])),
                                    _tapCell(p, Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFFF0F2FF), borderRadius: BorderRadius.circular(6)),
                                      child: Text(p.vendor, style: const TextStyle(fontSize: 12, color: Color(0xFF3949AB))),
                                    )),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 20),
        // Right panel add card 
        SizedBox(
          width: 220,
          child: Column(children: [
            // Stats card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A94D4), Color(0xFF3949AB)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFF2A94D4).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Total Spend", style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  "\$${allPurchases.fold(0.0, (s, p) => s + p.price).toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text("${allPurchases.length} purchases", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            // Add purchase card
            MouseRegion(
              onEnter: (_) => setState(() => _hoveringAdd = true),
              onExit: (_) => setState(() => _hoveringAdd = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _openAddPurchaseDialog,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A94D4), Color(0xFF3949AB)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    color: _hoveringAdd ? Colors.white : const Color(0xFF2A94D4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hoveringAdd ? const Color(0xFFBBCAFF) : const Color(0xFF2A94D4),
                      width: 2,
                    ),
                    boxShadow: [BoxShadow(
                      color: _hoveringAdd
                          ? Colors.black.withOpacity(0.06) : const Color(0xFF2A94D4).withOpacity(0.25),
                      blurRadius: _hoveringAdd ? 20 : 10,
                      offset: const Offset(0, 5),
                    )],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _hoveringAdd ? const Color(0xFFE8EAF6) : Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, size: 28,
                        color: _hoveringAdd ? const Color(0xFF2A94D4) : Colors.white),
                    ),
                    const SizedBox(height: 12),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _hoveringAdd ? const Color(0xFF2A94D4) : Colors.white,
                      ),
                      child: const Text("Log a Purchase"),
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 11,
                        color: _hoveringAdd ? Colors.grey : Colors.white70,
                      ),
                      child: const Text("Upload or enter manually"),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  DataCell _tapCell(Purchase p, Widget child) => DataCell(child, onTap: () {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseDetailPage(purchase: p)));
  });
}

// ADD PURCHASE DIALOG
class _AddPurchaseDialog extends StatefulWidget {
  const _AddPurchaseDialog();
  @override
  State<_AddPurchaseDialog> createState() => _AddPurchaseDialogState();
}

class _AddPurchaseDialogState extends State<_AddPurchaseDialog> {
  bool _showingResults = false;

  List<_PurchaseDraft> _drafts = [];
  int _currentDraftIndex = 0;

  bool _isProcessing = false;
  double _processingProgress = 0.0;
  Timer? _progressTimer;
  String _processingLabel = "Uploading...";

  // Manual form fields
  final _formKey = GlobalKey<FormState>();
  final _itemCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  final _purchaserCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _categoryCtrl= TextEditingController();
  final _detailsCtrl = TextEditingController();
  DateTime _loggedDate= DateTime.now();
  TimeOfDay _loggedTime = TimeOfDay.now();
  DateTime _purchaseDate = DateTime.now();
  List<String> _manualFiles = [];

  @override
  void dispose() {
    _progressTimer?.cancel();
    _itemCtrl.dispose(); _vendorCtrl.dispose(); _purchaserCtrl.dispose();
    _amountCtrl.dispose(); _categoryCtrl.dispose(); _detailsCtrl.dispose();
    super.dispose();
  }

  // File pick & parse
  static const _parseable = {'txt', 'pdf'};

  Future<void> _pickAndParseFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() { _isProcessing = true; _processingProgress = 0; _processingLabel = "Uploading files..."; });
    _startProgress();

    // Separate parseable from non-parseable
    final parseableFiles = result.files.where((f) => _parseable.contains((f.extension ?? '').toLowerCase())).toList();
    final otherFiles = result.files.where((f) => !_parseable.contains((f.extension ?? '').toLowerCase())).toList();

    final List<Future<_PurchaseDraft>> futures = [];

    for (final file in parseableFiles) {
      futures.add(_parseFile(file));
    }

    // Non-parseable: create blank drafts with just the filename attached
    for (final file in otherFiles) {
      futures.add(Future.value(_PurchaseDraft.blank(fileName: file.name)));
    }

    final drafts = await Future.wait(futures);

    _finishProgress();
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _isProcessing = false;
      _drafts = drafts;
      _currentDraftIndex = 0;
      _showingResults = true;
    });
  }

  Future<_PurchaseDraft> _parseFile(dynamic file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:8000/parse'));
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path!));
      }
      final response = await request.send();
      final body     = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        return _PurchaseDraft.fromBackend(data, fileName: file.name);
      }
    } catch (_) {}
    return _PurchaseDraft.blank(fileName: file.name);
  }

  void _startProgress() {
    _progressTimer?.cancel();
    const tickMs = 50;
    int elapsed  = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      elapsed += tickMs;
      double target;
      if (elapsed < 1200) {
        target = (elapsed / 1200) * 0.55;
        if (mounted) setState(() => _processingLabel = "Uploading files...");
      } else if (elapsed < 2800) {
        target = 0.55 + ((elapsed - 1200) / 1600) * 0.30;
        if (mounted) setState(() => _processingLabel = "Parsing documents...");
      } else {
        final extra = elapsed - 2800;
        target = 0.85 + 0.13 * (1 - math.exp(-extra / 8000.0));
        if (mounted) setState(() => _processingLabel = "Extracting details...");
      }
      if (mounted) setState(() => _processingProgress = target.clamp(0.0, 0.99));
    });
  }

  void _finishProgress() {
    _progressTimer?.cancel();
    if (mounted) setState(() { _processingProgress = 1.0; _processingLabel = "Done!"; });
  }

  // Manual form helpers
  Future<void> _pickManualFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null) setState(() => _manualFiles.add(result.files.single.name));
  }

  Future<void> _pickLoggedDate() async {
    final d = await showDatePicker(context: context, initialDate: _loggedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null) setState(() => _loggedDate = d);
  }

  Future<void> _pickLoggedTime() async {
    final t = await showTimePicker(context: context, initialTime: _loggedTime);
    if (t != null) setState(() => _loggedTime = t);
  }

  Future<void> _pickPurchaseDate() async {
    final d = await showDatePicker(context: context, initialDate: _purchaseDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null) setState(() => _purchaseDate = d);
  }

  void _submitManual() {
    if (!_formKey.currentState!.validate()) return;
    final purchase = Purchase(
      itemName:      _itemCtrl.text.trim(),
      date:          DateFormat('yyyy-MM-dd').format(_purchaseDate),
      dateLogged:    DateFormat('yyyy-MM-dd').format(_loggedDate),
      timeLogged:    '${_loggedTime.hour.toString().padLeft(2, '0')}:${_loggedTime.minute.toString().padLeft(2, '0')}',
      purchaserName: _purchaserCtrl.text.trim(),
      vendor:        _vendorCtrl.text.trim(),
      price:         double.tryParse(_amountCtrl.text.trim()) ?? 0.0,
      category:      _categoryCtrl.text.trim(),
      details:       _detailsCtrl.text.trim(),
      uploadedFiles: List.from(_manualFiles),
    );
    Navigator.pop(context, [purchase]);
  }

  // Confirm a draft 

  void _confirmCurrentDraft() {
    final draft = _drafts[_currentDraftIndex];
    draft.confirmed = true;
    // Check if all done
    if (_drafts.every((d) => d.confirmed)) {
      final purchases = _drafts.map((d) => d.toPurchase()).toList();
      Navigator.pop(context, purchases);
    } else {
      // Move to next unconfirmed
      int next = (_currentDraftIndex + 1) % _drafts.length;
      while (_drafts[next].confirmed) next = (next + 1) % _drafts.length;
      setState(() => _currentDraftIndex = next);
    }
  }

  void _saveAllRemaining() {
    final purchases = _drafts.map((d) => d.toPurchase()).toList();
    Navigator.pop(context, purchases);
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 740),
        child: _isProcessing
            ? _buildProcessing()
            : _showingResults
                ? _buildReviewScreen()
                : _buildManualForm(),
      ),
    );
  }

  // Processing overlay 
  Widget _buildProcessing() {
    final pct = (_processingProgress * 100).toInt();
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 110, height: 110,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: 110, height: 110,
              child: CircularProgressIndicator(value: 1.0, strokeWidth: 10, color: const Color(0xFFE8EAF6))),
            SizedBox(width: 110, height: 110,
              child: CircularProgressIndicator(value: _processingProgress, strokeWidth: 10,
                strokeCap: StrokeCap.round, color: const Color(0xFF2A94D4))),
            Text("$pct%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2A94D4))),
          ]),
        ),
        const SizedBox(height: 24),
        const Text("Processing Files", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2A94D4))),
        const SizedBox(height: 6),
        Text(_processingLabel, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ]),
    );
  }

  // Review screen (parsed results)

  Widget _buildReviewScreen() {
    final draft      = _drafts[_currentDraftIndex];
    final total      = _drafts.length;
    final confirmed  = _drafts.where((d) => d.confirmed).length;
    final allConfirmed = confirmed == total;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF2A94D4),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Row(children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(
            total > 1 ? "Review Purchases ($confirmed/$total confirmed)" : "Review Purchase",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          )),
          // Navigation arrows for multiple files
          if (total > 1) ...[
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () => setState(() => _currentDraftIndex = (_currentDraftIndex - 1 + total) % total),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text("${_currentDraftIndex + 1}/$total", style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () => setState(() => _currentDraftIndex = (_currentDraftIndex + 1) % total),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
      ),

      // File indicator dots (multi-file)
      if (total > 1)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(total, (i) {
            final isConfirmed = _drafts[i].confirmed;
            final isCurrent   = i == _currentDraftIndex;
            return GestureDetector(
              onTap: () => setState(() => _currentDraftIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isCurrent ? 20 : 8, height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isConfirmed
                      ? Colors.green
                      : isCurrent
                          ? const Color(0xFF2A94D4)
                          : Colors.grey[300],
                ),
              ),
            );
          })),
        ),

      // Fields
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (draft.confirmed)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade300)),
                child: Row(children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                  const SizedBox(width: 8),
                  const Text("This purchase has been confirmed.", style: TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                child: Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(child: Text("Review and edit the fields below before confirming.", style: TextStyle(fontSize: 12, color: Colors.black54))),
                ]),
              ),
            _draftField("Item",           draft.itemCtrl,       Icons.inventory_2_outlined),
            const SizedBox(height: 10),
            // Logged date/time row
            Row(children: [
              Expanded(child: _dateButton("Logged Date", DateFormat('yyyy-MM-dd').format(draft.loggedDate),
                () async { final d = await showDatePicker(context: context, initialDate: draft.loggedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setState(() => draft.loggedDate = d); })),
              const SizedBox(width: 10),
              Expanded(child: _timeButton("Logged Time", draft.loggedTime.format(context),
                () async { final t = await showTimePicker(context: context, initialTime: draft.loggedTime);
                  if (t != null) setState(() => draft.loggedTime = t); })),
            ]),
            const SizedBox(height: 10),
            _draftField("Vendor",         draft.vendorCtrl,     Icons.store_outlined),
            const SizedBox(height: 10),
            _draftField("Purchaser",      draft.purchaserCtrl,  Icons.person_outline),
            const SizedBox(height: 10),
            _dateButton("Date Purchased", DateFormat('yyyy-MM-dd').format(draft.purchaseDate),
              () async { final d = await showDatePicker(context: context, initialDate: draft.purchaseDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => draft.purchaseDate = d); }),
            const SizedBox(height: 10),
            _draftField("Amount (\$)",   draft.amountCtrl,     Icons.attach_money),
            const SizedBox(height: 10),
            _draftField("Category",       draft.categoryCtrl,   Icons.category_outlined),
            const SizedBox(height: 10),
            _draftFieldMultiline("Details", draft.detailsCtrl, Icons.receipt_long_outlined),
            const SizedBox(height: 10),
            // Uploaded files
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFBBBBBB)), borderRadius: BorderRadius.circular(6)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.attach_file, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text("Uploaded Files", style: TextStyle(fontSize: 12, color: Colors.grey[600]
                  )),
                ]),
                const SizedBox(height: 6),
                if (draft.uploadedFiles.isEmpty)
                  Text("None", style: TextStyle(fontSize: 12, color: Colors.grey[400], fontStyle: FontStyle.italic))
                else
                  ...draft.uploadedFiles.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      const Icon(Icons.insert_drive_file, size: 14, color: Color(0xFF3949AB)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
                    ]),
                  )),
              ]),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),

      // Action buttons
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(children: [
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.red.withOpacity(0.8))),
            ),
            Row(children: [
              if (total > 1 && !allConfirmed)
                TextButton(
                  onPressed: _saveAllRemaining,
                  child: const Text("Save All"),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: draft.confirmed ? null : _confirmCurrentDraft,
                icon: const Icon(Icons.check, size: 16),
                label: Text(total > 1 ? "Confirm This" : "Confirm & Save"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A94D4),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.green.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ]),
        ]),
      ),
    ]);
  }

  // Manual entry form

  Widget _buildManualForm() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF2A94D4),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Row(children: [
          const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text("Log a Purchase", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
      ),

      // Upload button
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickAndParseFiles,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text("Upload Receipt(s) for Auto-Fill"),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2A94D4),
              side: const BorderSide(color: Color(0xFF2A94D4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text("or enter manually", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ]),
      ),

      // Form
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _formField(_itemCtrl,      "Item Name",    Icons.inventory_2_outlined, required: true),
              const SizedBox(height: 10),
              // Logged date/time
              Row(children: [
                Expanded(child: _dateButton("Logged Date", DateFormat('yyyy-MM-dd').format(_loggedDate), _pickLoggedDate)),
                const SizedBox(width: 10),
                Expanded(child: _timeButton("Logged Time",
                  '${_loggedTime.hour.toString().padLeft(2, '0')}:${_loggedTime.minute.toString().padLeft(2, '0')}',
                  _pickLoggedTime)),
              ]),
              const SizedBox(height: 10),
              _formField(_vendorCtrl,    "Vendor",        Icons.store_outlined,      required: true),
              const SizedBox(height: 10),
              _formField(_purchaserCtrl, "Purchaser",     Icons.person_outline,      required: true),
              const SizedBox(height: 10),
              _dateButton("Date Purchased", DateFormat('yyyy-MM-dd').format(_purchaseDate), _pickPurchaseDate),
              const SizedBox(height: 10),
              _formField(_amountCtrl,    "Amount (\$)",  Icons.attach_money,         required: true, numeric: true),
              const SizedBox(height: 10),
              _formField(_categoryCtrl,  "Category",      Icons.category_outlined),
              const SizedBox(height: 10),
              _formFieldMultiline(_detailsCtrl, "Details", Icons.receipt_long_outlined),
              const SizedBox(height: 10),
              // File list
              if (_manualFiles.isNotEmpty) ...[
                ...(_manualFiles.map((f) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.insert_drive_file, size: 18, color: Color(0xFF3949AB)),
                  title: Text(f, style: const TextStyle(fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: () => setState(() => _manualFiles.remove(f)),
                  ),
                  contentPadding: EdgeInsets.zero,
                ))),
              ],
              TextButton.icon(
                onPressed: _pickManualFile,
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text("Attach File"),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
            ]),
          ),
        ),
      ),

      // Actions
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(children: [
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.red))),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _submitManual,
              icon: const Icon(Icons.check, size: 16),
              label: const Text("Save"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A94D4), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  // Shared field widgets
  Widget _draftField(String label, TextEditingController ctrl, IconData icon) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: ctrl.text.isEmpty ? 'Not found' : null,
      hintStyle: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
    ),
  );

  Widget _draftFieldMultiline(String label, TextEditingController ctrl, IconData icon) => TextField(
    controller: ctrl,
    maxLines: null, minLines: 2,
    keyboardType: TextInputType.multiline,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Padding(padding: const EdgeInsets.only(bottom: 0), child: Icon(icon, size: 18)),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: ctrl.text.isEmpty ? 'Not found' : null,
      hintStyle: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
    ),
  );

  Widget _formField(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, bool numeric = false}) =>
    TextFormField(
      controller: ctrl,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    );

  Widget _formFieldMultiline(TextEditingController ctrl, String label, IconData icon) =>
    TextFormField(
      controller: ctrl,
      maxLines: null, minLines: 2,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
      ),
    );

  Widget _dateButton(String label, String display, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today, size: 16),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(display, style: const TextStyle(fontSize: 14)),
    ),
  );

  Widget _timeButton(String label, String display, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.access_time, size: 16),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(display, style: const TextStyle(fontSize: 14)),
    ),
  );
}

// PURCHASE DRAFT
class _PurchaseDraft {
  final TextEditingController itemCtrl;
  final TextEditingController vendorCtrl;
  final TextEditingController purchaserCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController categoryCtrl;
  final TextEditingController detailsCtrl;
  DateTime loggedDate;
  TimeOfDay loggedTime;
  DateTime purchaseDate;
  List<String> uploadedFiles;
  bool confirmed = false;

  _PurchaseDraft({
    required String item,
    required String vendor,
    required String purchaser,
    required String amount,
    required String category,
    required String details,
    required this.loggedDate,
    required this.loggedTime,
    required this.purchaseDate,
    required this.uploadedFiles,
  })  : itemCtrl      = TextEditingController(text: item),
        vendorCtrl    = TextEditingController(text: vendor),
        purchaserCtrl = TextEditingController(text: purchaser),
        amountCtrl    = TextEditingController(text: amount),
        categoryCtrl  = TextEditingController(text: category),
        detailsCtrl   = TextEditingController(text: details);

  factory _PurchaseDraft.fromBackend(Map<String, dynamic> data, {required String fileName}) {
    // Parse date from backend (MM/DD/YYYY) into DateTime
    DateTime purchaseDate = DateTime.now();
    final rawDate = data['date']?.toString() ?? '';
    try {
      if (rawDate.contains('/')) {
        purchaseDate = DateFormat('MM/dd/yyyy').parse(rawDate);
      } else if (rawDate.contains('-')) {
        purchaseDate = DateTime.parse(rawDate);
      }
    } catch (_) {}

    return _PurchaseDraft(
      item:          data['item']?.toString()      ?? '',
      vendor:        data['vendor']?.toString()    ?? '',
      purchaser:     data['purchaser']?.toString() ?? '',
      amount:        data['amount']?.toString()    ?? '',
      category:      data['category']?.toString()  ?? '',
      details:       data['details']?.toString()   ?? '',
      loggedDate:    DateTime.now(),
      loggedTime:    TimeOfDay.now(),
      purchaseDate:  purchaseDate,
      uploadedFiles: [fileName],
    );
  }

  factory _PurchaseDraft.blank({required String fileName}) => _PurchaseDraft(
    item: '', vendor: '', purchaser: '', amount: '', category: '', details: '',
    loggedDate: DateTime.now(), loggedTime: TimeOfDay.now(), purchaseDate: DateTime.now(),
    uploadedFiles: [fileName],
  );

  Purchase toPurchase() => Purchase(
    itemName:      itemCtrl.text.trim(),
    date:          DateFormat('yyyy-MM-dd').format(purchaseDate),
    dateLogged:    DateFormat('yyyy-MM-dd').format(loggedDate),
    timeLogged:    '${loggedTime.hour.toString().padLeft(2, '0')}:${loggedTime.minute.toString().padLeft(2, '0')}',
    purchaserName: purchaserCtrl.text.trim(),
    vendor:        vendorCtrl.text.trim(),
    price:         double.tryParse(amountCtrl.text.trim()) ?? 0.0,
    category:      categoryCtrl.text.trim(),
    details:       detailsCtrl.text.trim(),
    uploadedFiles: List.from(uploadedFiles),
  );

  void dispose() {
    itemCtrl.dispose(); vendorCtrl.dispose(); purchaserCtrl.dispose();
    amountCtrl.dispose(); categoryCtrl.dispose(); detailsCtrl.dispose();
  }
}

// PURCHASE DETAIL PAGE
class PurchaseDetailPage extends StatelessWidget {
  final Purchase purchase;
  const PurchaseDetailPage({super.key, required this.purchase});

  Future<void> openPdf(String fileName) async {
    final Uri pdfUri = Uri.parse('https://resume-portfolio-ffb8e.web.app/Travel_Gen.pdf'); //just random url until we have actual files to link to
    if (await canLaunchUrl(pdfUri)) await launchUrl(pdfUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A94D4),
        foregroundColor: Colors.white,
        title: Text(purchase.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2A94D4), Color(0xFF3949AB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFF2A94D4).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(purchase.itemName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("\$${purchase.price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 20),
          // Info grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF616161), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(children: [
              _infoRow(Icons.store_outlined, "Vendor", purchase.vendor),
              _infoRow(Icons.person_outline, "Purchaser", purchase.purchaserName),
              _infoRow(Icons.calendar_today, "Date Purchased", purchase.date),
              _infoRow(Icons.category_outlined, "Category", purchase.category),
              _infoRow(Icons.access_time, "Time Logged", purchase.timeLogged),
              _infoRow(Icons.calendar_today, "Date Logged", purchase.dateLogged),
            ]),
          ),
          const SizedBox(height: 16),
          // Details
          if (purchase.details.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF616161), width: 1),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF2A94D4)),
                  SizedBox(width: 8),
                  Text("Details", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2A94D4))),
                ]),
                const SizedBox(height: 10),
                Text(purchase.details, style: const TextStyle(fontSize: 14, height: 1.5)),
              ]),
            ),
          const SizedBox(height: 16),
          // Files
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF616161), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.attach_file, size: 16, color: Color(0xFF2A94D4)),
                SizedBox(width: 8),
                Text("Uploaded Files", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2A94D4))),
              ]),
              const SizedBox(height: 10),
              if (purchase.uploadedFiles.isEmpty)
                Text("No files attached", style: TextStyle(color: Colors.grey[400], fontSize: 13, fontStyle: FontStyle.italic))
              else
                ...purchase.uploadedFiles.map((file) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                    title: Text(file, style: const TextStyle(fontSize: 13)),
                    trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                    onTap: () { openPdf(file); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opened $file'))); },
                  ),
                )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF3949AB)),
      const SizedBox(width: 12),
      Text("$label:", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}