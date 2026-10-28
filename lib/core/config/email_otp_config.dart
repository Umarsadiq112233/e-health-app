/// Public UX settings only. Keep aligned with Supabase Auth deployment settings.
/// Auth still enforces expiration and rate limits, independent of this client.
abstract final class EmailOtpConfig {
  /// Set to link only when the hosted recovery template contains only a link.
  static const recoveryUsesOtp =
      String.fromEnvironment('AUTH_RECOVERY_MODE', defaultValue: 'otp') !=
      'link';
  static const _length = int.fromEnvironment(
    'AUTH_EMAIL_OTP_LENGTH',
    defaultValue: 6,
  );
  static const _resend = int.fromEnvironment(
    'AUTH_EMAIL_RESEND_SECONDS',
    defaultValue: 60,
  );
  static int get codeLength => _length >= 6 && _length <= 10 ? _length : 6;
  static int get minCodeLength => 6;
  static int get maxCodeLength => 10;
  static int get resendSeconds => _resend > 0 ? _resend : 60;
}
