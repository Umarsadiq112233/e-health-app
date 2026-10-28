import 'package:flutter/material.dart';

import '../../shared/health_catalog.dart';
import '../../features/notifications/domain/reminder.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

class AppSessionState {
  final ThemeMode themeMode;
  final int revision;
  const AppSessionState(this.themeMode, this.revision);
}

class AppSessionCubit extends Cubit<AppSessionState> {
  static final instance = AppSessionCubit();
  AppSessionCubit() : super(const AppSessionState(ThemeMode.light, 0));
  final reminders = <BeamReminder>[];
  void saveReminder(BeamReminder reminder) {
    final index = reminders.indexWhere((r) => r.id == reminder.id);
    if (index < 0) {
      reminders.add(reminder);
    } else {
      reminders[index] = reminder;
    }
    _publish();
  }

  void deleteReminder(String id) {
    reminders.removeWhere((r) => r.id == id);
    _publish();
  }

  final coachConversations = <String, List<String>>{};
  void saveCoachMessage(String id, String text) {
    coachConversations.putIfAbsent(id, () => []).add(text);
    _publish();
  }

  void deleteCoachConversation(String id) {
    coachConversations.remove(id);
    _publish();
  }

  void _publish() => emit(AppSessionState(themeMode, state.revision + 1));
  void resetIdentity() {
    avatarUrl = null;
    avatarPath = null;
    name = '';
    email = '';
    weight = '70';
    gender = 'Prefer not to say';
    birthDate = '';
    goals
      ..clear()
      ..addAll(HealthCatalog.goals);
    preferences.clear();
    coachConversations.clear();
    reminders.clear();
    readNotifications.clear();
    _publish();
  }

  String? avatarUrl, avatarPath;
  void profilePhoto(String? url, String? path) {
    if (avatarUrl == url && avatarPath == path) return;
    avatarUrl = url;
    avatarPath = path;
    _publish();
  }

  ThemeMode themeMode = ThemeMode.light;
  String name = '', email = '', weight = '70';
  String gender = 'Prefer not to say', birthDate = '';
  final goals = [...HealthCatalog.goals];
  final preferences = <String, bool>{};
  final readNotifications = <String>{};
  void theme(ThemeMode value) {
    themeMode = value;
    _publish();
  }

  void profile(String newName, String newEmail, String newWeight) {
    name = newName;
    email = newEmail;
    weight = newWeight;
    _publish();
  }

  void addGoal(Goal goal) {
    goals.add(goal);
    _publish();
  }

  void updateGoal(int index, Goal goal) {
    goals[index] = goal;
    _publish();
  }

  void preference(String key, bool value) {
    preferences[key] = value;
    _publish();
  }
}
