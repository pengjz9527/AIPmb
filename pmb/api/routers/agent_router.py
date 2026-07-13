from fastapi import APIRouter
from pmb.api.schemas.common import ApiResponse
from pmb.api.schemas.agent import AgentInfo
from pmb.agents.registry import agent_registry

router = APIRouter()


@router.get("/agents", summary="列出所有智能体")
async def list_agents():
    agents = agent_registry.list_agents()
    return ApiResponse(data=[a.model_dump() for a in agents])


@router.post("/agents/{agent_id}/analyze", summary="调用智能体深度分析")
async def analyze_with_agent(agent_id: str):
    agent = agent_registry.get_agent(agent_id)
    if agent is None:
        return ApiResponse(code=404, message=f"智能体 {agent_id} 不存在")

    from pmb.agents.base import AgentContext
    context = AgentContext(
        session_id=f"analyze-{agent_id}",
        user_message=f"请为我进行{agent.name}分析",
        conversation_history=[],
    )

    try:
        result = await agent.analyze(context)
        return ApiResponse(data=result.model_dump())
    except Exception as e:
        return ApiResponse(code=500, message=f"分析出错: {str(e)}")


@router.get("/agents/{agent_id}/status", summary="获取智能体状态")
async def get_agent_status(agent_id: str):
    agent = agent_registry.get_agent(agent_id)
    if agent is None:
        return ApiResponse(code=404, message=f"智能体 {agent_id} 不存在")
    return ApiResponse(data={"agent_id": agent_id, "name": agent.name, "status": "available"})
