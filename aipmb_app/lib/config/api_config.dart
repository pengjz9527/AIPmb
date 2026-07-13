class ApiConfig {
  // Android 模拟器中 10.0.2.2 指向宿主机，真机用户请在登录页点击右上角齿轮修改为电脑 IP
  static const String _defaultBaseUrl = 'http://10.0.2.2:8000';
  static String _baseUrl = _defaultBaseUrl;

  /// 当前服务器地址（可从 SharedPreferences 加载或运行时修改）
  static String get baseUrl => _baseUrl;

  /// 运行时修改服务器地址
  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  static const String accounts = '/api/v1/accounts';
  static const String accountSummary = '/api/v1/accounts/summary';
  static const String wealthOverview = '/api/v1/wealth/overview';
  static const String transactions = '/api/v1/transactions';
  static const String transactionSummary = '/api/v1/transactions/summary';
  static const String products = '/api/v1/products';
  static const String productCategories = '/api/v1/products/categories';
  static const String consumptions = '/api/v1/consumptions';
  static const String consumptionStats = '/api/v1/consumptions/stats';
  static const String chatWs = '/api/v1/chat/ws';
  static const String chatSessions = '/api/v1/chat/sessions';
  static const String agents = '/api/v1/agents';
  static const String recommendationsTodos = '/api/v1/recommendations/todos';
  static const String recommendationsPromos = '/api/v1/recommendations/promos';
  static const String recommendationsProducts = '/api/v1/recommendations/products';
  static const String aiMatchedProducts = '/api/v1/recommendations/ai-products';
  static const String aiMatchedProductsStatus = '/api/v1/recommendations/ai-products/status';
  static const String profileTags = '/api/v1/profile/tags';
  static const String uploadImage = '/api/v1/upload/image';
  static const String uploadVoice = '/api/v1/upload/voice';
  static const String authLogin = '/api/v1/auth/login';
  static const String domainSkills = '/api/v1/skills/domain';
  static const String historyToday = '/api/v1/skills/history-today';
  static const String purchases = '/api/v1/purchases';
  static const String riskAssessment = '/api/v1/risk-assessment';
  static const String calendarGenerate = '/api/v1/manage/calendar';      // POST {name}/generate-async
  static const String calendarStatus = '/api/v1/manage/calendar';        // GET {name}/status
  static const String calendarGet = '/api/v1/manage/calendar';           // GET {name}

  // 缴费相关
  static const String payments = '/api/v1/payments';
  static const String paymentsSummary = '/api/v1/payments/summary';
  static const String paymentsForecast = '/api/v1/payments/forecast';

  // AI 洞察
  static const String aiInsight = '/api/v1/ai/insight';

  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.host}:${uri.port}';
  }
}
