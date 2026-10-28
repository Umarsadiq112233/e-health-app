/// Safe messages only; never includes query text, tokens or profile values.
class ProfileFailure implements Exception {
  final String message;
  const ProfileFailure(this.message);

  factory ProfileFailure.database(String? code) => ProfileFailure(
    switch (code) {
      'PGRST205' || '42P01' => 'Your account is connected, but profile storage has not been set up yet. Please contact support.',
      'PGRST204' ||
      '42703' => 'Profile storage needs an update. Please contact support.',
      '42501' => 'Your profile could not be accessed. Please contact support to check profile permissions.',
      'PGRST301' || 'PGRST302' || 'PGRST303' || '28000' =>
        'Your session could not be verified. Please log out and sign in again.',
      _ => 'Could not load your profile. Please try again.',
    },
  );
}
