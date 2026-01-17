import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xff9c27b0),
    primaryContainer: Color(0xff6a1b9a),
    secondary: Color(0xffab47bc),
    surface: Color(0xff121212),
    surfaceContainerHighest: Color(0xff1e1e1e),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white,
  ),
  scaffoldBackgroundColor: const Color(0xff121212),
  cardTheme: const CardThemeData(color: Color(0xff1e1e1e), elevation: 2),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xff1e1e1e),
    elevation: 0,
  ),
);

@NowaGenerated()
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff9c27b0),
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(),
);
