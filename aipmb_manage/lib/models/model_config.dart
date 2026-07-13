class ModelConfig {
  final String id;
  final String name;
  final String provider;
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  ModelConfig({
    required this.id,
    required this.name,
    required this.provider,
    required this.apiKey,
    required this.baseUrl,
    required this.modelName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      provider: json['provider'] ?? '',
      apiKey: json['api_key'] ?? '',
      baseUrl: json['base_url'] ?? '',
      modelName: json['model_name'] ?? '',
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'provider': provider,
    'api_key': apiKey,
    'base_url': baseUrl,
    'model_name': modelName,
  };
}