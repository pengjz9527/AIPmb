class HistoryTodayMemory {
  final String eventType;
  final String title;
  final String description;
  final int year;
  final String benefitType;

  const HistoryTodayMemory({
    required this.eventType,
    required this.title,
    required this.description,
    required this.year,
    required this.benefitType,
  });

  factory HistoryTodayMemory.fromJson(Map<String, dynamic> json) {
    return HistoryTodayMemory(
      eventType: json['event_type'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      year: json['year'] ?? DateTime.now().year - 1,
      benefitType: json['benefit_type'] ?? '',
    );
  }

  String get eventTypeLabel {
    switch (eventType) {
      case 'major_purchase':
        return '重要消费';
      case 'first_income':
        return '首笔收入';
      case 'family_care':
        return '家人关爱';
      case 'travel_memory':
        return '旅行记忆';
      case 'growth_milestone':
        return '成长里程碑';
      case 'daily_warmth':
        return '生活温暖';
      default:
        return '纪念';
    }
  }
}

class HistoryTodayBenefit {
  final String label;
  final String description;
  final String benefitType;
  final String benefitDesc;
  final String icon;
  final bool forFamily;
  final HistoryTodayProduct? linkedProduct;

  const HistoryTodayBenefit({
    required this.label,
    required this.description,
    required this.benefitType,
    required this.benefitDesc,
    required this.icon,
    required this.forFamily,
    this.linkedProduct,
  });

  factory HistoryTodayBenefit.fromJson(Map<String, dynamic> json) {
    return HistoryTodayBenefit(
      label: json['label'] ?? '',
      description: json['description'] ?? '',
      benefitType: json['benefit_type'] ?? '',
      benefitDesc: json['benefit_desc'] ?? '',
      icon: json['icon'] ?? 'emoji_events',
      forFamily: json['for_family'] ?? false,
      linkedProduct: json['linked_product'] != null
          ? HistoryTodayProduct.fromJson(json['linked_product'] as Map<String, dynamic>)
          : null,
    );
  }
}

class HistoryTodayProduct {
  final String productName;
  final String category;
  final String bank;
  final String description;
  final String detailLink;

  const HistoryTodayProduct({
    required this.productName,
    required this.category,
    required this.bank,
    required this.description,
    required this.detailLink,
  });

  factory HistoryTodayProduct.fromJson(Map<String, dynamic> json) {
    return HistoryTodayProduct(
      productName: json['product_name'] ?? '',
      category: json['category'] ?? '',
      bank: json['bank'] ?? '',
      description: json['description'] ?? '',
      detailLink: json['detail_link'] ?? '',
    );
  }
}

class HistoryTodayResult {
  final bool hasMemory;
  final String today;
  final String todayFormatted;
  final HistoryTodayMemory? memory;
  final HistoryTodayBenefit? benefit;
  final String yearsSummary;
  final int txCount;
  final List<int> years;

  const HistoryTodayResult({
    required this.hasMemory,
    required this.today,
    required this.todayFormatted,
    this.memory,
    this.benefit,
    required this.yearsSummary,
    required this.txCount,
    required this.years,
  });

  factory HistoryTodayResult.fromJson(Map<String, dynamic> json) {
    return HistoryTodayResult(
      hasMemory: json['has_memory'] ?? false,
      today: json['today'] ?? '',
      todayFormatted: json['today_formatted'] ?? '',
      memory: json['memory'] != null
          ? HistoryTodayMemory.fromJson(json['memory'] as Map<String, dynamic>)
          : null,
      benefit: json['benefit'] != null
          ? HistoryTodayBenefit.fromJson(json['benefit'] as Map<String, dynamic>)
          : null,
      yearsSummary: json['years_summary'] ?? '',
      txCount: json['tx_count'] ?? 0,
      years: (json['years'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}
