class Credentials {
  final String email;
  final String password;

  const Credentials({
    required this.email,
    required this.password,
  });

  factory Credentials.fromJson(Map<String, dynamic> json) {
    return Credentials(
      email: json['email'] as String,
      password: json['password'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}
