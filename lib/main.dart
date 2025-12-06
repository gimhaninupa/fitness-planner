// main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 
// Note: FL_Chart is removed from this final version to simplify dependencies,
// and the charts are replaced by simple CustomPaint implementations.

/// ----------------- MODELS -----------------
class UserProfile {
  String name;
  int age;
  double heightCm;
  double weightKg;
  String goal; // Lose / Gain / Maintain
  UserProfile({
    required this.name,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
  });

  double get bmi {
    final m = heightCm / 100;
    return weightKg / (m * m);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'goal': goal,
      };

  static UserProfile fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'],
        age: j['age'],
        heightCm: (j['heightCm'] as num).toDouble(),
        weightKg: (j['weightKg'] as num).toDouble(),
        goal: j['goal'],
      );
}

class Exercise {
  String id;
  String name;
  String muscleGroup;
  String instructions;
  String imageUrl;
  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.instructions,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup,
        'instructions': instructions,
        'imageUrl': imageUrl,
      };

  static Exercise fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'],
        name: j['name'],
        muscleGroup: j['muscleGroup'],
        instructions: j['instructions'],
        imageUrl: j['imageUrl'],
      );
}

class WorkoutExercise {
  String exerciseId;
  int sets;
  int reps;
  int restSeconds;
  WorkoutExercise({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets,
        'reps': reps,
        'restSeconds': restSeconds,
      };

  static WorkoutExercise fromJson(Map<String, dynamic> j) => WorkoutExercise(
        exerciseId: j['exerciseId'],
        sets: j['sets'],
        reps: j['reps'],
        restSeconds: j['restSeconds'],
      );
}

class Workout {
  String id;
  String title;
  String notes;
  List<WorkoutExercise> exercises;
  DateTime createdAt;
  Workout({
    required this.id,
    required this.title,
    required this.notes,
    required this.exercises,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  static Workout fromJson(Map<String, dynamic> j) => Workout(
        id: j['id'],
        title: j['title'],
        notes: j['notes'],
        exercises: (j['exercises'] as List)
            .map((e) => WorkoutExercise.fromJson(e))
            .toList(),
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class WeightLog {
  DateTime date;
  double weight;
  WeightLog({required this.date, required this.weight});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weight': weight,
      };

  static WeightLog fromJson(Map<String, dynamic> j) => WeightLog(
        date: DateTime.parse(j['date']),
        weight: (j['weight'] as num).toDouble(),
      );
}

/// ----------------- APP STATE -----------------
class AppState extends ChangeNotifier {
  bool initialized = false;
  bool darkMode = false;

  UserProfile? profile;
  List<Exercise> library = [];
  List<Workout> workouts = [];
  List<WeightLog> weightLogs = [];
  int waterCupsToday = 0;

  SharedPreferences? _prefs;

  AppState() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadAll();
    initialized = true;
    notifyListeners();
  }

  void _loadAll() {
    // profile
    final profileJson = _prefs?.getString('profile');
    if (profileJson != null) {
      try {
        profile = UserProfile.fromJson(jsonDecode(profileJson));
      } catch (e) {
        profile = null;
      }
    }

    // dark mode
    darkMode = _prefs?.getBool('darkMode') ?? false;

    // library
    final lib = _prefs?.getString('library');
    if (lib != null) {
      try {
        final arr = jsonDecode(lib) as List;
        library = arr.map((e) => Exercise.fromJson(e)).toList();
      } catch (e) {
        library = [];
      }
    } else {
      library = _seedLibrary();
      _saveLibrary();
    }

    // workouts
    final w = _prefs?.getString('workouts');
    if (w != null) {
      try {
        final arr = jsonDecode(w) as List;
        workouts = arr.map((e) => Workout.fromJson(e)).toList();
      } catch (e) {
        workouts = [];
      }
    } else {
      workouts = [];
    }

    // weight logs
    final wlog = _prefs?.getString('weightLogs');
    if (wlog != null) {
      try {
        final arr = jsonDecode(wlog) as List;
        weightLogs = arr.map((e) => WeightLog.fromJson(e)).toList();
      } catch (e) {
        weightLogs = [];
      }
    } else {
      weightLogs = [];
    }

    waterCupsToday = _prefs?.getInt(_waterKeyForToday()) ?? 0;
  }

  String _waterKeyForToday() {
    final d = DateTime.now();
    return 'water_${d.year}_${d.month}_${d.day}';
  }

  void toggleDarkMode() {
    darkMode = !darkMode;
    _prefs?.setBool('darkMode', darkMode);
    notifyListeners();
  }

  void saveProfile(UserProfile newProfile) {
    profile = newProfile;
    _prefs?.setString('profile', jsonEncode(profile!.toJson()));
    notifyListeners();
  }

  void addExercise(Exercise e) {
    library.add(e);
    _saveLibrary();
    notifyListeners();
  }

  void _saveLibrary() {
    _prefs?.setString(
        'library', jsonEncode(library.map((e) => e.toJson()).toList()));
  }

  void addWorkout(Workout w) {
    workouts.insert(0, w);
    _prefs?.setString(
        'workouts', jsonEncode(workouts.map((w) => w.toJson()).toList()));
    notifyListeners();
  }

  void updateWorkout(Workout w) {
    int idx = workouts.indexWhere((x) => x.id == w.id);
    if (idx >= 0) {
      workouts[idx] = w;
      _prefs?.setString(
          'workouts', jsonEncode(workouts.map((w) => w.toJson()).toList()));
      notifyListeners();
    }
  }

  void removeWorkout(String id) {
    workouts.removeWhere((w) => w.id == id);
    _prefs?.setString(
        'workouts', jsonEncode(workouts.map((w) => w.toJson()).toList()));
    notifyListeners();
  }

  void addWeightLog(WeightLog log) {
    weightLogs.insert(0, log);
    _prefs?.setString(
        'weightLogs', jsonEncode(weightLogs.map((w) => w.toJson()).toList()));
    notifyListeners();
  }

  void addWaterCup() {
    waterCupsToday++;
    _prefs?.setInt(_waterKeyForToday(), waterCupsToday);
    notifyListeners();
  }

  void resetWaterToday() {
    waterCupsToday = 0;
    _prefs?.setInt(_waterKeyForToday(), 0);
    notifyListeners();
  }

  // --- NEW ACTIONS ---
  Future<void> logout() async {
    // Clear only user-specific data to enforce login flow
    profile = null;
    await _prefs?.remove('profile');
    notifyListeners();
  }

  Future<void> resetAllData() async {
    // Clear all stored keys and reset state
    await _prefs?.clear();
    // Re-initialize state to default/empty values
    profile = null;
    library = _seedLibrary();
    workouts = [];
    weightLogs = [];
    waterCupsToday = 0;
    darkMode = false;
    // Reload data structure (important for consistency)
    _loadAll();
    notifyListeners();
  }
  // --- END NEW ACTIONS ---


  List<Exercise> _seedLibrary() => [
        Exercise(
          id: 'ex_pushup',
          name: 'Push Up',
          muscleGroup: 'Chest/Triceps',
          instructions: 'Keep body straight, lower to the chest, press up.',
          imageUrl: '',
        ),
        Exercise(
          id: 'ex_squat',
          name: 'Squat',
          muscleGroup: 'Legs',
          instructions: 'Feet shoulder width, push hips back, keep chest up.',
          imageUrl: '',
        ),
        Exercise(
          id: 'ex_plank',
          name: 'Plank',
          muscleGroup: 'Core',
          instructions: 'Keep hips level, hold body in straight line.',
          imageUrl: '',
        ),
      ];
}

/// ----------------- MAIN -----------------
void main() {
  runApp(ChangeNotifierProvider(
      create: (_) => AppState(), child: FitnessApp()));
}

class FitnessApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, state, _) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FitUnique',
        theme: ThemeData.light().copyWith(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        darkTheme: ThemeData.dark().copyWith(useMaterial3: true),
        themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: SplashRouter(),
      );
    });
  }
}

// FIX: SplashRouter ensures correct routing based on initialized state and profile existence.
class SplashRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);

    if (!app.initialized) {
      // Show simple loading screen while SharedPreferences load
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Check if profile exists; if not, go to onboarding/creation.
    if (app.profile == null) {
      return OnboardingScreens();
    }
    // If profile exists, go straight home.
    return HomeScreen();
  }
}


/// ----------------- ONBOARDING & SIMPLE AUTH -----------------
class OnboardingScreens extends StatefulWidget {
  @override
  _OnboardingScreensState createState() => _OnboardingScreensState();
}

class _OnboardingScreensState extends State<OnboardingScreens> {
  int page = 0;
  final _pages = [
    {'title': 'Track workouts', 'desc': 'Create and follow workout plans easily.'},
    {'title': 'Measure progress', 'desc': 'Log weight and see progress over time.'},
    {'title': 'Stay hydrated', 'desc': 'Track water and wellness.'},
  ];

  @override
  Widget build(BuildContext context) {
    final p = _pages[page];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.fitness_center_outlined, size: 120, color: Theme.of(context).colorScheme.primary),
                SizedBox(height: 22),
                Text(p['title']!, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text(p['desc']!, textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              ]),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton(onPressed: () => _skip(), child: Text('Skip')),
              Row(children: List.generate(_pages.length, (i) => Container(margin: EdgeInsets.symmetric(horizontal: 4), width: page == i ? 24 : 10, height: 6, decoration: BoxDecoration(color: page == i ? Theme.of(context).colorScheme.primary : Colors.grey.shade400, borderRadius: BorderRadius.circular(8))))),
              ElevatedButton(
                onPressed: () {
                  if (page < _pages.length - 1) setState(() => page++);
                  else _toCreateProfile();
                },
                child: Text(page < _pages.length - 1 ? 'Next' : 'Get started'),
              ),
            ])
          ]),
        ),
      ),
    );
  }

  void _skip() => _toCreateProfile();

  void _toCreateProfile() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CreateProfileScreen()));
  }
}

class CreateProfileScreen extends StatefulWidget {
  @override
  _CreateProfileScreenState createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  int age = 20;
  double height = 170;
  double weight = 70;
  String goal = 'Maintain';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Profile')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
            key: _formKey,
            child: ListView(children: [
              TextFormField(decoration: InputDecoration(labelText: 'Name'), onSaved: (v) => name = v?.trim() ?? '', validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null),
              TextFormField(decoration: InputDecoration(labelText: 'Age'), keyboardType: TextInputType.number, initialValue: '20', onSaved: (v) => age = int.tryParse(v ?? '20') ?? 20),
              TextFormField(decoration: InputDecoration(labelText: 'Height (cm)'), keyboardType: TextInputType.number, initialValue: '170', onSaved: (v) => height = double.tryParse(v ?? '170') ?? 170),
              TextFormField(decoration: InputDecoration(labelText: 'Weight (kg)'), keyboardType: TextInputType.number, initialValue: '70', onSaved: (v) => weight = double.tryParse(v ?? '70') ?? 70),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                items: ['Lose', 'Maintain', 'Gain'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                value: goal,
                onChanged: (v) => setState(() => goal = v ?? 'Maintain'),
                decoration: InputDecoration(labelText: 'Goal'),
              ),
              SizedBox(height: 18),
              ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      final profile = UserProfile(name: name, age: age, heightCm: height, weightKg: weight, goal: goal);
                      Provider.of<AppState>(context, listen: false).saveProfile(profile);
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
                    }
                  },
                  child: Text('Save Profile'))
            ])),
      ),
    );
  }
}

/// ----------------- HOME DASHBOARD -----------------
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final profile = app.profile;
    return Scaffold(
      appBar: AppBar(
        title: Text('FitUnique'),
        actions: [
          IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen())),
              icon: Icon(Icons.settings)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // small refresh
          await Future.delayed(Duration(milliseconds: 300));
        },
        child: ListView(padding: EdgeInsets.all(16), children: [
          Row(children: [
            CircleAvatar(radius: 30, child: Text(profile != null ? profile.name.split(' ').first.substring(0, 1).toUpperCase() : 'U')),
            SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${profile?.name ?? 'User'} 👋', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Goal: ${profile?.goal ?? '-'} • BMI: ${profile != null ? profile.bmi.toStringAsFixed(1) : '-'}'),
            ])),
            IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())),
                icon: Icon(Icons.edit))
          ]),
          SizedBox(height: 18),
          // summary cards
          Row(children: [
            Expanded(child: _SummaryCard(title: 'Workouts', value: '${app.workouts.length}')),
            SizedBox(width: 12),
            Expanded(child: _SummaryCard(title: 'Water', value: '${app.waterCupsToday} cups')),
          ]),
          SizedBox(height: 14),
          // quick actions
          Wrap(spacing: 12, runSpacing: 12, children: [
            _ActionTile(icon: Icons.playlist_add, label: 'Plan Workout', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutsListScreen()))),
            _ActionTile(icon: Icons.fitness_center, label: 'Start Session', onTap: () {
              if (app.workouts.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutSessionLauncher()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create a workout first.')));
              }
            }),
            _ActionTile(icon: Icons.local_drink, label: 'Add Water', onTap: () => app.addWaterCup()),
            _ActionTile(icon: Icons.show_chart, label: 'Progress', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProgressScreen()))),
            _ActionTile(icon: Icons.library_books, label: 'Library', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseLibraryScreen()))),
          ]),
          SizedBox(height: 22),
          Text('Recent Workouts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          if (app.workouts.isEmpty) Center(child: Text('No workouts yet. Create your first workout.')) else Column(children: app.workouts.take(4).map((w) => _WorkoutListTile(workout: w)).toList()),
          SizedBox(height: 20),
          ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateWorkoutScreen())), icon: Icon(Icons.add), label: Text('Create Workout'))
        ]),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  _SummaryCard({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: Colors.grey[700])),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ])));
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _ActionTile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
          width: 140,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.primary.withOpacity(0.08)),
          child: Row(children: [
            CircleAvatar(radius: 18, backgroundColor: Theme.of(context).colorScheme.primary, child: Icon(icon, size: 18, color: Colors.white)),
            SizedBox(width: 10),
            Flexible(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600))),
          ])),
    );
  }
}

class _WorkoutListTile extends StatelessWidget {
  final Workout workout;
  _WorkoutListTile({required this.workout});
  @override
  Widget build(BuildContext context) {
    return Card(
        child: ListTile(
      title: Text(workout.title),
      subtitle: Text('${workout.exercises.length} exercises • ${workout.createdAt.toLocal().toIso8601String().substring(0, 10)}'),
      trailing: PopupMenuButton<int>(
        onSelected: (i) {
          if (i == 0) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutEditScreen(workout: workout)));
          } else if (i == 1) {
            Provider.of<AppState>(context, listen: false).removeWorkout(workout.id);
          } else if (i == 2) {
            // start session with this workout
            Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutSessionScreen(workout: workout)));
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 0, child: Text('Edit')),
          PopupMenuItem(value: 1, child: Text('Delete')),
          PopupMenuItem(value: 2, child: Text('Start')),
        ],
      ),
    ));
  }
}

/// ----------------- WORKOUTS LIST & CREATE -----------------
class WorkoutsListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Workouts')),
      body: ListView(children: app.workouts.map((w) => _WorkoutListTile(workout: w)).toList()),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateWorkoutScreen())), child: Icon(Icons.add)),
    );
  }
}

class CreateWorkoutScreen extends StatefulWidget {
  @override
  _CreateWorkoutScreenState createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  List<WorkoutExercise> selected = [];

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _addExerciseDialog() {
    final app = Provider.of<AppState>(context, listen: false);
    showModalBottomSheet(
        context: context,
        builder: (_) {
          return ListView(
            children: app.library.map((ex) {
              return ListTile(
                title: Text(ex.name),
                subtitle: Text(ex.muscleGroup),
                onTap: () {
                  // add with default values
                  selected.add(WorkoutExercise(exerciseId: ex.id, sets: 3, reps: 10, restSeconds: 60));
                  setState(() {});
                  Navigator.pop(context);
                },
              );
            }).toList()
              ..add(ListTile(
                leading: Icon(Icons.add),
                title: Text('Create custom exercise'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CreateExerciseScreen()));
                },
              )),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Create Workout')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: ListView(children: [
          TextField(controller: _title, decoration: InputDecoration(labelText: 'Title')),
          TextField(controller: _notes, decoration: InputDecoration(labelText: 'Notes')),
          SizedBox(height: 12),
          Text('Exercises', style: TextStyle(fontWeight: FontWeight.w600)),
          ...selected.map((se) {
            final ex = app.library.firstWhere((l) => l.id == se.exerciseId, orElse: () => Exercise(id: 'x', name: 'Unknown', muscleGroup: '', instructions: '', imageUrl: ''));
            return Card(
                child: ListTile(
              title: Text(ex.name),
              subtitle: Text('${se.sets} sets • ${se.reps} reps • ${se.restSeconds}s rest'),
              trailing: IconButton(icon: Icon(Icons.delete), onPressed: () => setState(() => selected.remove(se))),
            ));
          }).toList(),
          SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _addExerciseDialog, icon: Icon(Icons.add), label: Text('Add Exercise')),
          SizedBox(height: 18),
          ElevatedButton(
              onPressed: () {
                final id = DateTime.now().millisecondsSinceEpoch.toString();
                final w = Workout(id: id, title: _title.text.isEmpty ? 'Workout $id' : _title.text, notes: _notes.text, exercises: selected, createdAt: DateTime.now());
                Provider.of<AppState>(context, listen: false).addWorkout(w);
                Navigator.pop(context);
              },
              child: Text('Save Workout'))
        ]),
      ),
    );
  }
}

class WorkoutEditScreen extends StatefulWidget {
  final Workout workout;
  WorkoutEditScreen({required this.workout});
  @override
  _WorkoutEditScreenState createState() => _WorkoutEditScreenState();
}

class _WorkoutEditScreenState extends State<WorkoutEditScreen> {
  late TextEditingController _title;
  late TextEditingController _notes;
  late List<WorkoutExercise> selected;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.workout.title);
    _notes = TextEditingController(text: widget.workout.notes);
    selected = List.from(widget.workout.exercises);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _addExerciseFromLibrary() {
    final app = Provider.of<AppState>(context, listen: false);
    showModalBottomSheet(
        context: context,
        builder: (_) {
          return ListView(children: app.library.map((ex) {
            return ListTile(title: Text(ex.name), subtitle: Text(ex.muscleGroup), onTap: () {
              selected.add(WorkoutExercise(exerciseId: ex.id, sets: 3, reps: 10, restSeconds: 60));
              setState(() {});
              Navigator.pop(context);
            });
          }).toList());
        });
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Edit Workout')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: ListView(children: [
          TextField(controller: _title, decoration: InputDecoration(labelText: 'Title')),
          TextField(controller: _notes, decoration: InputDecoration(labelText: 'Notes')),
          SizedBox(height: 12),
          Text('Exercises', style: TextStyle(fontWeight: FontWeight.w600)),
          ...selected.map((se) {
            final ex = app.library.firstWhere((l) => l.id == se.exerciseId, orElse: () => Exercise(id: 'x', name: 'Unknown', muscleGroup: '', instructions: '', imageUrl: ''));
            return Card(
                child: ListTile(
              title: Text(ex.name),
              subtitle: Text('${se.sets}x${se.reps} • ${se.restSeconds}s rest'),
              trailing: IconButton(icon: Icon(Icons.delete), onPressed: () => setState(() => selected.remove(se))),
            ));
          }).toList(),
          SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _addExerciseFromLibrary, icon: Icon(Icons.add), label: Text('Add Exercise')),
          SizedBox(height: 18),
          ElevatedButton(
              onPressed: () {
                final updated = Workout(id: widget.workout.id, title: _title.text, notes: _notes.text, exercises: selected, createdAt: widget.workout.createdAt);
                Provider.of<AppState>(context, listen: false).updateWorkout(updated);
                Navigator.pop(context);
              },
              child: Text('Save Changes'))
        ]),
      ),
    );
  }
}

/// ----------------- EXERCISE LIBRARY -----------------
class ExerciseLibraryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Exercise Library')),
      body: ListView(
        children: app.library
            .map((e) => ListTile(
                  title: Text(e.name),
                  subtitle: Text(e.muscleGroup),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ExerciseDetailScreen(ex: e))),
                ))
            .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => CreateExerciseScreen())),
        child: Icon(Icons.add),
      ),
    );
  }
}

class ExerciseDetailScreen extends StatelessWidget {
  final Exercise ex;
  ExerciseDetailScreen({required this.ex});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ex.name)),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 160, width: double.infinity, color: Colors.grey.shade200, child: Center(child: Icon(Icons.image, size: 64))),
          SizedBox(height: 10),
          Text(ex.muscleGroup, style: TextStyle(color: Colors.grey[700])),
          SizedBox(height: 8),
          Text(ex.instructions),
          SizedBox(height: 14),
          ElevatedButton(onPressed: () => _addToFavorite(context), child: Text('Add to Workout')),
        ]),
      ),
    );
  }

  void _addToFavorite(BuildContext context) {
    // simple: open modal to pick a workout
    final app = Provider.of<AppState>(context, listen: false);
    if (app.workouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create a workout first.')));
      return;
    }
    showModalBottomSheet(context: context, builder: (_) {
      return ListView(children: app.workouts.map((w) {
        return ListTile(title: Text(w.title), onTap: () {
          w.exercises.add(WorkoutExercise(exerciseId: ex.id, sets: 3, reps: 10, restSeconds: 60));
          Provider.of<AppState>(context, listen: false).updateWorkout(w);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${w.title}')));
        });
      }).toList());
    });
  }
}

class CreateExerciseScreen extends StatefulWidget {
  @override
  _CreateExerciseScreenState createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen> {
  final _name = TextEditingController();
  final _muscle = TextEditingController();
  final _inst = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _muscle.dispose();
    _inst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Exercise'),
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: ListView(children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: 'Name')),
          TextField(controller: _muscle, decoration: InputDecoration(labelText: 'Muscle Group')),
          TextField(controller: _inst, decoration: InputDecoration(labelText: 'Instructions'), maxLines: 4),
          SizedBox(height: 12),
          ElevatedButton(
              onPressed: () {
                final id = 'ex_${DateTime.now().millisecondsSinceEpoch}';
                final ex = Exercise(id: id, name: _name.text, muscleGroup: _muscle.text, instructions: _inst.text, imageUrl: '');
                Provider.of<AppState>(context, listen: false).addExercise(ex);
                Navigator.pop(context);
              },
              child: Text('Save Exercise'))
        ]),
      ),
    );
  }
}

/// ----------------- WORKOUT SESSION -----------------
class WorkoutSessionLauncher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Start Session')),
      body: ListView(children: app.workouts.map((w) {
        return ListTile(title: Text(w.title), subtitle: Text('${w.exercises.length} exercises'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutSessionScreen(workout: w))));
      }).toList()),
    );
  }
}

class WorkoutSessionScreen extends StatefulWidget {
  final Workout workout;
  WorkoutSessionScreen({required this.workout});
  @override
  _WorkoutSessionScreenState createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  int currentIndex = 0;
  int currentSet = 1;
  Timer? _timer;
  int _secondsLeft = 0;
  bool inRest = false;

  void _startRest(int secs) {
    _timer?.cancel();
    setState(() {
      _secondsLeft = secs;
      inRest = true;
    });
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          inRest = false;
          _timer?.cancel();
        }
      });
    });
  }

  void _next() {
    final w = widget.workout;
    final we = w.exercises[currentIndex];
    if (currentSet < we.sets) {
      // go to rest
      _startRest(we.restSeconds);
      setState(() => currentSet++);
    } else {
      // move to next exercise
      if (currentIndex < w.exercises.length - 1) {
        setState(() {
          currentIndex++;
          currentSet = 1;
        });
      } else {
        // session finished
        showDialog(context: context, builder: (_) => AlertDialog(title: Text('Completed!'), content: Text('You finished the workout.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'))]));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final w = widget.workout;
    final we = w.exercises[currentIndex];
    final ex = app.library.firstWhere((l) => l.id == we.exerciseId, orElse: () => Exercise(id: 'x', name: 'Unknown', muscleGroup: '', instructions: '', imageUrl: ''));
    return Scaffold(
      appBar: AppBar(title: Text('Session - ${w.title}')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ex.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(ex.muscleGroup),
          SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey.shade100),
              child: Center(child: Text(ex.instructions, style: TextStyle(fontSize: 16))),
            ),
          ),
          SizedBox(height: 12),
          Text('Set $currentSet of ${we.sets}', textAlign: TextAlign.center),
          SizedBox(height: 8),
          if (inRest) ...[
            Text('Resting: $_secondsLeft s', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            ElevatedButton(onPressed: () => setState(() => inRest = false), child: Text('Skip Rest')),
          ] else
            ElevatedButton(onPressed: _next, child: Text(currentSet < we.sets ? 'Complete Set' : (currentIndex < w.exercises.length - 1 ? 'Next Exercise' : 'Finish'))),
          SizedBox(height: 8),
        ]),
      ),
    );
  }
}

/// ----------------- PROGRESS SCREEN (weight logs + simple chart) -----------------
class ProgressScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final logs = app.weightLogs;
    return Scaffold(
      appBar: AppBar(title: Text('Progress')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(children: [
          Card(child: Padding(padding: EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Weight', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            SizedBox(height: 160, child: WeightChart(logs: logs)),
            SizedBox(height: 8),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: () => _addWeightDialog(context), child: Text('Add Weight'))),
              SizedBox(width: 8),
              OutlinedButton(onPressed: () => Provider.of<AppState>(context, listen: false).weightLogs.clear(), child: Text('Clear')),
            ])
          ]))),
          SizedBox(height: 12),
          Expanded(child: logs.isEmpty ? Center(child: Text('No weight logs yet.')) : ListView(children: logs.map((l) => ListTile(title: Text('${l.weight} kg'), subtitle: Text('${l.date.toLocal().toIso8601String().substring(0, 10)}'))).toList()))
        ]),
      ),
    );
  }

  void _addWeightDialog(BuildContext context) {
    final _ctrl = TextEditingController();
    showDialog(context: context, builder: (_) {
      return AlertDialog(
        title: Text('Add Weight (kg)'),
        content: TextField(controller: _ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'e.g. 72.5')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')), ElevatedButton(onPressed: () {
          final v = double.tryParse(_ctrl.text);
          if (v != null) {
            Provider.of<AppState>(context, listen: false).addWeightLog(WeightLog(date: DateTime.now(), weight: v));
            Navigator.pop(context);
          }
        }, child: Text('Add'))],
      );
    });
  }
}

class WeightChart extends StatelessWidget {
  final List<WeightLog> logs;
  WeightChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(child: Text('No data'));
    }
    // Simplified line chart using CustomPaint
    return CustomPaint(
      painter: _LineChartPainter(logs: logs, theme: Theme.of(context)),
      size: Size(double.infinity, double.infinity),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<WeightLog> logs;
  final ThemeData theme;
  _LineChartPainter({required this.logs, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final sorted = List<WeightLog>.from(logs)..sort((a, b) => a.date.compareTo(b.date));
    final minW = sorted.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    final maxW = sorted.map((e) => e.weight).reduce((a, b) => a > b ? a : b);
    final span = (maxW - minW) == 0 ? 1 : (maxW - minW);
    final paint = Paint()..color = theme.colorScheme.primary..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = theme.colorScheme.primary;
    final path = Path();
    for (int i = 0; i < sorted.length; i++) {
      final x = (size.width) * (i / (sorted.length - 1 == 0 ? 1 : (sorted.length - 1)));
      final y = size.height - ((sorted[i].weight - minW) / span) * size.height;
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.logs != logs;
}

/// ----------------- PROFILE & SETTINGS -----------------
class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _name, _age, _height, _weight;
  String goal = 'Maintain';

  @override
  void initState() {
    super.initState();
    final p = Provider.of<AppState>(context, listen: false).profile!;
    _name = TextEditingController(text: p.name);
    _age = TextEditingController(text: p.age.toString());
    _height = TextEditingController(text: p.heightCm.toString());
    _weight = TextEditingController(text: p.weightKg.toString());
    goal = p.goal;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final p = app.profile!;
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: ListView(children: [
          CircleAvatar(radius: 40, child: Text(p.name.substring(0, 1).toUpperCase())),
          SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(labelText: 'Name')),
          TextField(controller: _age, decoration: InputDecoration(labelText: 'Age'), keyboardType: TextInputType.number),
          TextField(controller: _height, decoration: InputDecoration(labelText: 'Height (cm)'), keyboardType: TextInputType.number),
          TextField(controller: _weight, decoration: InputDecoration(labelText: 'Weight (kg)'), keyboardType: TextInputType.number),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(items: ['Lose', 'Maintain', 'Gain'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), value: goal, onChanged: (v) => setState(() => goal = v ?? 'Maintain'), decoration: InputDecoration(labelText: 'Goal')),
          SizedBox(height: 14),
          ElevatedButton(
              onPressed: () {
                final newP = UserProfile(name: _name.text, age: int.tryParse(_age.text) ?? p.age, heightCm: double.tryParse(_height.text) ?? p.heightCm, weightKg: double.tryParse(_weight.text) ?? p.weightKg, goal: goal);
                Provider.of<AppState>(context, listen: false).saveProfile(newP);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile saved')));
              },
              child: Text('Save'))
        ]),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(children: [
        SwitchListTile(title: Text('Dark mode'), value: app.darkMode, onChanged: (_) => app.toggleDarkMode()),
        ListTile(title: Text('Reset water count today'), onTap: () => app.resetWaterToday()),
        ListTile(title: Text('About'), subtitle: Text('FitUnique • Version 1.0')),
        Divider(),
        // --- NEW LOGOUT AND RESET BUTTONS ---
        ListTile(
          leading: Icon(Icons.exit_to_app, color: Colors.orange),
          title: Text('Logout'),
          onTap: () {
            app.logout();
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => SplashRouter()), (route) => false);
          },
        ),
        ListTile(
          leading: Icon(Icons.delete_forever, color: Colors.red),
          title: Text('Factory Reset (Clear all data)'),
          onTap: () {
            showDialog(context: context, builder: (_) => AlertDialog(
              title: Text('Warning'),
              content: Text('Are you sure you want to clear ALL workouts, logs, and settings? This cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    app.resetAllData();
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => SplashRouter()), (route) => false);
                  },
                  child: Text('Clear Data', style: TextStyle(color: Colors.red)),
                ),
              ],
            ));
          },
        ),
      ]),
    );
  }
}