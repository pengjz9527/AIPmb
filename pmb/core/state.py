"""全局状态管理"""


class GlobalState:
    json_output: bool = False


state = GlobalState()


def should_json(local_json: bool = False) -> bool:
    """判断是否应该输出JSON（全局或局部）"""
    return local_json or state.json_output
