import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'pose_camera_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../utils/api_constants.dart';

import 'pose_camera_ai_page.dart';

class SessionSetupPage extends StatefulWidget {
  const SessionSetupPage({super.key});

  @override
  State<SessionSetupPage> createState() => _SessionSetupPageState();
}

class _SessionSetupPageState extends State<SessionSetupPage> {
  List<WorkoutSet> _routine = [];
  String _sessionMode = 'Real Time';
  Map<String, List<WorkoutSet>> _templates = {};
  bool _isLoading = true;

  Future<bool> _canStartAiSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // replace with your real endpoint
      final uri = Uri.parse(ApiConstants.pingEndpoint);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } on SocketException {
      return false;
    } on HttpException {
      return false;
    } on FormatException {
      return false;
    } catch (_) {
      return false;
    }
  }

  final List<String> _availableExercises = [
    'Push Up',
    'Bench Dip',
    'Bicep Curl',
    'Squat',
    'Lunges'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final String? savedRoutineStr = prefs.getString('saved_routine');
    if (savedRoutineStr != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(savedRoutineStr);
        _routine =
            decodedList.map((item) => WorkoutSet.fromJson(item)).toList();
      } catch (e) {
        debugPrint("Error loading routine: $e");
      }
    }

    final String? templatesStr = prefs.getString('saved_templates');
    if (templatesStr != null) {
      try {
        final Map<String, dynamic> decodedMap = jsonDecode(templatesStr);
        _templates = decodedMap.map((key, value) {
          final list =
              (value as List).map((item) => WorkoutSet.fromJson(item)).toList();
          return MapEntry(key, list);
        });
      } catch (e) {
        debugPrint("Error loading templates: $e");
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveActiveRoutine() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedRoutine =
        jsonEncode(_routine.map((e) => e.toJson()).toList());
    await prefs.setString('saved_routine', encodedRoutine);
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> serializableMap = _templates.map((key, value) {
      return MapEntry(key, value.map((e) => e.toJson()).toList());
    });
    await prefs.setString('saved_templates', jsonEncode(serializableMap));
  }

  void _confirmDeleteTemplate(String templateName, StateSetter setSheetState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkSlate,
        title: const Text('DELETE TEMPLATE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Permanently delete the "$templateName" template?',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: neonRed, foregroundColor: Colors.white),
            onPressed: () {
              setSheetState(() {
                _templates.remove(templateName);
              });
              _saveTemplates();
              Navigator.pop(context);
            },
            child: const Text('DELETE',
                style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showTemplateManager() {
    showModalBottomSheet(
        context: context,
        backgroundColor: darkSlate,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("TEMPLATES",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0)),
                  const SizedBox(height: 16),
                  if (_routine.isNotEmpty)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: mintGreen,
                          foregroundColor: navyBlue),
                      icon: const Icon(Icons.save),
                      label: const Text("SAVE CURRENT AS TEMPLATE",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(context);
                        _promptSaveTemplate();
                      },
                    ),
                  const Divider(color: Colors.grey, height: 32),
                  _templates.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("No templates saved.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey)),
                        )
                      : Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _templates.length,
                            itemBuilder: (context, index) {
                              String templateName =
                                  _templates.keys.elementAt(index);
                              return ListTile(
                                title: Text(templateName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    "${_templates[templateName]!.length} Exercises",
                                    style: const TextStyle(color: mintGreen)),
                                trailing: IconButton(
                                  icon:
                                      const Icon(Icons.delete, color: neonRed),
                                  onPressed: () => _confirmDeleteTemplate(
                                      templateName, setSheetState),
                                ),
                                onTap: () {
                                  setState(() {
                                    // We generate fresh IDs when loading a template so they don't share memory references
                                    _routine = _templates[templateName]!
                                        .map((e) => WorkoutSet(
                                            name: e.name,
                                            target: e.target,
                                            isDuration: e.isDuration))
                                        .toList();
                                  });
                                  _saveActiveRoutine();
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                        ),
                ],
              ),
            );
          });
        });
  }

  void _promptSaveTemplate() {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkSlate,
        title: const Text('NAME TEMPLATE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "e.g., Upper Body Day",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey)),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: mintGreen)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: mintGreen, foregroundColor: navyBlue),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  _templates[nameController.text] = _routine
                      .map((e) => WorkoutSet(
                          name: e.name,
                          target: e.target,
                          isDuration: e.isDuration))
                      .toList();
                });
                _saveTemplates();
                Navigator.pop(context);
              }
            },
            child: const Text('SAVE'),
          )
        ],
      ),
    );
  }

  void _showAddEditDialog({WorkoutSet? existingSet, int? index}) {
    String selectedName = existingSet?.name ?? _availableExercises.first;
    bool isDuration = selectedName.toLowerCase() == 'plank';

    // State preservation: Use the existing target or the default
    int currentTarget = existingSet?.target ?? (isDuration ? 60 : 10);

    // Track if the user has manually touched the values
    bool hasUserModifiedValues = false;

    int tempMin = isDuration ? currentTarget ~/ 60 : 0;
    int tempSec = isDuration ? currentTarget % 60 : 0;
    int tempH = !isDuration ? currentTarget ~/ 100 : 0;
    int tempT = !isDuration ? (currentTarget % 100) ~/ 10 : 0;
    int tempO = !isDuration ? currentTarget % 10 : 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: darkSlate,
            title: Text(existingSet == null ? 'ADD EXERCISE' : 'EDIT EXERCISE',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedName,
                  dropdownColor: navyBlue,
                  autofocus:
                      true, // TRIGGER: This ensures the dropdown is ready for interaction immediately
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: _availableExercises
                      .map((name) =>
                          DropdownMenuItem(value: name, child: Text(name)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedName = val;
                        bool wasDuration = isDuration;
                        isDuration = selectedName.toLowerCase() == 'plank';

                        // REFACTOR: Logic to prevent resetting user data
                        if (wasDuration != isDuration) {
                          // Only switch defaults if the user hasn't modified values yet
                          if (!hasUserModifiedValues) {
                            if (isDuration) {
                              tempMin = 1;
                              tempSec = 0;
                            } else {
                              tempH = 0;
                              tempT = 1;
                              tempO = 0;
                            }
                          }
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                // NEW: Dynamic headers. Only shown for duration.
                if (isDuration) ...[
                  const Row(
                    children: [
                      Expanded(
                          child: Text("MINUTES",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5))),
                      SizedBox(width: 24),
                      Expanded(
                          child: Text("SECONDS",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5))),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // --- THE MULTI-COLUMN TUMBLER UI ---
                SizedBox(
                  height: 160, // Increased height for bigger wheels
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      textTheme: CupertinoTextThemeData(
                          pickerTextStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold)), // Massive font
                    ),
                    child: isDuration
                        // DURATION WIDGET
                        ? Row(
                            children: [
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                      initialItem: tempMin),
                                  itemExtent: 50,
                                  selectionOverlay:
                                      CupertinoPickerDefaultSelectionOverlay(
                                          background:
                                              mintGreen.withOpacity(0.15)),
                                  onSelectedItemChanged: (idx) => tempMin = idx,
                                  children: List.generate(
                                      60,
                                      (idx) => Center(
                                          child: Text(
                                              idx.toString().padLeft(2, '0')))),
                                ),
                              ),
                              const Text(":",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold)),
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                      initialItem: tempSec),
                                  itemExtent: 50,
                                  selectionOverlay:
                                      CupertinoPickerDefaultSelectionOverlay(
                                          background:
                                              mintGreen.withOpacity(0.15)),
                                  onSelectedItemChanged: (idx) => tempSec = idx,
                                  children: List.generate(
                                      60,
                                      (idx) => Center(
                                          child: Text(
                                              idx.toString().padLeft(2, '0')))),
                                ),
                              ),
                            ],
                          )
                        // REP WIDGET
                        : Row(
                            children: [
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                      initialItem: tempH),
                                  itemExtent: 50,
                                  selectionOverlay:
                                      CupertinoPickerDefaultSelectionOverlay(
                                          background:
                                              mintGreen.withOpacity(0.15)),
                                  onSelectedItemChanged: (idx) => tempH = idx,
                                  children: List.generate(
                                      10,
                                      (idx) =>
                                          Center(child: Text(idx.toString()))),
                                ),
                              ),
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                      initialItem: tempT),
                                  itemExtent: 50,
                                  selectionOverlay:
                                      CupertinoPickerDefaultSelectionOverlay(
                                          background:
                                              mintGreen.withOpacity(0.15)),
                                  onSelectedItemChanged: (idx) => tempT = idx,
                                  children: List.generate(
                                      10,
                                      (idx) =>
                                          Center(child: Text(idx.toString()))),
                                ),
                              ),
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                      initialItem: tempO),
                                  itemExtent: 50,
                                  selectionOverlay:
                                      CupertinoPickerDefaultSelectionOverlay(
                                          background:
                                              mintGreen.withOpacity(0.15)),
                                  onSelectedItemChanged: (idx) => tempO = idx,
                                  children: List.generate(
                                      10,
                                      (idx) =>
                                          Center(child: Text(idx.toString()))),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL',
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: mintGreen, foregroundColor: navyBlue),
                onPressed: () {
                  int finalTarget = isDuration
                      ? (tempMin * 60) + tempSec
                      : (tempH * 100) + (tempT * 10) + tempO;

                  if (finalTarget <= 0) finalTarget = 1;

                  setState(() {
                    if (index != null) {
                      _routine[index].name = selectedName;
                      _routine[index].target = finalTarget;
                      _routine[index].isDuration = isDuration;
                    } else {
                      _routine.add(WorkoutSet(
                          name: selectedName,
                          target: finalTarget,
                          isDuration: isDuration));
                    }
                  });

                  _saveActiveRoutine();
                  Navigator.pop(context);
                },
                child: Text(existingSet == null ? 'ADD' : 'SAVE',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          );
        });
      },
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: mintGreen,
        side: const BorderSide(color: mintGreen, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.add),
      label: const Text('ADD EXERCISE',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      onPressed: () => _showAddEditDialog(),
    );
  }

  Widget _buildSessionModeSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeOption(
              label: 'Real Time',
              icon: Icons.flash_on_rounded,
              selected: _sessionMode == 'Real Time',
              onTap: () {
                setState(() {
                  _sessionMode = 'Real Time';
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModeOption(
              label: 'AI',
              icon: Icons.psychology_alt_rounded,
              selected: _sessionMode == 'AI',
              onTap: () {
                setState(() {
                  _sessionMode = 'AI';
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? mintGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: mintGreen.withOpacity(0.18),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? navyBlue : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? navyBlue : Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: navyBlue,
          body: Center(child: CircularProgressIndicator(color: mintGreen)));
    }

    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text('SESSION SETUP',
            style: TextStyle(
                color: mintGreen,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined, color: Colors.white),
            tooltip: "Templates",
            onPressed: _showTemplateManager,
          )
        ],
      ),
      body: Column(
        children: [
          _buildSessionModeSelector(),
          Expanded(
            child: _routine.isEmpty
                ? Center(child: _buildAddButton())
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 100, top: 8),
                    itemCount: _routine.length,
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _routine.removeAt(oldIndex);
                        _routine.insert(newIndex, item);
                      });
                      _saveActiveRoutine();
                    },
                    footer: Padding(
                      key: const Key("add_button_footer"),
                      padding: const EdgeInsets.symmetric(
                          vertical: 24.0, horizontal: 16.0),
                      child: Center(child: _buildAddButton()),
                    ),
                    itemBuilder: (context, index) {
                      final item = _routine[index];
                      return Card(
                        key: ValueKey(item.id),
                        color: darkSlate,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          title: Text(
                            item.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                    item.isDuration
                                        ? Icons.timer
                                        : Icons.repeat,
                                    color: mintGreen,
                                    size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '${item.target} ${item.isDuration ? "SEC" : "REPS"}',
                                  style: const TextStyle(
                                      color: mintGreen,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.grey),
                                onPressed: () => _showAddEditDialog(
                                    existingSet: item, index: index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: neonRed),
                                onPressed: () {
                                  setState(() {
                                    _routine.removeAt(index);
                                  });
                                  _saveActiveRoutine();
                                },
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding:
                                      EdgeInsets.only(left: 8.0, right: 8.0),
                                  child: Icon(Icons.drag_handle,
                                      color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'start_btn',
        backgroundColor: _routine.isEmpty ? Colors.grey.shade800 : mintGreen,
        foregroundColor: _routine.isEmpty ? Colors.grey.shade500 : navyBlue,
        onPressed: _routine.isEmpty
            ? null
            : () async {
                if (_sessionMode == 'Real Time') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PoseCameraPage(routine: _routine),
                    ),
                  );
                } else {
                  // AI mode: require server connection first
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(
                      child: CircularProgressIndicator(color: mintGreen),
                    ),
                  );

                  final canStart = await _canStartAiSession();

                  if (context.mounted) Navigator.pop(context);

                  if (!canStart) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Cannot start AI session. Server is unavailable.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PoseCameraAiPage(routine: _routine),
                    ),
                  );
                }
              },
        icon: const Icon(Icons.play_arrow),
        label: const Text('START SESSION',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// --- WORKOUT SET MODEL (Now with Immutable Unique IDs) ---
class WorkoutSet {
  final String id;
  String name;
  int target;
  bool isDuration;

  WorkoutSet({
    String? id,
    required this.name,
    required this.target,
    this.isDuration = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'isDuration': isDuration,
      };

  // The 'id' check handles backward compatibility in case you load an old save that didn't have an ID
  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
        id: json['id'] as String?,
        name: json['name'] as String,
        target: json['target'] as int,
        isDuration: json['isDuration'] as bool,
      );
}
