import 'package:flutter/foundation.dart';

/// Represents a deployment environment (e.g., dev, staging, prod).
///
/// Migrated from enum to class to support dynamic discovery of .env files.
@immutable
class Env {
  final String name;
  final String label;

  const Env._({required this.name, required this.label});

  /// The standard development environment.
  static const dev = Env._(name: 'dev', label: 'Dev');

  /// The standard staging/QA environment.
  static const staging = Env._(name: 'staging', label: 'Staging');

  /// The standard production environment.
  static const prod = Env._(name: 'prod', label: 'Prod');

  /// Creates a dynamic [Env] from a string suffix (e.g., 'custom' for .env.custom).
  factory Env.dynamic(String suffix) {
    if (suffix.isEmpty) return dev;
    final name = suffix.toLowerCase();
    final label = name[0].toUpperCase() + name.substring(1);
    return Env._(name: name, label: label);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Env && runtimeType == other.runtimeType && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Env($name)';
}
