import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/state/app_session_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/components.dart';
import '../../../../shared/widgets/beam_ui.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../onboarding/presentation/cubit/app_flow_cubit.dart';
import '../../data/services/profile_photo_picker.dart';
import '../../domain/models/account_profile.dart';
import '../cubit/profile_edit_cubit.dart';
import '../widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfileEditCubit? controller;
  const EditProfileScreen({super.key, this.controller});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  ProfileEditCubit? controller;
  final name = TextEditingController(), weight = TextEditingController();
  final form = GlobalKey<FormState>();
  bool initialized = false, allowPop = false, confirming = false;
  bool extraDirty = false, savingExtras = false;
  String gender = 'Prefer not to say', units = 'Metric';
  DateTime? birthday;
  final height = TextEditingController();
  AppFlowCubit? flowController;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    flowController = context.read<AppFlowCubit?>();
    final wellness =
        flowController?.state.setup.wellness ?? <String, dynamic>{};
    gender = wellness['gender']?.toString() ?? gender;
    units = wellness['units']?.toString() ?? units;
    birthday = DateTime.tryParse(wellness['birthday']?.toString() ?? '');
    height.text = wellness['heightCm']?.toString() ?? '';
    controller = widget.controller;
    if (controller == null) {
      final user = context.read<AuthBloc?>()?.state.user;
      final flow = context.read<AppFlowCubit?>();
      final repo = flow?.profiles;
      if (user != null && repo is AccountProfileRepository) {
        controller = ProfileEditCubit(
          userId: user.id,
          repository: repo as AccountProfileRepository,
          picker: NativeProfilePhotoPicker(),
          onSaved: (profile) {
            if (context.read<AuthBloc?>()?.state.user?.id != profile.id) return;
            flow!.acceptProfile(profile);
            final session = AppSessionCubit.instance;
            session.profile(profile.name, profile.email, profile.weight);
            session.profilePhoto(profile.avatarDisplayUrl, profile.avatarPath);
          },
        );
      }
    }
    final current = controller;
    if (current == null) return;
    if (current.state.profile != null) {
      name.text = current.state.name;
      weight.text = current.state.weight;
    } else {
      unawaited(current.load());
    }
  }

  @override
  void dispose() {
    name.dispose();
    weight.dispose();
    height.dispose();
    if (widget.controller == null) unawaited(controller?.close());
    super.dispose();
  }

  Future<void> leave() async {
    if (confirming || !mounted) return;
    if (controller?.state.busy == true || savingExtras) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the current request to finish.'),
        ),
      );
      return;
    }
    confirming = true;
    var discard = true;
    if (controller?.state.dirty == true || extraDirty) {
      discard =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Discard unsaved changes?'),
              content: const Text(
                'Your profile changes and selected photo have not been saved.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep editing'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          ) ??
          false;
    }
    confirming = false;
    if (discard && mounted) {
      setState(() => allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.maybePop(context);
    }
  }

  Future<void> photoSheet() async {
    final state = controller!.state;
    if (state.busy) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: AnimationStyle(
        duration: AppMotion.duration(context),
        reverseDuration: AppMotion.duration(context),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Profile photo', style: AppTypography.title),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (state.photo != null ||
                state.profile?.avatarPath != null ||
                state.profile?.legacyAvatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove Photo'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') {
      controller!.removePhoto();
    } else {
      await controller!.selectPhoto(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
    }
  }

  Future<void> emailDialog() async {
    final requested = await showDialog<String>(
      context: context,
      builder: (_) => const _EmailChangeDialog(),
    );
    if (!mounted || requested == null) return;
    final success = await controller!.changeEmail(requested);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email change requested. Follow the verification instructions in your inbox.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: beamTheme(context),
    child: Builder(builder: _buildProfile),
  );

  Widget _buildProfile(BuildContext context) {
    final cubit = controller;
    if (cubit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Sign in to load and edit your Supabase profile.'),
            ),
          ),
        ),
      );
    }
    return BlocConsumer<ProfileEditCubit, ProfileEditState>(
      bloc: cubit,
      listenWhen: (previous, current) => previous.profile != current.profile,
      listener: (context, state) {
        if (state.profile != null && !state.dirty) {
          name.text = state.name;
          weight.text = state.weight;
        }
      },
      builder: (context, state) => PopScope(
        canPop:
            allowPop ||
            !state.dirty && !extraDirty && !state.busy && !savingExtras,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(leave());
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'Edit Profile',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            leading: IconButton(
              tooltip: 'Back',
              onPressed: leave,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          body: SafeArea(
            child: state.profile == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: state.phase == ProfileEditPhase.loading
                          ? const CircularProgressIndicator()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  state.error ??
                                      'Your profile could not be loaded.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                PrimaryButton(
                                  'Try Again',
                                  onPressed: cubit.load,
                                ),
                              ],
                            ),
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: AppMotion.duration(context),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        16,
                        24,
                        24 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.all(10),
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: beamCyan,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: AppMotion.duration(context),
                                      child: ProfileAvatar(
                                        key: ValueKey(
                                          state.photo ??
                                              state.avatarEdit.name +
                                                  (state.profile!.avatarPath ??
                                                      ''),
                                        ),
                                        radius: 43,
                                        bytes: state.photo?.bytes,
                                        url:
                                            state.avatarEdit ==
                                                AvatarEdit.remove
                                            ? null
                                            : state.profile!.avatarDisplayUrl,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: IconButton.filled(
                                      tooltip: 'Edit profile photo',
                                      onPressed: state.busy ? null : photoSheet,
                                      style: IconButton.styleFrom(
                                        minimumSize: const Size(38, 38),
                                        backgroundColor: beamCyan,
                                        foregroundColor: beamNavy,
                                      ),
                                      icon: const Icon(
                                        Icons.camera_alt_outlined,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (state.avatarEdit != AvatarEdit.keep)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  state.avatarEdit == AvatarEdit.remove
                                      ? 'Photo will be removed when you save.'
                                      : 'Photo preview · saved only with Save Changes',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 22),
                            _formRow(
                              'Name',
                              TextFormField(
                                controller: name,
                                enabled: !state.busy && !savingExtras,
                                decoration: _input(
                                  'Full name',
                                  Icons.person_outline,
                                ),
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.name],
                                textInputAction: TextInputAction.next,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (_) => cubit.state.nameError,
                                onChanged: cubit.editName,
                              ),
                            ),
                            _formRow(
                              'Email',
                              TextFormField(
                                key: ValueKey(state.profile!.email),
                                initialValue: state.profile!.email,
                                readOnly: true,
                                decoration: _input('Email', Icons.email)
                                    .copyWith(
                                      suffixIcon: IconButton(
                                        tooltip: 'Change email',
                                        onPressed: state.busy
                                            ? null
                                            : emailDialog,
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: beamMuted,
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                            _formRow(
                              'Gender',
                              DropdownButtonFormField<String>(
                                initialValue:
                                    [
                                      'Male',
                                      'Female',
                                      'Other',
                                      'Prefer not to say',
                                    ].contains(gender)
                                    ? gender
                                    : 'Prefer not to say',
                                isExpanded: true,
                                dropdownColor: beamNavy,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                decoration: _input('Gender', Icons.person),
                                items: [
                                  for (final value in [
                                    'Male',
                                    'Female',
                                    'Other',
                                    'Prefer not to say',
                                  ])
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                                onChanged: flowController == null || state.busy
                                    ? null
                                    : (value) => setState(() {
                                        gender = value!;
                                        extraDirty = true;
                                      }),
                              ),
                            ),
                            _formRow(
                              'Date of Birth',
                              InkWell(
                                onTap: flowController == null || state.busy
                                    ? null
                                    : pickBirthday,
                                child: InputDecorator(
                                  decoration: _input(
                                    'Date of Birth',
                                    Icons.calendar_month,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          birthday == null
                                              ? 'Not set'
                                              : MaterialLocalizations.of(
                                                  context,
                                                ).formatShortDate(birthday!),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.calendar_month_outlined,
                                        size: 18,
                                        color: beamMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            _formRow(
                              'Height',
                              TextFormField(
                                controller: height,
                                enabled: flowController != null && !state.busy,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _input(
                                  'Height',
                                  Icons.straighten,
                                ).copyWith(suffixText: 'cm'),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return null;
                                  }
                                  final parsed = double.tryParse(value);
                                  return parsed == null ||
                                          !parsed.isFinite ||
                                          parsed <= 0
                                      ? 'Enter a valid height'
                                      : null;
                                },
                                onChanged: (_) =>
                                    setState(() => extraDirty = true),
                              ),
                            ),
                            _formRow(
                              'Weight',
                              TextFormField(
                                controller: weight,
                                enabled: !state.busy && !savingExtras,
                                decoration: _input(
                                  'Weight (kg)',
                                  Icons.monitor_weight,
                                ).copyWith(suffixText: 'kg'),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.done,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (_) => cubit.state.weightError,
                                onChanged: cubit.editWeight,
                                onFieldSubmitted: (_) =>
                                    FocusScope.of(context).unfocus(),
                              ),
                            ),
                            _formRow(
                              'Units',
                              InputDecorator(
                                decoration: _input('Units', Icons.straighten),
                                child: const Text(
                                  'Metric (kg, cm)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (state.busy) ...[
                              if (!MediaQuery.disableAnimationsOf(context))
                                const LinearProgressIndicator(),
                              const SizedBox(height: 12),
                              Text(switch (state.phase) {
                                ProfileEditPhase.selecting =>
                                  'Preparing photo…',
                                ProfileEditPhase.uploading =>
                                  'Uploading and saving photo…',
                                ProfileEditPhase.emailChanging =>
                                  'Requesting email change…',
                                _ => 'Saving changes…',
                              }, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                            ],
                            if (state.error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Text(
                                  state.error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            if (state.warning != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Text(state.warning!),
                              ),
                            BeamButton(
                              'Save Changes',
                              onPressed:
                                  (state.canSave || extraDirty) &&
                                      !state.busy &&
                                      !savingExtras
                                  ? () async {
                                      if (form.currentState?.validate() !=
                                          true) {
                                        return;
                                      }
                                      FocusScope.of(context).unfocus();
                                      var saved =
                                          !cubit.state.dirty ||
                                          await cubit.save();
                                      if (saved &&
                                          extraDirty &&
                                          flowController != null) {
                                        setState(() => savingExtras = true);
                                        try {
                                          await flowController!.finishProfile(
                                            name.text.trim(),
                                            weight.text.trim(),
                                            wellness: {
                                              ...flowController!
                                                  .state
                                                  .setup
                                                  .wellness,
                                              'gender': gender,
                                              'birthday': birthday
                                                  ?.toIso8601String(),
                                              'heightCm': double.tryParse(
                                                height.text,
                                              ),
                                              'units': units,
                                            },
                                          );
                                          if (mounted) {
                                            setState(() => extraDirty = false);
                                          }
                                        } catch (_) {
                                          saved = false;
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Could not save wellness details. Try again.',
                                                    ),
                                                  ),
                                                );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(
                                              () => savingExtras = false,
                                            );
                                          }
                                        }
                                      }
                                      if (saved && context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text('Profile saved'),
                                              ),
                                            );
                                      }
                                    }
                                  : null,
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

  Future<void> pickBirthday() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: birthday ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (value != null && mounted) {
      setState(() {
        birthday = value;
        extraDirty = true;
      });
    }
  }

  Widget _formRow(String label, Widget field) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF002131),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, box) =>
            MediaQuery.textScalerOf(context).scale(13) > 21
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: beamMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  field,
                ],
              )
            : Row(
                children: [
                  SizedBox(
                    width: box.maxWidth * .30,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFBBD0DD),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(child: field),
                ],
              ),
      ),
    ),
  );
  InputDecoration _input(String label, IconData icon) => InputDecoration(
    hintText: label,
    hintStyle: const TextStyle(color: beamMuted, fontSize: 13),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    filled: true,
    fillColor: const Color(0xFF001725),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: beamBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFF06485D)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: beamCyan),
    ),
  );
}

class _EmailChangeDialog extends StatefulWidget {
  const _EmailChangeDialog();
  @override
  State<_EmailChangeDialog> createState() => _EmailChangeDialogState();
}

class _EmailChangeDialogState extends State<_EmailChangeDialog> {
  final value = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change email'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Email changes use Supabase Auth. Follow the verification instructions sent to your inbox before using the new address.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: value,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'New email'),
              validator: (value) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid email address',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState?.validate() == true) {
            Navigator.pop(context, value.text.trim());
          }
        },
        child: const Text('Request change'),
      ),
    ],
  );
}
