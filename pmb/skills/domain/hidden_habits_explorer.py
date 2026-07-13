"""探索隐秘习惯领域 Skill — 从交易消费记录中发现用户的有趣生活习惯、生活圈轨迹和偏好。

输出以图表为主、文字为辅，减少冗长描述。
"""
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pmb.skills.base import BaseSkill, SkillResult
from pmb.skills.api_client import create_client


# ---- 线上平台关键词 ----
ONLINE_KEYWORDS = [
    '京东', '淘宝', '唯品会', '抖音', 'QQ', '荣耀', '华为', '支付宝',
    '财付通', '美团平台', '滴滴出行', '哈啰', '亿通行', '轨道', '公交',
    '中铁', '腾讯', '抖店', '抖音月付', '美团', '滴滴', '高德',
    '拼多多', '天猫', '苏宁', '当当', '网易严选',
]

# ---- 商户分类规则 ----
CATEGORY_RULES = {
    '咖啡茶饮': ['咖啡', '茶姬', '星巴克', '瑞幸', 'Costa', 'Manner', 'Tims', '奶茶', '茶饮', '喜茶', '奈雪', 'CoCo', '一点点', '蜜雪冰城'],
    '外卖速食': ['外卖', '快餐', '汉堡', '肯德基', '麦当劳', '披萨', '必胜客', '赛百味', '德克士', '华莱士'],
    '餐饮美食': ['餐饮', '餐厅', '小吃', '烧烤', '火锅', '面馆', '饭店', '食堂', '美食', '肠粉', '肉饼', '春饼', '湘菜', '川菜', '粤菜', '日料', '寿司', '拉面', '卤味', '炸鸡', '轻食', '沙拉', '饺子', '馄饨', '米线', '烘焙', '蛋糕', '甜品', '锅盔'],
    '超市便利店': ['超市', '便利店', '客隆', '7-11', '罗森', '全家', '便利蜂', '美宜佳', '京客隆', '首航', '物美', '永辉', '超市发', '华联', '盒马', '七鲜'],
    '生鲜食品': ['生鲜', '蔬菜', '水果', '果多美', '稻香村', '味多美', '好利来'],
    '医疗健康': ['医院', '医疗', '药房', '药店', '诊所', '安贞', '望京医院', '中日友好', '儿研所', '儿科', '口腔', '眼科', '体检', '妇幼', '同仁', '协和', '北医', '首都医科', '中医', '康复'],
    '商场购物': ['商场', '购物', '万象汇', '华彩', '奥特莱斯', '凯德', '百货', '长安商场', '赛特', 'SKP', '国贸', '三里屯', '大悦城', '万达', '王府井', '银泰', '来福士', '颐堤港', '芳草地', '蓝色港湾'],
    '交通出行': ['地铁', '公交', '停车', '打车', '出租', '加油', '中石化', '中石油', '一卡通', '停简单', 'ETCP', '首汽', '神州', '曹操'],
    '生活缴费': ['水电', '燃气', '物业', '供暖', '话费', '联通', '移动', '电信', '有线电视', '宽带'],
    '休闲娱乐': ['电影院', '影院', 'KTV', '健身房', '游泳', '瑜伽', 'SPA', '美容', '美发', '理发', '足疗', '按摩', '公园', '景区', '游乐'],
}

# ---- 订阅型服务检测关键词（仅限线上数字内容/会员类） ----
SUBSCRIPTION_KEYWORDS = {
    '视频会员': ['爱奇艺', '腾讯视频', '优酷', '芒果TV', 'B站', 'bilibili', '哔哩哔哩', 'Netflix', 'YouTube', 'Disney', 'HBO', 'Hulu'],
    '音乐会员': ['QQ音乐', '网易云', '酷狗', 'Spotify', 'Apple Music', '喜马拉雅', '蜻蜓FM', '懒人听书'],
    '云存储': ['iCloud', '百度网盘', 'Google One', 'Dropbox', 'OneDrive', '阿里云盘', '夸克网盘'],
    '知识付费': ['得到', '樊登', '知乎', '知识星球', '极客时间', '混沌', '三联中读', '看理想'],
    '阅读充值': ['微信读书', '掌阅', '起点', '晋江', '番茄小说', '书旗', '快看漫画', '哔哩哔哩漫画', 'Kindle', '多看'],
    '游戏订阅': ['Steam', 'PlayStation', 'Xbox', 'Nintendo', 'Switch Online', 'Epic', 'XGP', 'Game Pass'],
    '办公软件': ['WPS', 'Microsoft 365', 'Office 365', 'Notion', 'Evernote', '滴答清单', '百度文库'],
}

# ---- 明确排除的非订阅型消费（防止误判） ----
NON_SUBSCRIPTION_MERCHANTS = [
    '滴滴', '地铁', '轨道', '公交', '出租车', '中铁', '高德', '首汽', '神州', '曹操',
    '餐厅', '饭店', '食堂', '小吃', '烧烤', '火锅', '面馆', '外卖', '快餐',
    '汉堡', '披萨', '烘焙', '蛋糕', '奶茶', '咖啡', '茶', '超市', '便利店',
    '停车', '加油', '中石化', '中石油',
]


def _safe_float(v) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def _is_online(name: str) -> bool:
    return any(kw in name for kw in ONLINE_KEYWORDS)


def _categorize(name: str) -> str:
    for cat, kws in CATEGORY_RULES.items():
        if any(kw in name for kw in kws):
            return cat
    return '其他消费'


def _is_person_name(name: str) -> bool:
    if len(name) > 4:
        return False
    suffixes = ['公司', '店', '医院', '中心', '集团', '银行', '有限', '超市',
                '商场', '餐厅', '食堂', '酒店', '门诊', '药房', '药店', '大厦',
                '支行', '广场', '市场', '停车场', '物业', '小区', '园', '街']
    return not any(s in name for s in suffixes)


def _parse_date(date_str: str) -> datetime | None:
    """解析日期字符串，返回 datetime 或 None"""
    for fmt in ['%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M', '%Y-%m-%d', '%Y/%m/%d', '%Y%m%d']:
        try:
            return datetime.strptime(date_str.strip(), fmt)
        except ValueError:
            continue
    return None


class HiddenHabitsExplorerSkill(BaseSkill):
    """探索隐秘习惯 — 从交易消费中发现用户的有趣生活习惯和生活圈轨迹"""

    @property
    def name(self) -> str:
        return "hidden_habits_explorer"

    @property
    def description(self) -> str:
        return (
            "探索我隐秘的生活习惯。从交易和消费记录中提取有趣的生活规律、"
            "消费偏好和隐藏习惯，围绕家庭地址画出生活圈轨迹，标记最常去的"
            "商户和机构，并给出改善生活/理财的个性化建议。"
            "当我询问'我的习惯'、'生活习惯'、'消费习惯'、'生活圈轨迹'、"
            "'我最喜欢去的地方'、'分析我的生活方式'等问题时调用。"
        )

    @property
    def parameters_schema(self) -> dict:
        return {"type": "object", "properties": {}}

    async def execute(self, **kwargs) -> SkillResult:
        user_name = kwargs.get("user_name", "")
        api = create_client(user_name=user_name)

        # ========== 1. 加载数据 ==========
        credit_txs, _ = await api.list_transactions(source="credit", limit=10000)
        debit_txs, _ = await api.list_transactions(source="debit", limit=10000)

        all_txs = []
        for tx in credit_txs:
            all_txs.append({
                'merchant': str(tx.get('merchant', '')),
                'amount': _safe_float(tx.get('amount', 0)),
                'date': str(tx.get('date', '')),
                'direction': str(tx.get('direction', '支出')),
                'category': str(tx.get('subcategory', tx.get('category', ''))),
                'source': 'credit',
            })
        for tx in debit_txs:
            all_txs.append({
                'merchant': str(tx.get('merchant', '')),
                'amount': _safe_float(tx.get('amount', 0)),
                'date': str(tx.get('date', '')),
                'direction': str(tx.get('direction', '支出')),
                'category': str(tx.get('category', '')),
                'source': 'debit',
            })

        expense_txs = [tx for tx in all_txs if tx['amount'] > 0 and tx['direction'] in ('支出', 'expense', '')]

        if not expense_txs:
            return SkillResult(success=True, data={}, summary="未找到消费记录，无法分析。")

        # 加载账户数据
        account_rows, _ = await api.list_accounts(limit=1000)
        branches = []
        for row in account_rows:
            branch = str(row.get('branch', ''))
            if branch and branch != 'None' and '支行' in branch:
                branches.append(branch)

        # ========== 2. 时间维度分析 ==========
        time_patterns = self._analyze_time_patterns(expense_txs)

        # ========== 3. 习惯检测（含增强版订阅分析） ==========
        habits = self._detect_habits(expense_txs)

        # ========== 4. 生活圈分析 ==========
        life_circle = self._analyze_life_circle(expense_txs, branches)

        # ========== 5. TOP 洞察 ==========
        top_insights = self._top_insights(expense_txs)

        # ========== 6. 生成图表 ==========
        charts = self._build_charts(expense_txs, time_patterns, life_circle, top_insights, habits)

        # ========== 7. 生成建议 ==========
        suggestions = self._generate_suggestions(habits, time_patterns, life_circle, top_insights)

        total_expense = sum(tx['amount'] for tx in expense_txs)
        unique_merchants = len(set(tx['merchant'] for tx in expense_txs if tx['merchant'] and tx['merchant'] != 'None'))

        return SkillResult(
            success=True,
            data={
                'total_transactions': len(expense_txs),
                'total_expense': round(total_expense, 2),
                'unique_merchants': unique_merchants,
                'time_patterns': time_patterns,
                'habits': habits,
                'life_circle': life_circle,
                'top_insights': top_insights,
                'charts': charts,
                'suggestions': suggestions,
                'branches': branches,
            },
            summary=(
                f"已分析{len(expense_txs)}笔消费记录，发现{len(habits)}个生活习惯模式，"
                f"覆盖{unique_merchants}个商户，"
                f"生成{len(charts)}张图表"
            ),
        )

    # ==================================================================
    #  时间模式分析
    # ==================================================================
    def _analyze_time_patterns(self, txs: list[dict]) -> dict:
        hour_counts = defaultdict(lambda: {'count': 0, 'total': 0.0})
        weekday_counts = defaultdict(lambda: {'count': 0, 'total': 0.0})
        monthly_totals = defaultdict(float)

        weekday_names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
        weekend_count = 0
        weekend_total = 0.0
        weekday_count_val = 0
        weekday_total_val = 0.0
        late_night_count = 0
        late_night_total = 0.0

        for tx in txs:
            date_str = tx['date']
            amount = tx['amount']
            if len(date_str) >= 7:
                monthly_totals[date_str[:7]] += amount

            dt = _parse_date(date_str)
            if dt is None:
                continue

            hour = dt.hour
            wd = dt.weekday()

            hour_counts[hour]['count'] += 1
            hour_counts[hour]['total'] += amount
            weekday_counts[wd]['count'] += 1
            weekday_counts[wd]['total'] += amount

            if wd >= 5:
                weekend_count += 1
                weekend_total += amount
            else:
                weekday_count_val += 1
                weekday_total_val += amount

            if 22 <= hour or hour < 6:
                late_night_count += 1
                late_night_total += amount

        sorted_hours = sorted(hour_counts.items(), key=lambda x: x[1]['count'], reverse=True)
        peak_hours = [{'hour': h, 'count': v['count'], 'total': round(v['total'], 2)}
                      for h, v in sorted_hours[:6]]

        weekday_dist = [
            {'day': weekday_names[d], 'count': weekday_counts.get(d, {}).get('count', 0),
             'total': round(weekday_counts.get(d, {}).get('total', 0.0), 2)}
            for d in range(7)
        ]

        monthly_trend = sorted(monthly_totals.items())
        total_count = weekend_count + weekday_count_val
        late_night_ratio = late_night_count / total_count if total_count > 0 else 0
        weekend_ratio = weekend_total / (weekend_total + weekday_total_val) if (weekend_total + weekday_total_val) > 0 else 0

        # 24小时完整分布（用于热力图图表）
        hour_full = []
        for h in range(24):
            d = hour_counts.get(h, {'count': 0, 'total': 0.0})
            hour_full.append({'hour': h, 'count': d['count'], 'total': round(d['total'], 2)})

        return {
            'peak_hours': peak_hours,
            'hour_full': hour_full,
            'weekday_distribution': weekday_dist,
            'monthly_trend': [{'month': m, 'total': round(v, 2)} for m, v in monthly_trend],
            'weekend_ratio': round(weekend_ratio, 3),
            'weekend_total': round(weekend_total, 2),
            'weekday_total': round(weekday_total_val, 2),
            'late_night_count': late_night_count,
            'late_night_total': round(late_night_total, 2),
            'late_night_ratio': round(late_night_ratio, 3),
            'weekend_vs_weekday_avg': (
                round(weekend_total / max(weekend_count, 1), 2),
                round(weekday_total_val / max(weekday_count_val, 1), 2),
            ),
        }

    # ==================================================================
    #  隐藏习惯检测（含增强版订阅/周期性消费分析）
    # ==================================================================
    def _detect_habits(self, txs: list[dict]) -> list[dict]:
        habits = []

        merchant_stats = defaultdict(lambda: {'count': 0, 'total': 0.0, 'dates': []})
        for tx in txs:
            m = tx['merchant']
            if not m or m == 'None' or _is_person_name(m):
                continue
            merchant_stats[m]['count'] += 1
            merchant_stats[m]['total'] += tx['amount']
            merchant_stats[m]['dates'].append(tx['date'])

        # --- 习惯1: 咖啡/茶饮成瘾 ---
        caffeine_merchants = []
        caffeine_count = 0
        caffeine_total = 0.0
        for m, s in merchant_stats.items():
            if _categorize(m) == '咖啡茶饮':
                caffeine_merchants.append({'name': m, 'count': s['count'], 'total': round(s['total'], 2)})
                caffeine_count += s['count']
                caffeine_total += s['total']
        if caffeine_count >= 5:
            caffeine_merchants.sort(key=lambda x: x['count'], reverse=True)
            habits.append({
                'type': 'coffee_addict',
                'icon': '☕',
                'label': '咖啡/茶饮爱好者',
                'count': caffeine_count,
                'total': round(caffeine_total, 2),
                'top_merchants': caffeine_merchants[:5],
                'avg_per_time': round(caffeine_total / max(caffeine_count, 1), 2),
                'yearly_estimate': round(caffeine_total / max(caffeine_count, 1) * 365, 0),
            })

        # --- 习惯2: 外卖重度 ---
        takeout_merchants = []
        takeout_count = 0
        takeout_total = 0.0
        for m, s in merchant_stats.items():
            if any(kw in m for kw in ['外卖', '快餐', '汉堡', '披萨', '炸鸡', '盖码饭', '拌饭', '便当']):
                takeout_merchants.append({'name': m, 'count': s['count'], 'total': round(s['total'], 2)})
                takeout_count += s['count']
                takeout_total += s['total']
        if takeout_count >= 5:
            habits.append({
                'type': 'takeout_lover',
                'icon': '🍔',
                'label': '外卖/快餐高频消费',
                'count': takeout_count,
                'total': round(takeout_total, 2),
                'top_merchants': sorted(takeout_merchants, key=lambda x: x['count'], reverse=True)[:5],
                'avg_per_time': round(takeout_total / max(takeout_count, 1), 2),
            })

        # --- 习惯3: 夜间活跃 ---
        night_txs = [tx for tx in txs if (dt := _parse_date(tx['date'])) and (dt.hour >= 22 or dt.hour < 6)]
        if len(night_txs) >= 3:
            night_total = sum(tx['amount'] for tx in night_txs)
            night_cats = Counter(_categorize(tx['merchant']) for tx in night_txs if tx['merchant'] and tx['merchant'] != 'None')
            habits.append({
                'type': 'night_owl',
                'icon': '🌙',
                'label': '夜间消费活跃',
                'count': len(night_txs),
                'total': round(night_total, 2),
                'top_categories': night_cats.most_common(5),
            })

        # --- 习惯4: 小额高频 ---
        small_txs = [tx for tx in txs if 0 < tx['amount'] <= 50]
        if len(small_txs) >= 10:
            small_total = sum(tx['amount'] for tx in small_txs)
            small_merchants = Counter(tx['merchant'] for tx in small_txs if tx['merchant'] and tx['merchant'] != 'None')
            num_months = max(len(set(tx['date'][:7] for tx in txs if len(tx['date']) >= 7)), 1)
            habits.append({
                'type': 'impulse_buyer',
                'icon': '💳',
                'label': '小额高频消费',
                'count': len(small_txs),
                'total': round(small_total, 2),
                'top_merchants': [{'name': m, 'count': c} for m, c in small_merchants.most_common(5)],
                'avg_per_month': round(len(small_txs) / num_months, 1),
            })

        # --- 习惯5: 周末消费型 ---
        weekend_txs = []
        weekday_txs_data = []
        for tx in txs:
            dt = _parse_date(tx['date'])
            if dt is None:
                continue
            if dt.weekday() >= 5:
                weekend_txs.append(tx)
            else:
                weekday_txs_data.append(tx)
        if len(weekend_txs) >= 3 and len(weekday_txs_data) >= 3:
            weekend_avg = sum(tx['amount'] for tx in weekend_txs) / max(len(weekend_txs), 1)
            weekday_avg = sum(tx['amount'] for tx in weekday_txs_data) / max(len(weekday_txs_data), 1)
            ratio = weekend_avg / max(weekday_avg, 0.01)
            if ratio > 1.3:
                weekend_cats = Counter(_categorize(tx['merchant']) for tx in weekend_txs if tx['merchant'] and tx['merchant'] != 'None')
                habits.append({
                    'type': 'weekend_warrior',
                    'icon': '🎉',
                    'label': '周末消费型人格',
                    'ratio': round(ratio, 1),
                    'weekend_avg': round(weekend_avg, 2),
                    'weekday_avg': round(weekday_avg, 2),
                    'top_weekend_categories': weekend_cats.most_common(5),
                })

        # --- 习惯6: 订阅/周期性消费（增强版） ---
        recurring = self._detect_recurring_enhanced(merchant_stats, txs)
        if recurring['items']:
            habits.append({
                'type': 'recurring_payments',
                'icon': '🔄',
                'label': '数字内容会员',
                'count': recurring['total_count'],
                'monthly_total': recurring['monthly_total'],
                'yearly_total': recurring['yearly_total'],
                'idle_count': recurring['idle_count'],
                'idle_monthly_waste': recurring['idle_monthly_waste'],
                'items': recurring['items'],
            })

        return habits

    def _detect_recurring_enhanced(self, merchant_stats: dict, all_txs: list[dict]) -> dict:
        """增强版周期性消费检测：仅限线上数字内容订阅 + 闲置判定 + 浪费金额计算

        明确排除：滴滴/地铁/公交等出行消费、餐厅/外卖/超市等餐饮零售消费。
        只检测：视频会员、音乐会员、云存储、知识付费、阅读充值、游戏订阅、办公软件。
        """
        recurring_items = []
        now = datetime.now()

        for m, s in merchant_stats.items():
            if s['count'] < 2:
                continue

            # 0) 明确排除：出行/餐饮/零售类商户
            if any(kw in m for kw in NON_SUBSCRIPTION_MERCHANTS):
                continue

            # 1) 仅依赖关键词匹配，不使用金额规律推断
            matched_cat = ''
            for cat_name, kws in SUBSCRIPTION_KEYWORDS.items():
                if any(kw in m for kw in kws):
                    matched_cat = cat_name
                    break

            # 仅限明确的数字内容订阅关键词
            is_subscription = any(kw in m for kw in [
                '会员', '订阅', '自动续', '月卡', '年卡', '季卡', 'VIP', 'SVIP',
            ])

            if not matched_cat and not is_subscription:
                continue

            # 2) 判断最近使用时间 → 闲置风险分级
            dates_sorted = sorted(s['dates'])
            last_date_str = dates_sorted[-1] if dates_sorted else ''
            last_dt = _parse_date(last_date_str)
            days_since_last = (now - last_dt).days if last_dt else 999

            if days_since_last > 90:
                idle_level = 'high'
                idle_icon = '🔴'
                idle_label = '高度疑似闲置'
            elif days_since_last > 45:
                idle_level = 'medium'
                idle_icon = '🟡'
                idle_label = '可能已闲置'
            else:
                idle_level = 'low'
                idle_icon = '🟢'
                idle_label = '活跃使用中'

            # 3) 计算月均支出
            monthly_cost = round(s['total'] / max(s['count'], 1), 2)
            yearly_cost = round(monthly_cost * 12, 2)

            recurring_items.append({
                'name': m,
                'category': matched_cat or '数字内容订阅',
                'count': s['count'],
                'total': round(s['total'], 2),
                'monthly_cost': monthly_cost,
                'yearly_cost': yearly_cost,
                'last_date': last_date_str,
                'days_since_last': days_since_last,
                'idle_level': idle_level,
                'idle_icon': idle_icon,
                'idle_label': idle_label,
            })

        recurring_items.sort(key=lambda x: (0 if x['idle_level'] == 'high' else 1 if x['idle_level'] == 'medium' else 2, -x['yearly_cost']))

        idle_items = [i for i in recurring_items if i['idle_level'] in ('high', 'medium')]
        all_items = recurring_items[:15]

        total_monthly = round(sum(i['monthly_cost'] for i in all_items), 2)
        total_yearly = round(total_monthly * 12, 2)
        idle_monthly = round(sum(i['monthly_cost'] for i in idle_items), 2)
        idle_yearly = round(idle_monthly * 12, 2)

        return {
            'items': all_items,
            'total_count': len(all_items),
            'monthly_total': total_monthly,
            'yearly_total': total_yearly,
            'idle_items': idle_items,
            'idle_count': len(idle_items),
            'idle_monthly_waste': idle_monthly,
            'idle_yearly_waste': idle_yearly,
        }

    # ==================================================================
    #  生活圈分析
    # ==================================================================
    def _analyze_life_circle(self, txs: list[dict], branches: list[str]) -> dict:
        offline_merchants = {}
        for tx in txs:
            m = tx['merchant']
            if not m or m == 'None' or len(m) <= 2:
                continue
            if _is_online(m) or _is_person_name(m):
                continue
            if m not in offline_merchants:
                offline_merchants[m] = {'count': 0, 'total': 0.0, 'category': _categorize(m)}
            offline_merchants[m]['count'] += 1
            offline_merchants[m]['total'] += tx['amount']

        home_hints = []
        for b in branches:
            if '支行' in b:
                home_hints.append(b.replace('支行', '').replace('北京', '').strip())

        location_keywords = [
            '望京', '朝阳', '海淀', '中关村', '西二旗', '国贸', '三里屯',
            '亚运村', '安贞', '东城', '西城', '丰台', '石景山', '通州',
            '大兴', '昌平', '顺义', '亦庄', '上地', '五道口', '酒仙桥',
            '大望路', '双井', '劲松', '潘家园', '十里堡', '常营', '天通苑',
            '回龙观', '立水桥', '北苑', '来广营', '太阳宫', '亮马桥',
        ]
        location_hits = Counter()
        for m in offline_merchants:
            for loc in location_keywords:
                if loc in m:
                    location_hits[loc] += offline_merchants[m]['count']

        by_category = defaultdict(list)
        for m, s in offline_merchants.items():
            by_category[s['category']].append({
                'name': m, 'count': s['count'], 'total': round(s['total'], 2),
            })

        favorite_merchants = {}
        for cat, items in by_category.items():
            items.sort(key=lambda x: (x['count'], x['total']), reverse=True)
            favorite_merchants[cat] = items[:5]

        all_ranked = sorted(
            [{'name': m, **s} for m, s in offline_merchants.items()],
            key=lambda x: (x['count'], x['total']), reverse=True,
        )[:30]

        total_offline = sum(s['count'] for s in offline_merchants.values())
        top5_count = sum(x['count'] for x in all_ranked[:5])
        top10_ratio = sum(x['count'] for x in all_ranked[:10]) / max(total_offline, 1)

        # 推断居住区域
        inferred = (home_hints[0] if home_hints
                    else (location_hits.most_common(1)[0][0] if location_hits else '未知'))

        # 生活圈半径内的商户（与居住区域相关的商户）
        nearby_merchants = []
        for m, s in offline_merchants.items():
            if inferred != '未知' and inferred in m:
                nearby_merchants.append({'name': m, 'count': s['count'], 'total': round(s['total'], 2), 'category': s['category']})
        nearby_merchants.sort(key=lambda x: x['count'], reverse=True)

        return {
            'home_area_inference': {
                'branches': home_hints,
                'location_hits': dict(location_hits.most_common(5)),
                'inferred_area': inferred,
            },
            'favorite_merchants_by_category': favorite_merchants,
            'top_all_merchants': [{'name': x['name'], 'count': x['count'], 'total': x['total'], 'category': x['category']} for x in all_ranked],
            'nearby_merchants': nearby_merchants[:15],
            'concentration': '高度集中' if top10_ratio > 0.6 else ('较为集中' if top10_ratio > 0.35 else '较为分散'),
            'concentration_pct': round(top10_ratio * 100, 0),
            'offline_total': len(offline_merchants),
        }

    # ==================================================================
    #  TOP 洞察
    # ==================================================================
    def _top_insights(self, txs: list[dict]) -> dict:
        merchant_amounts = defaultdict(float)
        merchant_counts = defaultdict(int)
        for tx in txs:
            m = tx['merchant']
            if not m or m == 'None':
                continue
            merchant_amounts[m] += tx['amount']
            merchant_counts[m] += 1

        top_by_amount = sorted(merchant_amounts.items(), key=lambda x: x[1], reverse=True)[:10]
        top_by_count = sorted(merchant_counts.items(), key=lambda x: x[1], reverse=True)[:10]

        category_totals = defaultdict(float)
        category_counts = defaultdict(int)
        for tx in txs:
            cat = _categorize(tx['merchant']) if tx['merchant'] and tx['merchant'] != 'None' else '未分类'
            category_totals[cat] += tx['amount']
            category_counts[cat] += 1
        top_categories = sorted(category_totals.items(), key=lambda x: x[1], reverse=True)

        max_tx = max(txs, key=lambda x: x['amount']) if txs else None

        return {
            'top_merchants_by_amount': [{'name': m, 'total': round(v, 2), 'count': merchant_counts[m]} for m, v in top_by_amount],
            'top_merchants_by_count': [{'name': m, 'count': v, 'total': round(merchant_amounts[m], 2)} for m, v in top_by_count],
            'category_breakdown': [{'category': c, 'total': round(v, 2), 'pct': round(v / sum(ct for _, ct in top_categories) * 100, 1), 'count': category_counts[c]} for c, v in top_categories],
            'largest_single': {
                'merchant': max_tx['merchant'] if max_tx else '',
                'amount': round(max_tx['amount'], 2) if max_tx else 0,
                'date': max_tx['date'] if max_tx else '',
            } if max_tx else None,
        }

    # ==================================================================
    #  图表生成（Mermaid + 结构化数据）
    # ==================================================================
    def _build_charts(self, txs: list[dict], time_patterns: dict,
                      life_circle: dict, top_insights: dict, habits: list[dict]) -> dict:
        """生成多种图表，优先使用 Mermaid 语法，辅以结构化数据"""
        chart_list = []

        # ---- 图1: 消费分类饼图 (Mermaid pie) ----
        cats = top_insights.get('category_breakdown', [])
        if cats:
            # 把"其他消费"之外的小类别合并为"其他"
            major_cats = []
            other_total = 0.0
            other_count = 0
            for c in cats:
                if c['pct'] >= 3:
                    major_cats.append(c)
                else:
                    other_total += c['total']
                    other_count += c['count']
            if other_total > 0:
                major_cats.append({'category': '其他', 'total': round(other_total, 2), 'pct': round(other_total / sum(c['total'] for c in cats) * 100, 1), 'count': other_count})

            pie_lines = ['pie showData', '    title 消费分类占比']
            for c in major_cats[:8]:
                label = c['category'].replace('"', '')
                pie_lines.append(f'    "{label}" : {c["total"]:.0f}')
            chart_list.append({
                'id': 'category_pie',
                'title': '📊 消费分类占比',
                'type': 'mermaid',
                'mermaid': '\n'.join(pie_lines),
                'data': major_cats[:8],
            })

        # ---- 图2: 月度消费趋势折线图 (Mermaid xy) ----
        monthly = time_patterns.get('monthly_trend', [])
        if len(monthly) >= 2:
            xy_lines = [
                'xychart-beta',
                '    title "月度消费趋势"',
                '    x-axis ' + str([m['month'][-2:] + '月' for m in monthly]).replace("'", '"'),
                '    y-axis "金额(元)"',
                '    line ' + str([m['total'] for m in monthly]),
            ]
            chart_list.append({
                'id': 'monthly_trend',
                'title': '📈 月度消费趋势',
                'type': 'mermaid',
                'mermaid': '\n'.join(xy_lines),
                'data': monthly,
            })

        # ---- 图3: 周消费分布柱状图 (Mermaid xy bar) ----
        wd = time_patterns.get('weekday_distribution', [])
        if wd:
            bar_lines = [
                'xychart-beta',
                '    title "一周消费分布"',
                '    x-axis ' + str([d['day'] for d in wd]).replace("'", '"'),
                '    y-axis "金额(元)"',
                '    bar ' + str([d['total'] for d in wd]),
            ]
            chart_list.append({
                'id': 'weekday_bar',
                'title': '📅 一周消费分布',
                'type': 'mermaid',
                'mermaid': '\n'.join(bar_lines),
                'data': wd,
            })

        # ---- 图4: 24小时消费热力 (Mermaid timeline/gantt + 数据表) ----
        hour_full = time_patterns.get('hour_full', [])
        if hour_full:
            max_count = max(h['count'] for h in hour_full) or 1
            heatmap_rows = []
            for h in hour_full:
                bar_len = int(h['count'] / max_count * 20)
                bar = '█' * bar_len
                heatmap_rows.append({
                    'hour': f"{h['hour']:02d}:00",
                    'count': h['count'],
                    'total': h['total'],
                    'bar': bar,
                    'label': '🌙' if (h['hour'] >= 22 or h['hour'] < 6) else ('☀️' if 6 <= h['hour'] < 18 else '🌆'),
                })
            chart_list.append({
                'id': 'hour_heatmap',
                'title': '⏰ 24小时消费热力',
                'type': 'heatmap_table',
                'data': heatmap_rows,
            })

        # ---- 图5: 生活圈轨迹流程图 (Mermaid flowchart) ----
        inferred = life_circle.get('home_area_inference', {}).get('inferred_area', '')
        nearby = life_circle.get('nearby_merchants', [])
        favorite = life_circle.get('favorite_merchants_by_category', {})

        if inferred and inferred != '未知' and (nearby or favorite):
            flow_lines = ['graph LR']
            home_id = inferred.replace(' ', '_')
            flow_lines.append(f'    HOME["🏠 {inferred}"]')

            # 分类节点
            cat_colors = {'餐饮美食': '#FF6B6B', '咖啡茶饮': '#C084FC', '超市便利店': '#4ADE80',
                          '商场购物': '#FBBF24', '医疗健康': '#38BDF8', '休闲娱乐': '#F472B6',
                          '交通出行': '#A78BFA', '生活缴费': '#34D399'}

            for cat, items in list(favorite.items())[:5]:
                cat_id = cat.replace(' ', '_')
                top_item = items[0]['name'] if items else ''
                if len(top_item) > 10:
                    top_item = top_item[:8] + '..'
                color = cat_colors.get(cat, '#94A3B8')
                flow_lines.append(f'    HOME -->|{cat}| {cat_id}["{top_item}"]')
                flow_lines.append(f'    style {cat_id} fill:{color},color:#fff')

            flow_lines.append(f'    style HOME fill:#6C4DFF,color:#fff,stroke:#6C4DFF')
            chart_list.append({
                'id': 'life_circle_flow',
                'title': f'🗺️ {inferred}周边生活圈轨迹',
                'type': 'mermaid',
                'mermaid': '\n'.join(flow_lines),
                'data': {'home': inferred, 'nearby_count': len(nearby)},
            })

        # ---- 图6: 数字内容订阅闲置分析 ----
        recurring_habit = next((h for h in habits if h['type'] == 'recurring_payments'), None)
        if recurring_habit and recurring_habit.get('items'):
            items = recurring_habit['items']
            idle_items = [i for i in items if i['idle_level'] in ('high', 'medium')]
            active_items = [i for i in items if i['idle_level'] == 'low']

            idle_monthly = sum(i['monthly_cost'] for i in idle_items)
            active_monthly = sum(i['monthly_cost'] for i in active_items)
            if idle_monthly + active_monthly > 0:
                sub_pie_lines = [
                    'pie showData',
                    '    title 数字会员·闲置月费 vs 活跃月费',
                    f'    "🔴闲置 ¥{idle_monthly:.0f}/月" : {idle_monthly:.0f}',
                    f'    "🟢活跃 ¥{active_monthly:.0f}/月" : {active_monthly:.0f}',
                ]
                chart_list.append({
                    'id': 'subscription_pie',
                    'title': '🔔 数字会员·闲置 vs 活跃',
                    'type': 'mermaid',
                    'mermaid': '\n'.join(sub_pie_lines),
                    'data': {
                        'idle_monthly': round(idle_monthly, 2),
                        'active_monthly': round(active_monthly, 2),
                        'idle_yearly': round(idle_monthly * 12, 2),
                        'idle_items': [{'name': i['name'], 'category': i['category'], 'monthly_cost': i['monthly_cost'], 'days_since_last': i['days_since_last']} for i in idle_items],
                    },
                })

        # ---- 图7: 周末 vs 工作日消费对比 (Mermaid pie) ----
        wk_ratio = time_patterns.get('weekend_ratio', 0)
        if wk_ratio > 0:
            weekend_total = time_patterns.get('weekend_total', 0)
            weekday_total = time_patterns.get('weekday_total', 0)
            if weekend_total + weekday_total > 0:
                comp_pie = [
                    'pie showData',
                    '    title 周末 vs 工作日消费占比',
                    f'    "周末" : {weekend_total:.0f}',
                    f'    "工作日" : {weekday_total:.0f}',
                ]
                chart_list.append({
                    'id': 'weekend_vs_weekday_pie',
                    'title': '🏖️ 周末 vs 工作日消费',
                    'type': 'mermaid',
                    'mermaid': '\n'.join(comp_pie),
                    'data': {'weekend': round(weekend_total, 2), 'weekday': round(weekday_total, 2), 'ratio': wk_ratio},
                })

        return {
            'charts': chart_list,
            'total_charts': len(chart_list),
        }

    # ==================================================================
    #  生成建议
    # ==================================================================
    def _generate_suggestions(self, habits: list[dict], time_patterns: dict,
                              life_circle: dict, top_insights: dict) -> list[dict]:
        suggestions = []

        for h in habits:
            # 咖啡
            if h['type'] == 'coffee_addict':
                yearly = h.get('yearly_estimate', 0)
                suggestions.append({
                    'icon': '☕', 'category': '消费习惯', 'title': '咖啡茶饮支出',
                    'detail': f'日均{h["avg_per_time"]:.0f}元，年约¥{yearly:,.0f}',
                    'action': '自带杯/品牌会员卡可省30%',
                })
            # 外卖
            elif h['type'] == 'takeout_lover':
                suggestions.append({
                    'icon': '🍔', 'category': '饮食健康', 'title': '减少外卖频次',
                    'detail': f'{h["count"]}笔共¥{h["total"]:,.0f}',
                    'action': '每周2次自炊，月省¥200-400',
                })
            # 夜间
            elif h['type'] == 'night_owl':
                suggestions.append({
                    'icon': '🌙', 'category': '作息', 'title': '夜间消费提醒',
                    'detail': f'{h["count"]}笔深夜消费¥{h["total"]:,.0f}',
                    'action': '设置22:00后消费确认提醒',
                })
            # 小额
            elif h['type'] == 'impulse_buyer':
                suggestions.append({
                    'icon': '💳', 'category': '财务', 'title': '拿铁因子',
                    'detail': f'{h["count"]}笔小额共¥{h["total"]:,.0f}，月均{h["avg_per_month"]:.0f}笔',
                    'action': '月底复盘小额消费',
                })
            # 周末
            elif h['type'] == 'weekend_warrior':
                suggestions.append({
                    'icon': '🎉', 'category': '规划', 'title': '周末预算制',
                    'detail': f'周末日均¥{h["weekend_avg"]:,.0f}，{h["ratio"]}x工作日',
                    'action': '提前规划周末活动',
                })
            # 数字内容订阅
            elif h['type'] == 'recurring_payments':
                idle_count = h.get('idle_count', 0)
                idle_waste = h.get('idle_monthly_waste', 0)
                idle_yearly = h.get('idle_yearly_waste', 0) if 'idle_yearly_waste' in h else idle_waste * 12

                # 为每个闲置数字会员生成逐条提醒
                for item in h.get('items', []):
                    if item['idle_level'] in ('high', 'medium'):
                        suggestions.append({
                            'icon': item['idle_icon'],
                            'category': '数字会员闲置',
                            'title': f'{item["idle_icon"]} {item["name"]}',
                            'detail': f'{item["idle_label"]}（{item["days_since_last"]}天未使用），¥{item["monthly_cost"]:.0f}/月 · ¥{item["yearly_cost"]:.0f}/年',
                            'action': '建议核查是否仍需续费',
                        })

                if idle_count > 0:
                    suggestions.append({
                        'icon': '⚠️',
                        'category': '数字会员管理',
                        'title': f'清理{idle_count}项闲置数字会员',
                        'detail': f'取消后月省¥{idle_waste:,.0f}，年省¥{idle_yearly:,.0f}',
                        'action': '在手机设置中检查订阅并取消',
                    })

        # 生活圈建议
        inferred = life_circle.get('home_area_inference', {}).get('inferred_area', '')
        conc = life_circle.get('concentration', '')
        if inferred and conc == '高度集中':
            suggestions.append({
                'icon': '🌍', 'category': '生活', 'title': '拓展生活半径',
                'detail': f'消费集中在{inferred}（{life_circle.get("concentration_pct", 0):.0f}%）',
                'action': '探索城市其他区域',
            })

        # 消费结构建议
        cats = top_insights.get('category_breakdown', [])
        if cats:
            top_cat = cats[0]
            total = sum(c['total'] for c in cats)
            if total > 0 and top_cat['total'] / total > 0.4:
                suggestions.append({
                    'icon': '📊', 'category': '结构', 'title': '消费结构优化',
                    'detail': f'"{top_cat["category"]}"占{top_cat["pct"]:.0f}%',
                    'action': '多元化消费，平衡各品类',
                })

        return suggestions
