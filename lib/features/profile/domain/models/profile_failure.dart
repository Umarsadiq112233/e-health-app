/// Safe messages only; never includes query text, tokens or profile values.
class ProfileFailure implements Exception {
  final String message;
  const ProfileFailure(this.message);

  factory ProfileFailure.database(String? code, {String? details}) {
    return ProfileFailure(switch (code) {
        'PGRST205' || '42P01' => 'Your account is connected, but profile storage has not been set up yet. Please contact support.',
        'PGRST204' ||
        '42703' => 'Profile storage needs an update. Please contact support.',
        '42501' => 'Supabase denied access to your profile. Check that the latest RLS policies are deployed.',
        'permission-denied' => 'Supabase denied access. Confirm that the latest RLS policies are deployed.',
        'unauthenticated' => 'Your session could not be verified. Please log out and sign in again.',
        'unavailable' => 'Supabase could not be reached. Check your connection and retry.',
        'deadline-exceeded' => 'Supabase is temporarily unavailable. Check your internet connection and retry.',
        _ => 'Could not load your profile. Please try again.',
      });
  }
}
