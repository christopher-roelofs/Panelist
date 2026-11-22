import 'package:material_ui/material_ui.dart';

import 'home/home_screen.dart';

/// `panelist [path]` opens [path] directly in the reader.
void main(List<String> args) {
  runApp(PanelistApp(initialPath: args.isEmpty ? null : args.first));
}

class PanelistApp extends StatelessWidget {
  const PanelistApp({super.key, this.initialPath});

  final String? initialPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panelist',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
      ),
      home: _Launcher(initialPath: initialPath),
    );
  }
}

/// Shows the home screen and, if a path was passed on the command line,
/// immediately opens it in the reader on top.
class _Launcher extends StatefulWidget {
  const _Launcher({this.initialPath});

  final String? initialPath;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  @override
  void initState() {
    super.initState();
    final path = widget.initialPath;
    if (path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) openInReader(context, path);
      });
    }
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
