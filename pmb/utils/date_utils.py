import calendar
from datetime import date, datetime
from typing import Optional


def parse_date_start(date_str: str) -> Optional[str]:
    """解析日期字符串为起始日期 (YYYY-MM-DD)"""
    if not date_str or not date_str.strip():
        return None
    date_str = date_str.strip()

    # YYYY-MM-DD
    if len(date_str) == 10 and date_str[4] == "-":
        try:
            datetime.strptime(date_str, "%Y-%m-%d")
            return date_str
        except ValueError:
            pass

    # YYYY-MM
    if len(date_str) == 7 and date_str[4] == "-":
        try:
            parts = date_str.split("-")
            y, m = int(parts[0]), int(parts[1])
            return f"{y:04d}-{m:02d}-01"
        except (ValueError, IndexError):
            pass

    # YYYY
    if len(date_str) == 4:
        try:
            int(date_str)
            return f"{date_str}-01-01"
        except ValueError:
            pass

    return None


def parse_date_end(date_str: str) -> Optional[str]:
    """解析日期字符串为结束日期 (YYYY-MM-DD)"""
    if not date_str or not date_str.strip():
        return None
    date_str = date_str.strip()

    # YYYY-MM-DD
    if len(date_str) == 10 and date_str[4] == "-":
        try:
            datetime.strptime(date_str, "%Y-%m-%d")
            return date_str
        except ValueError:
            pass

    # YYYY-MM (取该月最后一天)
    if len(date_str) == 7 and date_str[4] == "-":
        try:
            parts = date_str.split("-")
            y, m = int(parts[0]), int(parts[1])
            last_day = calendar.monthrange(y, m)[1]
            return f"{y:04d}-{m:02d}-{last_day:02d}"
        except (ValueError, IndexError):
            pass

    # YYYY (取12月31日)
    if len(date_str) == 4:
        try:
            int(date_str)
            return f"{date_str}-12-31"
        except ValueError:
            pass

    return None


def date_in_range(date_val: str, date_from: Optional[str], date_to: Optional[str]) -> bool:
    """检查日期是否在范围内。date_val/date_from/date_to 都是 YYYY-MM-DD 字符串"""
    if not date_val:
        return False
    if date_from and date_val < date_from:
        return False
    if date_to and date_val > date_to:
        return False
    return True


def amount_in_range(amount: float, amount_min: Optional[float], amount_max: Optional[float]) -> bool:
    """检查金额是否在范围内"""
    if amount_min is not None and amount < amount_min:
        return False
    if amount_max is not None and amount > amount_max:
        return False
    return True
