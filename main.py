import os
import time
from fastapi import FastAPI, Request, HTTPException
from openai import OpenAI
from sqlalchemy import create_engine, text
import json
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

client = OpenAI(
    api_key=os.getenv("OPENAI_API_KEY")
)

engine = create_engine(
    os.getenv("MYSQL_DSN"),
    pool_pre_ping=True,
    pool_recycle=3600
)


def get_client_ip(request: Request) -> str:
    """Resolve client IP behind nginx / reverse proxy."""
    forwarded_for = request.headers.get("x-forwarded-for")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()

    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip.strip()

    if request.client:
        return request.client.host

    return "unknown"


@app.post("/v1/chat")
async def chat(request: Request):
    start_time = time.time()

    request_ip = get_client_ip(request)
    body = await request.json()

    model = body.get("model", "gpt-4.1-mini")
    user_input = body.get("input")

    if not user_input:
        raise HTTPException(status_code=400, detail="input is required")

    response_body = None
    error_message = None
    success = 1

    try:
        response = client.responses.create(
            model=model,
            input=user_input
        )

        response_body = response.model_dump()

        usage = response_body.get("usage") or {}

        result = {
            "id": response_body.get("id"),
            "model": model,
            "text": response.output_text,
            "usage": usage
        }

        return result

    except Exception as e:
        success = 0
        error_message = str(e)
        raise HTTPException(status_code=500, detail=error_message)

    finally:
        duration_ms = int((time.time() - start_time) * 1000)

        try:
            with engine.begin() as conn:
                conn.execute(
                    text("""
                        INSERT INTO ai_request_logs (
                            request_ip,
                            model,
                            request_body,
                            response_body,
                            prompt_tokens,
                            completion_tokens,
                            total_tokens,
                            duration_ms,
                            success,
                            error_message
                        ) VALUES (
                            :request_ip,
                            :model,
                            CAST(:request_body AS JSON),
                            CAST(:response_body AS JSON),
                            :prompt_tokens,
                            :completion_tokens,
                            :total_tokens,
                            :duration_ms,
                            :success,
                            :error_message
                        )
                    """),
                    {
                        "request_ip": request_ip,
                        "model": model,
                        "request_body": json.dumps(body, ensure_ascii=False),
                        "response_body": json.dumps(response_body, ensure_ascii=False) if response_body else None,
                        "prompt_tokens": usage.get("input_tokens", 0) if response_body else 0,
                        "completion_tokens": usage.get("output_tokens", 0) if response_body else 0,
                        "total_tokens": usage.get("total_tokens", 0) if response_body else 0,
                        "duration_ms": duration_ms,
                        "success": success,
                        "error_message": error_message
                    }
                )
        except Exception as log_error:
            print("log insert error:", log_error)