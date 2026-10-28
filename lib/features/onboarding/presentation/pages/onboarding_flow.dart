import 'package:flutter/material.dart';

import '../../../../app/navigation/app_page_route.dart';
import '../../../../shared/widgets/beam_ui.dart';
import '../../../../shared/widgets/beam_illustrations.dart';
import '../../../auth/presentation/pages/auth_page.dart';

/// Beam welcome and four swipeable introductions. Existing account setup keeps
/// its separate privacy step and saves progress through the supplied callbacks.
class OnboardingFlow extends StatefulWidget {
  final int initialStep;
  final bool replay;
  final Future<void> Function()? onIntroductionComplete, onFinished;
  final VoidCallback? onSignIn, onCreateAccount;
  const OnboardingFlow({
    super.key,
    this.initialStep = 1,
    this.replay = false,
    this.onIntroductionComplete,
    this.onFinished,
    this.onSignIn,
    this.onCreateAccount,
  });
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late int stage = widget.initialStep >= 4
      ? 2
      : widget.initialStep >= 2
      ? 1
      : 0;
  final pages = PageController();
  int page = 0;
  bool busy = false;
  String? error;
  static const slides = [
    ('Meet', 'E Health Pulse', 'Your health, connected.'),
    ('Track What', 'Matters', 'Daily health at a glance.'),
    ('Share with', 'Your Doctor', 'Keep your care team connected.'),
    ('Your AI', 'Wellness Advisor', 'Simple guidance. Better habits.'),
  ];
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  Future<void> finishIntro() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!widget.replay) await widget.onIntroductionComplete?.call();
      if (mounted) {
        if (widget.onCreateAccount != null) {
          widget.onCreateAccount!();
        } else {
          setState(() => stage = 2);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save progress. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> finishPrivacy() async {
    if (busy) return;
    if (widget.replay) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.onFinished != null) {
        await widget.onFinished!();
      } else if (mounted) {
        await Navigator.of(context).push(
          AppPageRoute<void>(
            reducedMotion: MediaQuery.disableAnimationsOf(context),
            builder: (_) => const AuthPage(initialMode: AuthPageMode.signup),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save progress. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void advance() {
    if (busy) return;
    if (stage == 0) {
      setState(() {
        stage = 1;
        page = 0;
      });
    } else if (stage == 2) {
      finishPrivacy();
    } else if (page == slides.length - 1) {
      finishIntro();
    } else {
      movePage(page + 1);
    }
  }

  void movePage(int value) {
    if (MediaQuery.disableAnimationsOf(context)) {
      pages.jumpToPage(value);
    } else {
      pages.animateToPage(
        value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void back() {
    if (busy) return;
    if (stage == 2) {
      setState(() {
        stage = 1;
        page = slides.length - 1;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pages.hasClients) pages.jumpToPage(page);
      });
    } else if (stage == 1 && page > 0) {
      movePage(page - 1);
    } else if (stage == 1) {
      setState(() => stage = 0);
    } else if (widget.replay) {
      Navigator.of(context).pop();
    }
  }

  void signIn() {
    if (widget.onSignIn != null) {
      widget.onSignIn!();
    } else {
      Navigator.of(context).push(
        AppPageRoute<void>(
          reducedMotion: MediaQuery.disableAnimationsOf(context),
          builder: (_) => const AuthPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: beamTheme(context),
    child: PopScope(
      canPop: widget.replay && stage == 0 && !busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: beamNavy,
        body: DecoratedBox(
          decoration: BoxDecoration(
            image: stage == 0
                ? const DecorationImage(
                    image: AssetImage(BeamAssets.welcomeBackground),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  )
                : null,
            gradient: stage == 1 && page == 0
                ? const LinearGradient(
                    colors: [Color(0xFF000B16), Color(0xFF000B16)],
                  )
                : const RadialGradient(
                    center: Alignment(.6, -.8),
                    radius: 1.5,
                    colors: [Color(0xFF00304C), beamNavy, Color(0xFF000B16)],
                  ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (stage == 2 || widget.replay)
                        IconButton(
                          tooltip: 'Back',
                          onPressed: busy ? null : back,
                          icon: const Icon(Icons.chevron_left),
                        )
                      else
                        const SizedBox(width: 48),
                      if (stage < 2)
                        TextButton(
                          onPressed: busy ? null : finishIntro,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 32),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(color: beamMuted),
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: stage == 1
                          ? PageView.builder(
                              key: const ValueKey('introduction-slides'),
                              controller: pages,
                              itemCount: slides.length,
                              physics: busy
                                  ? const NeverScrollableScrollPhysics()
                                  : null,
                              onPageChanged: (index) =>
                                  setState(() => page = index),
                              itemBuilder: (context, index) => slide(index),
                            )
                          : stage == 0
                          ? welcome()
                          : privacy(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                  child: Column(
                    children: [
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Color(0xFFFF8696)),
                          ),
                        ),
                      if (stage == 1) ...[
                        Semantics(
                          label: 'Introduction ${page + 1} of ${slides.length}',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < slides.length; i++)
                                Semantics(
                                  label: 'Go to introduction ${i + 1}',
                                  selected: page == i,
                                  button: true,
                                  child: InkWell(
                                    onTap: busy ? null : () => movePage(i),
                                    child: SizedBox(
                                      width: 22,
                                      height: 32,
                                      child: Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: page == i
                                                ? beamCyan
                                                : beamBorder,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (stage == 1)
                        Row(
                          children: [
                            if (page < slides.length - 1) ...[
                              Expanded(
                                flex: 4,
                                child: BeamButton(
                                  'Previous',
                                  secondary: true,
                                  onPressed: busy ? null : back,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              flex: 5,
                              child: BeamButton(
                                busy
                                    ? 'Saving…'
                                    : page == slides.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                arrow: true,
                                onPressed: busy ? null : advance,
                              ),
                            ),
                          ],
                        )
                      else if (stage == 0) ...[
                        BeamButton(
                          'Create Account',
                          arrow: true,
                          onPressed: busy ? null : advance,
                        ),
                        const SizedBox(height: 9),
                        BeamButton(
                          'Sign In',
                          secondary: true,
                          onPressed: busy ? null : signIn,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'By continuing, you agree to our',
                          style: TextStyle(color: beamMuted, fontSize: 10),
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 24),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () =>
                                  showBeamLegal(context, 'Privacy Policy'),
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  fontSize: 10,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 24),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () =>
                                  showBeamLegal(context, 'Terms of Service'),
                              child: const Text(
                                'Terms of Service',
                                style: TextStyle(
                                  fontSize: 10,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        BeamButton(
                          busy
                              ? 'Saving…'
                              : widget.replay
                              ? 'Done'
                              : 'Continue',
                          onPressed: busy ? null : advance,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget welcome() => BeamReveal(child: welcomeContent());

  Widget welcomeContent() => LayoutBuilder(
    builder: (context, box) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: box.maxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BeamLogo(width: 120),
            const SizedBox(height: 17),
            const Text(
              'Your Health,',
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'More ',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: 'Connected',
                    style: TextStyle(color: beamCyan),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Wear. Track. Feel better.',
              textAlign: TextAlign.center,
              style: TextStyle(color: beamMuted, fontSize: 11, height: 1.45),
            ),
            const SizedBox(height: 12),
            SizedBox(height: box.maxWidth),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: BeamFeatureRow(welcome: true),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == 0 ? beamCyan : beamBorder,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );

  Widget meetPulse(BoxConstraints box) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: box.maxWidth.clamp(280, 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BeamLogo(width: 84),
            const SizedBox(height: 18),
            const Text(
              'Meet',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
            const Text(
              'E Health Pulse',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: beamCyan,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'A modern smartwatch designed\nfor a healthier, more connected you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFCEE0EC),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: AspectRatio(
                aspectRatio: 1190 / 1322,
                child: BeamReveal(
                  art: true,
                  child: Image.asset(
                    BeamAssets.scene,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'E Health Pulse smartwatch with a cyan orbit',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: BeamFeatureRow(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );

  Widget slide(int index) =>
      BeamReveal(key: ValueKey(index), child: slideContent(index));

  Widget slideContent(int index) => LayoutBuilder(
    builder: (context, box) {
      if (index == 0) return meetPulse(box);
      final data = slides[index];
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const BeamLogo(width: 84),
            const SizedBox(height: 22),
            Text(
              data.$1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                height: 1.05,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              data.$2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: beamCyan,
                fontSize: 28,
                height: 1.05,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              data.$3,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFCEE0EC),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            switch (index) {
              0 => Column(
                children: [
                  SizedBox(height: (box.maxHeight * .54).clamp(170, 380)),
                  const SizedBox(height: 10),
                  const BeamFeatureRow(),
                ],
              ),
              1 => const BeamTrackingPanel(),
              2 => BeamDoctorPanel(
                height: (box.maxHeight * .60).clamp(260, 400),
              ),
              _ => BeamCoachPanel(
                height: (box.maxHeight * .60).clamp(260, 400),
              ),
            },
          ],
        ),
      );
    },
  );

  Widget privacy() => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        const BeamLogo(),
        const SizedBox(height: 30),
        const BeamIcon('shield', size: 90),
        const SizedBox(height: 26),
        const Text(
          'Your Privacy',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your choice. Your control.',
          style: TextStyle(color: beamCyan, fontSize: 21),
        ),
        const SizedBox(height: 18),
        const Text(
          'Choose what you share. We’ll ask for your consent and permission choices during setup.',
          textAlign: TextAlign.center,
          style: TextStyle(color: beamMuted, height: 1.5),
        ),
        const SizedBox(height: 24),
        for (final text in [
          'You control your preferences',
          'Review your choices before device setup',
          'Change your preferences in Settings',
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle, color: beamCyan),
            title: Text(text),
          ),
      ],
    ),
  );
}
