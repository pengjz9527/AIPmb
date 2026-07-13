"""生活圈画像分析领域 Skill — 分析用户的生活圈、工作地、常去商户和出行方式"""
from collections import Counter
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


# 线上平台关键词（排除，不参与线下生活圈分析）
ONLINE_KEYWORDS = [
    '京东', '淘宝', '唯品会', '抖音', 'QQ', '荣耀', '华为', '支付宝',
    '财付通', '美团平台', '滴滴出行', '哈啰', '亿通行', '轨道', '公交',
    '中铁', '腾讯', '抖店', '抖音月付', '美团', '滴滴', '高德',
]

# 线下实体关键词（保留）
OFFLINE_KEYWORDS = [
    '店', '医院', '中心', '广场', '超市', '市场', '停车场', '物业',
    '小区', '园', '路', '街', '区', '支行', '餐厅', '食堂', '大厦',
    '酒店', '门诊', '药房', '药店', '诊', '安贞', '望京', '中日',
    '儿研', '儿科', '口腔', '眼科', '医美',
]

# 人名特征后缀
PERSON_SUFFIXES = [
    '公司', '店', '医院', '中心', '集团', '银行', '有限', '超市',
    '商场', '餐厅', '食堂', '酒店', '门诊', '药房', '药店', '大厦',
    '支行', '广场', '市场', '停车场', '物业', '小区', '园', '街',
]

# 商户分类规则
CATEGORY_RULES = {
    '餐饮美食': [
        '餐饮', '餐厅', '小吃', '烧烤', '火锅', '面馆', '饭店', '食堂',
        '美食', '汉堡', '肯德基', '麦当劳', '披萨', '茶姬', '贝甜', '甜品',
        '咖啡', '肠粉', '肉饼', '春饼', '盖码饭', '湘菜', '川菜', '粤菜',
        '烘焙', '蛋糕', '奶茶', '茶饮', '锅盔', '饺子', '馄饨', '米线',
        '日料', '寿司', '拉面', '卤味', '炸鸡', '轻食', '沙拉',
    ],
    '超市便利店': [
        '超市', '便利店', '客隆', '7-11', '罗森', '全家', '便利蜂',
        '美宜佳', '京客隆', '首航', '物美', '永辉', '超市发', '华联',
    ],
    '生鲜食品': [
        '盒马', '七鲜', '鲜汇', '生鲜', '蔬菜', '水果', '果多美',
        '稻香村', '味多美', '好利来',
    ],
    '医疗健康': [
        '医院', '医疗', '药房', '药店', '诊所', '安贞', '望京医院',
        '中日友好', '儿研所', '儿科', '口腔', '眼科', '体检', '妇幼',
        '同仁', '协和', '北医', '首都医科', '中医', '康复',
    ],
    '商场购物': [
        '商场', '购物', '万象汇', '华彩', '奥特莱斯', '凯德', '百货',
        '长安商场', '赛特', 'SKP', '国贸', '三里屯', '大悦城', '万达',
        '王府井', '银泰', '来福士', '颐堤港', '芳草地', '蓝色港湾',
    ],
    '交通出行': [
        '地铁', '公交', '停车', '打车', '滴滴', '出租车', '加油',
        '中石化', '中石油', '一卡通', '停简单', 'ETCP', 'P云停车',
        '亿通行', '高德打车', '首汽约车', '神州专车', '曹操出行',
    ],
    '生活缴费': [
        '水电', '燃气', '物业', '供暖', '话费', '联通', '移动', '电信',
        '有线电视', '宽带',
    ],
    '教育学习': [
        '学校', '大学', '中学', '小学', '幼儿园', '培训', '教育',
        '书店', '图书', '文具', '新东方', '学而思', '作业帮',
    ],
    '休闲娱乐': [
        '电影院', '影院', 'KTV', '健身房', '游泳', '瑜伽', 'SPA',
        '美容', '美发', '理发', '足疗', '按摩', '公园', '景区', '游乐',
    ],
}


def _is_online_platform(name: str) -> bool:
    """判断是否为线上平台"""
    return any(kw in name for kw in ONLINE_KEYWORDS)


def _is_person_name(name: str) -> bool:
    """判断是否为人名（2-4个汉字，无公司/店等后缀）"""
    if len(name) > 4:
        return False
    return not any(s in name for s in PERSON_SUFFIXES)


def _categorize_merchant(name: str) -> str:
    """对商户进行分类"""
    for category, keywords in CATEGORY_RULES.items():
        if any(kw in name for kw in keywords):
            return category
    return '其他消费'


def _filter_offline(merchants: list[str]) -> list[str]:
    """过滤出线下实体商户"""
    offline = []
    for m in merchants:
        if _is_online_platform(m):
            continue
        if _is_person_name(m):
            continue
        if len(m) <= 2:
            continue
        offline.append(m)
    return offline


def _infer_location(branches: list[str], offline_merchants: list[str]) -> dict:
    """推断居住区域"""
    # 开户行是强信号
    branch_hints = []
    for b in branches:
        if '支行' in b:
            branch_hints.append(b.replace('支行', '').replace('北京', '').strip())

    # 高频商户中的地名
    location_keywords = [
        '望京', '朝阳', '海淀', '中关村', '西二旗', '国贸', '三里屯',
        '亚运村', '安贞', '东城', '西城', '丰台', '石景山', '通州',
        '大兴', '昌平', '顺义', '亦庄', '上地', '五道口', '酒仙桥',
        '大望路', '双井', '劲松', '潘家园', '十里堡', '常营', '天通苑',
        '回龙观', '立水桥', '北苑', '来广营', '太阳宫', '亮马桥',
    ]
    location_counts = Counter()
    for m in offline_merchants:
        for loc in location_keywords:
            if loc in m:
                location_counts[loc] += 1

    return {
        'branches': branch_hints,
        'location_hints': dict(location_counts.most_common(8)),
    }


def _infer_workplace(counterparties: list[str]) -> list[dict]:
    """推断工作区域"""
    work_candidates = []
    for cp in counterparties:
        if _is_online_platform(cp):
            continue
        if _is_person_name(cp):
            continue
        if any(kw in cp for kw in ['公司', '股份', '有限', '科技', '技术', '网络']):
            work_candidates.append(cp)

    work_counts = Counter(work_candidates)
    top_work = work_counts.most_common(5)
    return [{'name': name, 'count': count} for name, count in top_work]


def _analyze_commute(merchants: list[str], counterparties: list[str]) -> dict:
    """分析通勤方式"""
    all_names = merchants + counterparties
    commute = {
        '地铁': sum(1 for n in all_names if any(
            kw in n for kw in ['轨道', '地铁', '亿通行', '轨道交通'])),
        '公交': sum(1 for n in all_names if '公交' in n),
        '打车': sum(1 for n in all_names if any(
            kw in n for kw in ['滴滴', '出行', '打车', '高德', '首汽', '神州', '曹操'])),
        '共享单车': sum(1 for n in all_names if any(
            kw in n for kw in ['哈啰', '美团单车', '青桔'])),
        '开车': sum(1 for n in all_names if any(
            kw in n for kw in ['停车', '加油', '中石化', '中石油', '停简单', 'ETCP', 'P云'])),
        '火车': sum(1 for n in all_names if '中铁' in n or '火车' in n),
    }
    return commute


class NeighborhoodProfilerSkill(BaseSkill):
    """生活圈画像分析 — 收集交易数据，分析用户生活圈"""

    @property
    def name(self) -> str:
        return "neighborhood_profiler"

    @property
    def description(self) -> str:
        return (
            "分析我的生活圈画像。从交易记录中识别居住区域、工作地、"
            "常去商户（商场/超市/医院/学校等）、出行方式习惯，发现生活重心和偏好。"
            "当我询问'我的生活圈'、'我住在哪里'、'我家附近有什么'、"
            "'分析我的生活'等涉及地理位置和生活方式的问题时调用。"
        )

    @property
    def parameters_schema(self) -> dict:
        return {"type": "object", "properties": {}}

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")
        api = create_client(user_name=user_name)

        # 1. 加载账户数据
        account_rows, _ = await api.list_accounts(limit=1000)
        branches = []
        for row in account_rows:
            branch = str(row.get('branch', ''))
            if branch and branch != 'None' and '支行' in branch:
                branches.append(branch)

        # 2. 加载信用卡交易
        credit_merchants = []
        credit_all = []
        credit_txs, _ = await api.list_transactions(source="credit", limit=10000)
        for row in credit_txs:
            merchant = str(row.get('merchant', ''))
            if merchant and merchant != 'None':
                credit_merchants.append(merchant)
                credit_all.append({
                    'merchant': merchant,
                    'category': str(row.get('subcategory', '')),
                    'amount': _safe_float(row.get('amount', 0)),
                    'date': str(row.get('date', '')),
                    'direction': str(row.get('direction', '')),
                })

        # 3. 加载借记卡交易
        debit_counterparties = []
        debit_all = []
        debit_txs, _ = await api.list_transactions(source="debit", limit=10000)
        for row in debit_txs:
            cp = str(row.get('merchant', ''))
            if cp and cp != 'None':
                debit_counterparties.append(cp)
                debit_all.append({
                    'counterparty': cp,
                    'category': str(row.get('category', '')),
                    'amount': _safe_float(row.get('amount', 0)),
                    'date': str(row.get('date', '')),
                    'direction': str(row.get('direction', '')),
                })

        # 4. 合并所有商户名
        all_merchant_names = credit_merchants + debit_counterparties

        # 5. 过滤线下商户
        offline_merchants = _filter_offline(all_merchant_names)
        offline_counts = Counter(offline_merchants)

        # 6. 分类统计
        category_stats = {}
        for merchant, count in offline_counts.most_common(200):
            category = _categorize_merchant(merchant)
            if category not in category_stats:
                category_stats[category] = []
            category_stats[category].append({'name': merchant, 'count': count})

        # 7. 推断居住区域
        location_info = _infer_location(branches, offline_merchants)

        # 8. 推断工作区域
        workplace_info = _infer_workplace(debit_counterparties)

        # 9. 分析通勤方式
        commute_info = _analyze_commute(credit_merchants, debit_counterparties)

        # 10. 在线平台统计（补充参考）
        online_counter = Counter()
        for m in all_merchant_names:
            if _is_online_platform(m):
                online_counter[m] += 1
        top_online = online_counter.most_common(10)

        # 11. 交易金额统计（按线下商户合并）
        merchant_amounts = {}
        for tx in credit_all:
            m = tx['merchant']
            if not _is_online_platform(m) and not _is_person_name(m) and len(m) > 2:
                if m not in merchant_amounts:
                    merchant_amounts[m] = {'count': 0, 'total': 0.0}
                merchant_amounts[m]['count'] += 1
                merchant_amounts[m]['total'] += tx['amount']

        # 高频线下商户（按次数+金额排序）
        top_offline_detail = sorted(
            [{'name': m, **v} for m, v in merchant_amounts.items()],
            key=lambda x: (x['count'], x['total']),
            reverse=True,
        )[:30]

        return SkillResult(
            success=True,
            data={
                'branches': branches,
                'location_inference': location_info,
                'workplace_inference': workplace_info,
                'offline_merchants_by_category': category_stats,
                'commute_analysis': commute_info,
                'top_offline_merchants': [
                    {'name': name, 'count': count}
                    for name, count in offline_counts.most_common(30)
                ],
                'top_offline_detail': top_offline_detail,
                'top_online_platforms': [
                    {'name': name, 'count': count}
                    for name, count in top_online
                ],
                'credit_tx_count': len(credit_merchants),
                'debit_tx_count': len(debit_counterparties),
                'offline_merchant_count': len(set(offline_merchants)),
            },
            summary=(
                f"已分析生活圈数据：{len(branches)}个开户行、"
                f"{len(set(offline_merchants))}个线下商户、"
                f"{len(credit_merchants)}笔信用卡交易+{len(debit_counterparties)}笔记账交易，"
                f"共{len(set(offline_merchants))}个独立线下商户"
            ),
        )


def _safe_float(v) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0