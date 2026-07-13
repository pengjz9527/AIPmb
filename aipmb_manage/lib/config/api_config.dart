class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';

  // Model Config
  static const String modelConfigs = '/api/v1/manage/model-configs';
  static const String activeModelConfig = '/api/v1/manage/model-configs/active';
  static String configDetail(String id) => '/api/v1/manage/model-configs/$id';
  static String configActivate(String id) => '/api/v1/manage/model-configs/$id/activate';

  // Users
  static const String users = '/api/v1/manage/users';
  static String userDetail(String name) => '/api/v1/manage/users/$name';
  static String userAccounts(String name) => '/api/v1/manage/users/$name/accounts';
  static String userTransactions(String name) => '/api/v1/manage/users/$name/transactions';
  static String userConsumptionStats(String name) => '/api/v1/manage/users/$name/consumption-stats';
  static String userSummary(String name) => '/api/v1/manage/users/$name/summary';

  // Tags
  static const String tags = '/api/v1/manage/tags';
  static String userTags(String name) => '/api/v1/manage/tags/$name';
  static String generateTags(String name) => '/api/v1/manage/tags/$name/generate';
  static const String batchGenerateTags = '/api/v1/manage/tags/batch-generate';

  // Calendar
  static String calendar(String name) => '/api/v1/manage/calendar/$name';
  static String generateCalendar(String name) => '/api/v1/manage/calendar/$name/generate';
  static String generateCalendarAsync(String name) => '/api/v1/manage/calendar/$name/generate-async';
  static String calendarStatus(String name) => '/api/v1/manage/calendar/$name/status';
  static const String batchGenerateCalendar = '/api/v1/manage/calendar/batch-generate';
  static String calendarEvents(String name) => '/api/v1/manage/calendar/$name/events';

  // Matches
  static const String matches = '/api/v1/manage/matches';
  static String userMatches(String name) => '/api/v1/manage/matches/$name';
  static String matchedProducts(String name) => '/api/v1/manage/matches/$name/products';
  static String recommendations(String name) => '/api/v1/manage/recommendations/$name';

  // Product Matching
  static String startProductMatching(String name) => '/api/v1/manage/products/$name/match-async';
  static String productMatchingStatus(String name) => '/api/v1/manage/products/$name/match-status';
  static String productMatchResult(String name) => '/api/v1/manage/products/$name/match-result';

  // Profile Portrait 用户性格画像
  static String startPortrait(String name) => '/api/v1/manage/portrait/$name/generate-async';
  static String portraitStatus(String name) => '/api/v1/manage/portrait/$name/status';
  static String portraitResult(String name) => '/api/v1/manage/portrait/$name/result';

  // Conversations
  static String userConversations(String name) => '/api/v1/manage/users/$name/conversations';
  static String conversationDetail(String name, String sessionId) => '/api/v1/manage/users/$name/conversations/$sessionId';
  static String analyzeConversation(String name) => '/api/v1/manage/users/$name/conversations/analyze';
  static String conversationSummary(String name) => '/api/v1/manage/users/$name/conversation-summary';
  static String marketingLeads(String name) => '/api/v1/manage/users/$name/marketing-leads';
  static String marketingLeadsStream(String name) => '/api/v1/manage/users/$name/marketing-leads/stream';

  // Held Products
  static String heldSummary(String name) => '/api/v1/held-products/summary/$name';
  static String heldWealth(String name) => '/api/v1/held-products/wealth?user_name=$name';
  static String heldLoans(String name) => '/api/v1/held-products/loans?user_name=$name';
  static String heldPensions(String name) => '/api/v1/held-products/pensions?user_name=$name';

  // Skill Monitor (技能监控)
  static const String skillLogs = '/api/v1/manage/skill-logs';
  static String skillLogDetail(String logId) => '/api/v1/manage/skill-logs/$logId';
  static const String skillWeeklyReport = '/api/v1/manage/skill-logs/report/weekly';
  static const String skillNames = '/api/v1/manage/skill-names';
}