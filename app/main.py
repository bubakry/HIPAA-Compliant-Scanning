import os
import time
import uuid
from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.logging_config import configure_logging


SERVICE_NAME = os.getenv("SERVICE_NAME", "hipaa-fastapi")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
APP_DATA_BUCKET = os.getenv("APP_DATA_BUCKET", "unset")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")

configure_logging(LOG_LEVEL)
logger = structlog.get_logger(SERVICE_NAME)


@asynccontextmanager
async def lifespan(_: FastAPI):
    logger.info(
        "service.startup",
        service=SERVICE_NAME,
        app_data_bucket=APP_DATA_BUCKET,
        aws_region=AWS_REGION,
    )
    yield
    logger.info("service.shutdown", service=SERVICE_NAME)


app = FastAPI(
    title="HIPAA FastAPI Sample",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
    lifespan=lifespan,
)


@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(
        request_id=request_id,
        method=request.method,
        path=request.url.path,
        service=SERVICE_NAME,
    )

    start = time.perf_counter()
    try:
        response = await call_next(request)
    except Exception:
        logger.exception("http.request.failed")
        raise

    duration_ms = round((time.perf_counter() - start) * 1000, 2)
    response.headers["x-request-id"] = request_id
    logger.info(
        "http.request.completed",
        status_code=response.status_code,
        duration_ms=duration_ms,
        client_host=request.client.host if request.client else "unknown",
    )
    return response


@app.get("/", response_class=JSONResponse)
async def root():
    return {
        "service": SERVICE_NAME,
        "compliance_profile": "HIPAA",
        "aws_region": AWS_REGION,
        "app_data_bucket": APP_DATA_BUCKET,
        "status": "ok",
    }


@app.get("/health/live", response_class=JSONResponse)
async def liveness():
    return {"status": "alive"}


@app.get("/health/ready", response_class=JSONResponse)
async def readiness():
    return {"status": "ready", "checks": {"logging": "configured", "env": "loaded"}}
