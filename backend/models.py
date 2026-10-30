from typing import Any, Literal

from pydantic import BaseModel, Field


class TaskPayload(BaseModel):
    task_id: str = Field(..., min_length=1)
    title: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    status: str | None = None
    done: bool | None = None
    updated_at: str | None = None

    model_config = {"extra": "allow"}


class TaskUpdatePayload(BaseModel):
    title: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    status: str | None = None
    done: bool | None = None
    updated_at: str | None = None

    model_config = {"extra": "allow"}


class WebSocketEvent(BaseModel):
    event: Literal["ping", "subscribe"]
    data: dict[str, Any] = Field(default_factory=dict)


class BroadcastEvent(BaseModel):
    event: Literal[
        "task_created",
        "task_updated",
        "task_completed",
        "task_deleted",
        "schedule_changed",
    ]
    user_id: str
    data: dict[str, Any]
