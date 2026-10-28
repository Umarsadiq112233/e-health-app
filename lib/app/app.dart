import '../features/setup/presentation/pages/setup_complete_page.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/system_ui.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../core/config/supabase_config.dart';
import '../shared/widgets/artwork.dart';
import '../features/auth/data/repositories/supabase_auth_repository.dart';
import '../features/profile/data/repositories/supabase_profile_repository.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/pages/auth_page.dart';
import '../features/onboarding/data/local_progress_store.dart';
import '../features/onboarding/presentation/cubit/app_flow_cubit.dart';
import '../features/onboarding/presentation/pages/onboarding_flow.dart';
import '../features/onboarding/presentation/pages/splash_page.dart';
import '../shared/widgets/beam_ui.dart';
import '../features/setup/presentation/pages/setup_page.dart';
import '../features/device_pairing/presentation/pages/pairing_flow.dart';
import 'navigation/main_shell.dart';
import 'state/app_session_cubit.dart';
import '../features/health_metrics/presentation/cubit/health_cubit.dart';
import '../features/device_pairing/presentation/cubit/device_cubit.dart';

class EHealthApp extends StatefulWidget {
  final AuthRepository? authRepository;
  final Future<AuthRepository> Function()? authRepositoryLoader;
  final LocalProgressStore? progressStore;
  final ProfileRepository? profileRepository;
  final String? startupError;
  const EHealthApp({
    super.key,
    this.authRepository,
    this.authRepositoryLoader,
    this.progressStore,
    this.profileRepository,
    this.startupError,
  });
  @override
  State<EHealthApp> createState() => _EHealthAppState();
}

class _EHealthAppState extends State<EHealthApp> {
  AuthRepository? repository;
  AppFlowCubit? flow;
  String? error;
  bool splashComplete = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) initialize();
    });
  }

  Future<void> initialize() async {
    try {
      if (widget.startupError != null) throw StateError(widget.startupError!);
      final prefs = await SharedPreferences.getInstance();
      final store = widget.progressStore ?? LocalProgressStore(prefs);
      final auth =
          widget.authRepository ??
          await widget.authRepositoryLoader?.call() ??
          (throw StateError('Supabase configuration is missing'));
      await prefs.remove('ehealth.mockSession.v1');
      if (prefs.getString(LocalProgressStore.key) != null) {
        await store.write(store.read());
      }
      if (!mounted) {
        return;
      }
      // Decode high-resolution Beam artwork while the splash is visible.
      await BeamAssets.preload(context);
      if (!mounted) return;
      // Other existing setup screens retain their own artwork.
      await AppArtwork.preload(context, [
        AppArtwork.ring,
        AppArtwork.welcome,
        AppArtwork.introduction,
      ]);
      if (!mounted) {
        return;
      }
      final progress = AppFlowCubit(
        store,
        profiles:
            widget.profileRepository ??
            (auth is SupabaseAuthRepository
                ? SupabaseProfileRepository(auth.client)
                : null),
      );
      progress.bindUser(auth.currentUser?.id);
      setState(() {
        repository = auth;
        flow = progress;
      });
    } catch (failure) {
      if (mounted) {
        setState(() {
          error =
              widget.startupError ??
              (failure is ConfigurationFailure
                  ? failure.message
                  : 'Could not start the app. Check Supabase environment configuration and your connection.');
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(flow?.close());
    if (repository case final SupabaseAuthRepository auth) {
      unawaited(auth.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = repository != null && flow != null && splashComplete;
    return AnimatedSwitcher(
      duration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 300),
      child: ready
          ? RepositoryProvider<AuthRepository>.value(
              key: const ValueKey('application'),
              value: repository!,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider(create: (_) => AuthBloc(repository!)),
                  BlocProvider<AppFlowCubit>.value(value: flow!),
                ],
                child: const _AppView(),
              ),
            )
          : MaterialApp(
              key: const ValueKey('startup'),
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              builder: (context, child) =>
                  AnnotatedRegion<SystemUiOverlayStyle>(
                    value: eHealthSystemUi,
                    child: child!,
                  ),
              home: error == null
                  ? SplashPage(
                      onReady: () {
                        if (mounted) setState(() => splashComplete = true);
                      },
                    )
                  : Scaffold(
                      backgroundColor: SplashPage.background,
                      body: SafeArea(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: () {
                                    setState(() => error = null);
                                    initialize();
                                  },
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();
  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<AppFlowCubit>().refreshAvatar());
    }
  }

  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  String? lastUserId;
  AuthStatus? lastStatus;
  bool initialized = false;
  void syncIdentity(AuthState state) {
    final user = state.user;
    unawaited(HealthCubit.instance.bindUser(user?.id));
    unawaited(DeviceCubit.instance.bindUser(user?.id));
    final session = AppSessionCubit.instance;
    if (user == null) {
      session.resetIdentity();
    } else {
      final setup = context.read<AppFlowCubit>().state.setup;
      session.profile(
        setup.profileComplete ? setup.name : user.name,
        user.email,
        setup.profileComplete ? setup.weight : user.weight,
      );
      session.profilePhoto(setup.avatarDisplayUrl, setup.avatarPath);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final state = context.read<AuthBloc>().state;
    lastStatus = state.status;
    lastUserId = state.user?.id;
    syncIdentity(state);
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<DeviceCubit, DeviceState>(
        bloc: DeviceCubit.instance,
        listenWhen: (previous, current) => previous.phase != current.phase,
        listener: (context, device) {
          if (device.phase == DevicePhase.syncing) {
            HealthCubit.instance.syncing();
          } else if (device.phase == DevicePhase.connected &&
              (device.sync == SyncStatus.completed ||
                  device.sync == SyncStatus.failed)) {
            unawaited(HealthCubit.instance.refresh());
          }
          if ([
            DevicePhase.disconnected,
            DevicePhase.bluetoothOff,
          ].contains(device.phase)) {
            HealthCubit.instance.deviceDisconnected();
          }
        },
      ),
      BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.user != current.user ||
            previous.error != current.error ||
            previous.message != current.message,
        listener: (context, state) {
          context.read<AppFlowCubit>().bindUser(state.user?.id);
          syncIdentity(state);
          if (state.message == 'Profile updated.' && state.user != null) {
            unawaited(
              context.read<AppFlowCubit>().bindUser(
                state.user!.id,
                reload: true,
              ),
            );
          }
          if (lastStatus != state.status || lastUserId != state.user?.id) {
            messengerKey.currentState?.clearSnackBars();
            navigatorKey.currentState?.popUntil((route) => route.isFirst);
          }
          if (state.error != null &&
              (state.status == AuthStatus.signedIn ||
                  navigatorKey.currentState?.canPop() != true)) {
            messengerKey.currentState?.showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
          lastStatus = state.status;
          lastUserId = state.user?.id;
        },
      ),
      BlocListener<AppFlowCubit, AppFlowState>(
        listener: (context, state) =>
            syncIdentity(context.read<AuthBloc>().state),
      ),
    ],
    child: BlocBuilder<AppSessionCubit, AppSessionState>(
      bloc: AppSessionCubit.instance,
      builder: (context, state) => MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        title: 'E Health',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        darkTheme: buildTheme(dark: true),
        themeMode: state.themeMode,
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: eHealthSystemUi,
          child: Container(
            color: SplashPage.background,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: child!,
            ),
          ),
        ),
        home: const _FlowGate(),
      ),
    ),
  );
}

class _FlowGate extends StatelessWidget {
  const _FlowGate();
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
    builder: (context, auth) => BlocBuilder<AppFlowCubit, AppFlowState>(
      builder: (context, progress) {
        final flow = context.read<AppFlowCubit>();
        final Widget screen;
        if (auth.status == AuthStatus.callbackProcessing) {
          screen = const Scaffold(
            body: SafeArea(child: Center(child: CircularProgressIndicator())),
          );
        } else if (auth.status == AuthStatus.recovery ||
            auth.status == AuthStatus.recoverySuccess) {
          screen = const AuthPage(
            key: ValueKey('recovery'),
            initialMode: AuthPageMode.recovery,
          );
        } else if (auth.user != null &&
            (progress.loading || progress.userId != auth.user!.id)) {
          screen = const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (auth.user != null && progress.error != null) {
          screen = Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(progress.error!, textAlign: TextAlign.center),
                      FilledButton(
                        onPressed: () =>
                            flow.bindUser(auth.user!.id, reload: true),
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: () => context.read<AuthBloc>().add(
                          AuthSubmitted(AuthAction.signOut),
                        ),
                        child: const Text('Log Out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (auth.status == AuthStatus.signedOut) {
          screen = const AuthPage(key: ValueKey('login'), showWelcome: true);
        } else if (!progress.setup.profileComplete &&
            (!progress.introComplete || !progress.privacyComplete)) {
          screen = OnboardingFlow(
            key: const ValueKey('onboarding'),
            initialStep: progress.introComplete ? 4 : 1,
            onIntroductionComplete: flow.finishIntroduction,
            onFinished: flow.finishPrivacy,
          );
        } else if (!progress.setup.profileComplete) {
          screen = const SetupPage(key: ValueKey('profile-setup'));
        } else if (!progress.setup.consentComplete) {
          screen = const SetupPage(
            key: ValueKey('consent-setup'),
            consent: true,
          );
        } else if (!progress.setup.deviceComplete &&
            progress.setup.wellness.isNotEmpty &&
            progress.setup.wellness['reviewed'] != true) {
          screen = const SetupCompletePage(key: ValueKey('setup-summary'));
        } else if (!progress.setup.deviceComplete) {
          screen = PairingFlow(
            key: ValueKey('device-setup-${auth.user?.id}'),
            initialStep: progress.setup.pairingStep,
            onStepChanged: flow.savePairingStep,
            onCompleted: flow.finishDevice,
          );
        } else {
          screen = const MainShell(key: ValueKey('dashboard'));
        }
        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          child: screen,
        );
      },
    ),
  );
}
