import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/email_otp_config.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../../../onboarding/presentation/pages/onboarding_flow.dart';
import '../../../onboarding/presentation/cubit/app_flow_cubit.dart';
import '../bloc/auth_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/beam_verification_art.dart';

enum AuthPageMode { login, signup, reset, recovery }

class AuthPage extends StatefulWidget {
  final AuthPageMode initialMode;
  final bool showWelcome;
  const AuthPage({
    super.key,
    this.initialMode = AuthPageMode.login,
    this.showWelcome = false,
  });
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final name = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  final otp = TextEditingController();
  DateTime? lastSend;
  bool restoredCooldown = false;
  bool awaitingEmailVerification = false;
  late AuthPageMode mode = widget.initialMode;
  Timer? cooldown;
  int resendSeconds = 0;
  bool hidePassword = true, hideConfirmation = true;
  late bool showingWelcome = widget.showWelcome;
  bool acceptedTerms = false, marketingUpdates = false;
  String? consentError;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (restoredCooldown) return;
    restoredCooldown = true;
    final auth = context.read<AuthBloc?>()?.state;
    final sentAt = auth?.confirmationSentAt ?? auth?.recoverySentAt;
    if (sentAt != null) {
      lastSend = sentAt;
      startCooldown(sentAt);
    }
  }

  @override
  void dispose() {
    cooldown?.cancel();
    email.dispose();
    name.dispose();
    password.dispose();
    confirmation.dispose();
    otp.dispose();
    super.dispose();
  }

  void startCooldown(DateTime sentAt) {
    cooldown?.cancel();
    void update() {
      final remaining =
          EmailOtpConfig.resendSeconds -
          DateTime.now().difference(sentAt).inSeconds;
      setState(
        () => resendSeconds = remaining.clamp(0, EmailOtpConfig.resendSeconds),
      );
    }

    update();
    cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      update();
      if (resendSeconds == 0) timer.cancel();
    });
  }

  void changeMode(AuthPageMode value) {
    context.read<AuthBloc>().add(AuthFormReset());
    setState(() {
      mode = value;
      hidePassword = true;
      hideConfirmation = true;
      password.clear();
      confirmation.clear();
      otp.clear();
      form.currentState?.reset();
    });
  }

  void submit() {
    if (!(form.currentState?.validate() ?? false)) return;
    if (mode == AuthPageMode.signup && !acceptedTerms) {
      setState(
        () => consentError =
            'Please accept the Terms of Service and Privacy Policy.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
      AuthSubmitted(
        switch (mode) {
          AuthPageMode.login => AuthAction.signIn,
          AuthPageMode.signup => AuthAction.signUp,
          AuthPageMode.reset => AuthAction.resetPassword,
          AuthPageMode.recovery => AuthAction.updatePassword,
        },
        email: email.text,
        name: name.text,
        password: password.text,
      ),
    );
  }

  void verifyCode(AuthBloc bloc, AuthState state) {
    if (state.busy || !(form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    awaitingEmailVerification = state.recoveryEmail == null;
    bloc.add(
      AuthSubmitted(
        state.recoveryEmail != null
            ? AuthAction.verifyRecovery
            : AuthAction.verifyConfirmation,
        code: otp.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AuthBloc?>();
    if (bloc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connect your account')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Supabase configuration is required before you can sign in. Please configure the project public key.',
            ),
          ),
        ),
      );
    }
    return Theme(
      data: beamTheme(context),
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (awaitingEmailVerification &&
              state.status == AuthStatus.signedIn) {
            awaitingEmailVerification = false;
            final verificationTheme = beamTheme(context);
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => Theme(
                data: verificationTheme,
                child: Dialog.fullscreen(
                  backgroundColor: beamNavy,
                  child: SafeArea(
                    child: AuthSurface(
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          const BeamLogo(width: 138, horizontal: true),
                          const SizedBox(height: 40),
                          const BeamVerificationArt(
                            kind: 'success',
                            height: 210,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Email Verified!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'You’re ready to continue.',
                            style: TextStyle(color: beamMuted),
                          ),
                          const SizedBox(height: 60),
                          BeamButton(
                            'Continue',
                            arrow: true,
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          final sentAt = state.confirmationSentAt ?? state.recoverySentAt;
          if ((state.confirmationEmail != null ||
                  state.recoveryEmail != null) &&
              state.error == null &&
              !state.busy &&
              sentAt != null &&
              sentAt != lastSend) {
            lastSend = sentAt;
            otp.clear();
            startCooldown(lastSend!);
            password.clear();
            confirmation.clear();
          }
          if (state.message != null &&
              state.confirmationEmail == null &&
              state.recoveryEmail == null &&
              state.status != AuthStatus.recoverySuccess) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        builder: (context, state) {
          final recovering = mode == AuthPageMode.recovery;
          final pendingEmail = state.confirmationEmail ?? state.recoveryEmail;
          final confirming = pendingEmail != null;
          final success = state.status == AuthStatus.recoverySuccess;
          if (showingWelcome && !confirming && !recovering && !success) {
            return OnboardingFlow(
              onIntroductionComplete: () async {
                await context.read<AppFlowCubit?>()?.finishIntroduction();
              },
              onSignIn: () => setState(() {
                showingWelcome = false;
                mode = AuthPageMode.login;
              }),
              onCreateAccount: () => setState(() {
                showingWelcome = false;
                mode = AuthPageMode.signup;
              }),
            );
          }

          if (!confirming &&
              !success &&
              (mode == AuthPageMode.login || mode == AuthPageMode.signup)) {
            return beamAuth(context, bloc, state);
          }
          return beamVerification(context, bloc, state);
        },
      ),
    );
  }

  Widget beamVerification(
    BuildContext context,
    AuthBloc bloc,
    AuthState state,
  ) {
    final pending = state.confirmationEmail ?? state.recoveryEmail;
    final confirming = pending != null;
    final recovery = state.recoveryEmail != null;
    final linkOnly = recovery && !EmailOtpConfig.recoveryUsesOtp;
    final success = state.status == AuthStatus.recoverySuccess;
    final updating = mode == AuthPageMode.recovery && !confirming;
    final invalid = confirming && state.error != null;
    final title = success
        ? 'Password Updated'
        : confirming
        ? linkOnly
              ? 'Check Your Email'
              : invalid
              ? 'Invalid Code'
              : recovery
              ? 'Verify Recovery'
              : 'Verify Your Email'
        : updating
        ? 'Create a New Password'
        : 'Reset Your Password';
    Widget note(String text, {Color color = beamMuted}) => Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 12, height: 1.45),
    );
    Widget field(
      String label,
      TextEditingController controller, {
      bool secret = false,
      bool confirm = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: beamMuted, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: !state.busy,
          obscureText: secret && (confirm ? hideConfirmation : hidePassword),
          keyboardType: secret
              ? TextInputType.visiblePassword
              : TextInputType.emailAddress,
          autofillHints: [
            secret ? AutofillHints.newPassword : AutofillHints.email,
          ],
          autocorrect: false,
          enableSuggestions: !secret,
          decoration: authFieldDecoration(
            context,
            label: label,
            externalLabel: true,
            hint: secret ? 'At least 8 characters' : 'you@example.com',
            icon: secret ? Icons.lock_outline : Icons.mail_outline,
            suffix: secret
                ? IconButton(
                    tooltip: confirm
                        ? 'Show confirmation password'
                        : 'Show password',
                    onPressed: state.busy
                        ? null
                        : () => setState(() {
                            if (confirm) {
                              hideConfirmation = !hideConfirmation;
                            } else {
                              hidePassword = !hidePassword;
                            }
                          }),
                    icon: BeamIcon(
                      (confirm ? hideConfirmation : hidePassword)
                          ? 'eye-off'
                          : 'eye',
                      color: beamMuted,
                      size: 19,
                    ),
                  )
                : null,
          ),
          validator: (value) => secret
              ? confirm
                    ? value == password.text
                          ? null
                          : 'Passwords do not match'
                    : (value?.length ?? 0) >= 8
                    ? null
                    : 'Use at least 8 characters'
              : RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                    .hasMatch(value?.trim() ?? '')
              ? null
              : 'Enter a valid email address',
          onFieldSubmitted: (_) => submit(),
        ),
      ],
    );
    return PopScope(
      canPop: !state.busy && !updating,
      child: Scaffold(
        backgroundColor: beamNavy,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(.9, -.6),
              radius: 1.6,
              colors: [Color(0xFF00344B), beamNavy, Color(0xFF000C18)],
            ),
          ),
          child: SafeArea(
            child: AuthSurface(
              child: AutofillGroup(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back',
                          icon: const BeamIcon('back', color: beamMuted),
                          onPressed: state.busy || updating
                              ? null
                              : () => changeMode(AuthPageMode.login),
                        ),
                      ),
                      const Center(
                        child: BeamLogo(width: 138, horizontal: true),
                      ),
                      const SizedBox(height: 26),
                      if (invalid || success || linkOnly)
                        BeamVerificationArt(
                          kind: success
                              ? 'success'
                              : invalid
                              ? 'error'
                              : 'mail',
                          height: 170,
                        ),
                      if (confirming || success) ...[
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: title.substring(
                                  0,
                                  title.lastIndexOf(' ') + 1,
                                ),
                              ),
                              TextSpan(
                                text: title.substring(
                                  title.lastIndexOf(' ') + 1,
                                ),
                                style: TextStyle(
                                  color: invalid
                                      ? const Color(0xFFFF6D88)
                                      : beamCyan,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        note(
                          success
                              ? 'Your new password is ready.'
                              : confirming
                              ? linkOnly
                                    ? 'We sent a reset link to'
                                    : invalid
                                    ? 'Please try again.'
                                    : 'We sent a ${EmailOtpConfig.codeLength}-digit code to'
                              : updating
                              ? 'Choose a password you haven’t used before.'
                              : EmailOtpConfig.recoveryUsesOtp
                              ? 'Enter your email to receive a reset code.'
                              : 'Enter your email to receive a reset link.',
                        ),
                        if (pending != null) ...[
                          const SizedBox(height: 4),
                          note(pending, color: beamCyan),
                        ],
                        if (!invalid && !success && !linkOnly)
                          BeamVerificationArt(
                            kind: confirming
                                ? 'mail'
                                : updating
                                ? 'lock'
                                : 'recovery',
                            height: confirming ? 140 : 120,
                          ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: updating
                                              ? 'Create a\n'
                                              : 'Reset Your\n',
                                        ),
                                        TextSpan(
                                          text: updating
                                              ? 'New Password'
                                              : 'Password',
                                          style: const TextStyle(
                                            color: beamCyan,
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    updating
                                        ? 'Choose a password you haven’t used before.'
                                        : EmailOtpConfig.recoveryUsesOtp
                                        ? 'Enter your email to receive a reset code.'
                                        : 'Enter your email to receive a reset link.',
                                    style: const TextStyle(
                                      color: beamMuted,
                                      fontSize: 12,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: BeamVerificationArt(
                                kind: updating ? 'lock' : 'recovery',
                                height: 150,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      if (success) ...[
                        const SizedBox(height: 30),
                        BeamButton(
                          'Continue',
                          arrow: true,
                          onPressed: state.busy
                              ? null
                              : () => bloc.add(
                                  AuthSubmitted(AuthAction.finishRecovery),
                                ),
                        ),
                      ] else if (confirming) ...[
                        if (!linkOnly) ...[
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: otp,
                            builder: (context, value, _) {
                              final count =
                                  value.text.length > EmailOtpConfig.codeLength
                                  ? value.text.length.clamp(
                                      EmailOtpConfig.codeLength,
                                      EmailOtpConfig.maxCodeLength,
                                    )
                                  : EmailOtpConfig.codeLength;
                              return Stack(
                                children: [
                                  Row(
                                    children: [
                                      for (var i = 0; i < count; i++)
                                        Expanded(
                                          child: Container(
                                            margin: EdgeInsets.only(
                                              right: i == count - 1 ? 0 : 5,
                                            ),
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF002235),
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              border: Border.all(
                                                color: invalid && i == 0
                                                    ? Colors.redAccent
                                                    : i ==
                                                          value.text.length
                                                              .clamp(
                                                                0,
                                                                count - 1,
                                                              )
                                                    ? beamCyan
                                                    : beamBorder,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              i < value.text.length
                                                  ? value.text[i]
                                                  : '',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  TextFormField(
                                    controller: otp,
                                    enabled: !state.busy,
                                    keyboardType: TextInputType.number,
                                    autofillHints: const [
                                      AutofillHints.oneTimeCode,
                                    ],
                                    style: const TextStyle(
                                      color: Colors.transparent,
                                      fontSize: 20,
                                    ),
                                    showCursor: false,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      fillColor: Colors.transparent,
                                      filled: false,
                                      contentPadding: EdgeInsets.all(14),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(
                                        EmailOtpConfig.maxCodeLength,
                                      ),
                                    ],
                                    validator: (value) =>
                                        (value?.length ?? 0) >=
                                            EmailOtpConfig.minCodeLength
                                        ? null
                                        : 'Enter the complete code',
                                    onFieldSubmitted: (_) =>
                                        verifyCode(bloc, state),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: state.busy
                                ? null
                                : () async {
                                    final data = await Clipboard.getData(
                                      Clipboard.kTextPlain,
                                    );
                                    if (!mounted || data?.text == null) return;
                                    final digits = data!.text!.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    );
                                    otp.text = digits.substring(
                                      0,
                                      digits.length.clamp(
                                        0,
                                        EmailOtpConfig.maxCodeLength,
                                      ),
                                    );
                                    if (otp.text.length >=
                                        EmailOtpConfig.minCodeLength) {
                                      verifyCode(bloc, state);
                                    }
                                  },
                            icon: const BeamIcon(
                              'document',
                              size: 15,
                              color: beamMuted,
                            ),
                            label: const Text('Paste Code'),
                          ),
                          const SizedBox(height: 12),
                          BeamButton(
                            state.busy
                                ? 'Verifying…'
                                : recovery
                                ? 'Verify Recovery'
                                : 'Verify Email',
                            onPressed: state.busy
                                ? null
                                : () => verifyCode(bloc, state),
                          ),
                        ] else ...[
                          const ListTile(
                            leading: BeamIcon('mail'),
                            title: Text('Open your email'),
                            subtitle: Text('Check your inbox and spam.'),
                          ),
                          const ListTile(
                            leading: BeamIcon('lock'),
                            title: Text('Follow the reset link'),
                            subtitle: Text('Then choose a new password.'),
                          ),
                          BeamButton(
                            'Back to Sign In',
                            arrow: true,
                            onPressed: () => changeMode(AuthPageMode.login),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: state.busy || resendSeconds > 0
                              ? null
                              : () => bloc.add(
                                  AuthSubmitted(
                                    recovery
                                        ? AuthAction.resendRecovery
                                        : AuthAction.resendConfirmation,
                                    email: pending,
                                  ),
                                ),
                          child: Text(
                            resendSeconds > 0
                                ? 'Resend code in ${resendSeconds}s'
                                : 'Resend code',
                            style: const TextStyle(
                              color: beamCyan,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        BeamButton(
                          'Change Email',
                          secondary: true,
                          onPressed: state.busy
                              ? null
                              : () {
                                  email.text = pending;
                                  changeMode(
                                    recovery
                                        ? AuthPageMode.reset
                                        : AuthPageMode.signup,
                                  );
                                },
                        ),
                      ] else ...[
                        if (updating) ...[
                          field('New Password', password, secret: true),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: password,
                            builder: (context, value, _) {
                              final strength = [
                                value.text.length >= 8,
                                RegExp(r'[A-Z]').hasMatch(value.text),
                                RegExp(r'[0-9]').hasMatch(value.text),
                                RegExp(r'[^a-zA-Z0-9]').hasMatch(value.text),
                              ].where((v) => v).length;
                              return Row(
                                children: [
                                  for (var i = 0; i < 4; i++)
                                    Expanded(
                                      child: Container(
                                        height: 4,
                                        margin: const EdgeInsets.only(right: 5),
                                        decoration: BoxDecoration(
                                          color: i < strength
                                              ? beamCyan
                                              : beamBorder,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          field(
                            'Confirm Password',
                            confirmation,
                            secret: true,
                            confirm: true,
                          ),
                        ] else
                          field('Email Address', email),
                        const SizedBox(height: 28),
                        BeamButton(
                          state.busy
                              ? 'Please wait…'
                              : updating
                              ? 'Reset Password'
                              : 'Send Recovery Email',
                          arrow: true,
                          onPressed: state.busy ? null : submit,
                        ),
                      ],
                      if (state.error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x332D1020),
                            border: Border.all(color: const Color(0xFF8F3B50)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: note(
                            state.error!,
                            color: const Color(0xFFFF90A3),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget beamAuth(BuildContext context, AuthBloc bloc, AuthState state) {
    final signup = mode == AuthPageMode.signup;
    return PopScope(
      canPop: !state.busy,
      child: Scaffold(
        backgroundColor: beamNavy,
        resizeToAvoidBottomInset: false,
        body: ColoredBox(
          color: beamNavy,
          child: SafeArea(
            child: AuthSurface(
              key: ValueKey(mode),
              transparent: true,
              backgroundAsset: BeamAssets.authBackground,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: AutofillGroup(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (signup ||
                          widget.showWelcome ||
                          Navigator.of(context).canPop())
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Back',
                            icon: const BeamIcon('back', color: beamMuted),
                            onPressed: state.busy
                                ? null
                                : () {
                                    if (signup) {
                                      changeMode(AuthPageMode.login);
                                    } else if (widget.showWelcome) {
                                      setState(() => showingWelcome = true);
                                    } else {
                                      Navigator.maybePop(context);
                                    }
                                  },
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, box) => SizedBox(
                          height:
                              (box.maxWidth * .57).clamp(170, 220) *
                              MediaQuery.textScalerOf(context).scale(12) /
                              12,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: 0,
                                top: 8,
                                width: box.maxWidth * .53,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const BeamLogo(
                                      width: 116,
                                      horizontal: true,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      signup ? 'Create your' : 'Welcome',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.05,
                                      ),
                                    ),
                                    Text(
                                      signup ? 'E Health ID' : 'Back',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.05,
                                        color: beamCyan,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      signup
                                          ? 'Your health journey starts here.'
                                          : 'Continue your health journey.',
                                      style: const TextStyle(
                                        color: beamMuted,
                                        fontSize: 10,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (signup) ...[
                        beamField(
                          'Full Name',
                          TextFormField(
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFCEE0EC),
                            ),
                            controller: name,
                            enabled: !state.busy,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            decoration: authFieldDecoration(
                              externalLabel: true,
                              compact: true,
                              context,
                              label: 'Full Name',
                              hint: 'Enter your full name',
                              icon: Icons.person_outline,
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Enter your name'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      beamField(
                        'Email Address',
                        TextFormField(
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFCEE0EC),
                          ),
                          controller: email,
                          enabled: !state.busy,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: authFieldDecoration(
                            externalLabel: true,
                            compact: true,
                            context,
                            label: 'Email Address',
                            hint: 'you@example.com',
                            icon: Icons.mail_outline,
                          ),
                          validator: (value) =>
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Enter a valid email address',
                        ),
                      ),
                      const SizedBox(height: 10),
                      beamField(
                        'Password',
                        TextFormField(
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFCEE0EC),
                          ),
                          controller: password,
                          enabled: !state.busy,
                          obscureText: hidePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: [
                            signup
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => submit(),
                          onChanged: (_) => setState(() {}),
                          decoration: authFieldDecoration(
                            externalLabel: true,
                            compact: true,
                            context,
                            label: 'Password',
                            hint: signup
                                ? 'At least 8 characters'
                                : 'Enter your password',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              tooltip: hidePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: state.busy
                                  ? null
                                  : () => setState(
                                      () => hidePassword = !hidePassword,
                                    ),
                              icon: Icon(
                                hidePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 19,
                              ),
                            ),
                          ),
                          validator: (value) => signup
                              ? (value?.length ?? 0) < 8
                                    ? 'Use at least 8 characters'
                                    : null
                              : (value?.isEmpty ?? true)
                              ? 'Enter your password'
                              : null,
                        ),
                      ),
                      if (signup) ...[
                        const SizedBox(height: 10),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: password,
                          builder: (context, value, _) {
                            final strength = [
                              value.text.length >= 8,
                              RegExp(r'[A-Z]').hasMatch(value.text),
                              RegExp(r'[0-9]').hasMatch(value.text),
                              RegExp(r'[^a-zA-Z0-9]').hasMatch(value.text),
                            ].where((v) => v).length;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    for (var i = 0; i < 4; i++)
                                      Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            right: 5,
                                          ),
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: i < strength
                                                ? const Color(0xFF00E9B4)
                                                : beamBorder,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      strength >= 3
                                          ? 'Strong'
                                          : strength > 0
                                          ? 'Fair'
                                          : '',
                                      style: const TextStyle(
                                        color: Color(0xFF00E9B4),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                const Text(
                                  '8+ characters with letters, numbers & symbols.',
                                  style: TextStyle(
                                    color: beamMuted,
                                    fontSize: 10,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 30,
                              child: Checkbox(
                                value: acceptedTerms,
                                onChanged: state.busy
                                    ? null
                                    : (value) => setState(() {
                                        acceptedTerms = value ?? false;
                                        consentError = null;
                                      }),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'I agree to the ',
                                    style: TextStyle(
                                      color: beamMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => showBeamLegal(
                                      context,
                                      'Terms of Service',
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'Terms of Service',
                                        style: TextStyle(
                                          color: beamCyan,
                                          fontSize: 11,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    ' and ',
                                    style: TextStyle(
                                      color: beamMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => showBeamLegal(
                                      context,
                                      'Privacy Policy',
                                    ),
                                    child: const Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                        color: beamCyan,
                                        fontSize: 11,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 30,
                              child: Checkbox(
                                value: marketingUpdates,
                                onChanged: state.busy
                                    ? null
                                    : (value) => setState(
                                        () => marketingUpdates = value ?? false,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Text(
                                  'Send me health tips and product updates.',
                                  style: TextStyle(
                                    color: beamMuted,
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (consentError != null)
                          Text(
                            consentError!,
                            style: const TextStyle(
                              color: Color(0xFFFF8696),
                              fontSize: 12,
                            ),
                          ),
                      ] else
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: state.busy
                                ? null
                                : () => changeMode(AuthPageMode.reset),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      BeamButton(
                        state.busy
                            ? 'Please wait…'
                            : signup
                            ? 'Create Account'
                            : 'Sign In',
                        arrow: true,
                        onPressed: state.busy ? null : submit,
                      ),
                      if (state.busy)
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: beamCyan,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                signup
                                    ? 'Creating your account…'
                                    : 'Signing you in…',
                                style: TextStyle(
                                  color: beamMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            state.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFFF8696)),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: beamBorder)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18),
                            child: Text(
                              'OR',
                              style: TextStyle(color: beamMuted, fontSize: 10),
                            ),
                          ),
                          Expanded(child: Divider(color: beamBorder)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      socialButton(
                        'Google',
                        const BeamIcon('google', size: 20, color: null),
                        state.busy,
                      ),
                      const SizedBox(height: 8),
                      socialButton(
                        'Apple',
                        const BeamIcon('apple', size: 21, color: null),
                        state.busy,
                      ),
                      if (!signup) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF032D41),
                            border: Border.all(color: beamBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              BeamIcon('shield', size: 22),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your data is encrypted and always secure with E Health.',
                                  style: TextStyle(
                                    color: beamMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              signup
                                  ? 'Already have a E Health ID?'
                                  : 'Don’t have a E Health ID?',
                              style: const TextStyle(
                                color: beamMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: state.busy
                                ? null
                                : () => changeMode(
                                    signup
                                        ? AuthPageMode.login
                                        : AuthPageMode.signup,
                                  ),
                            child: Text(
                              signup ? 'Sign In' : 'Sign Up',
                              style: const TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget beamField(String label, Widget field) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFFCEE0EC), fontSize: 12),
      ),
      const SizedBox(height: 5),
      field,
    ],
  );

  Widget socialButton(
    String provider,
    Widget icon,
    bool busy,
  ) => OutlinedButton(
    onPressed: busy
        ? null
        : () {
            if (mode == AuthPageMode.signup && !acceptedTerms) {
              setState(
                () => consentError =
                    'Please accept the Terms of Service and Privacy Policy.',
              );
              return;
            }
            context.read<AuthBloc>().add(
              AuthSocialSubmitted(
                provider == 'Google'
                    ? SocialAuthProvider.google
                    : SocialAuthProvider.apple,
              ),
            );
          },
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: beamCyan),
      shape: const StadiumBorder(),
      minimumSize: const Size.fromHeight(42),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: 20),
        Flexible(
          child: Text(
            'Continue with $provider',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
