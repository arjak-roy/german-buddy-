class AppUser {
  final String id;
  final String? email;
  final String? displayName;
  final String languageLevel;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.languageLevel = 'B1',
  });
}
