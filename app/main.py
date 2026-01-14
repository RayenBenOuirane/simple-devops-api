from contextlib import asynccontextmanager
from datetime import datetime
import json
import logging
import time
import uuid
from typing import Dict, List

from fastapi import FastAPI, HTTPException, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest

from app.models import HealthResponse, ItemCreate, ItemResponse, ItemUpdate

# ============ METRICS ============
REQUEST_COUNT = Counter("http_requests_total", "Total HTTP requests", ["method", "endpoint", "status"])
REQUEST_DURATION = Histogram("http_request_duration_seconds", "HTTP request duration", ["method", "endpoint"])
ERROR_COUNT = Counter("http_errors_total", "Total HTTP errors", ["type"])
ACTIVE_REQUESTS = Gauge("http_requests_active", "Active HTTP requests")
ITEMS_COUNT = Gauge("items_total", "Total number of items")

# ============ LOGGING ============
logging.basicConfig(
    level=logging.INFO,
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "message": %(message)s}',
    datefmt="%Y-%m-%dT%H:%M:%SZ",
)
logger = logging.getLogger(__name__)

# ============ DATABASE ============
items_db: Dict[str, dict] = {}
startup_time = time.time()

# ============ LIFESPAN ============
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(json.dumps({"event": "startup", "message": "Starting API"}))
    
    # Sample data
    samples = [
        {"id": "1", "name": "Laptop", "description": "Gaming laptop", "price": 1299.99},
        {"id": "2", "name": "Mouse", "description": "Wireless mouse", "price": 49.99},
        {"id": "3", "name": "Keyboard", "description": "Mechanical keyboard", "price": 89.99},
    ]
    for item in samples:
        items_db[item["id"]] = {
            **item,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat(),
        }
    ITEMS_COUNT.set(len(items_db))
    yield
    logger.info(json.dumps({"event": "shutdown", "message": "Stopping API"}))

# ============ APP ============
app = FastAPI(title="DevOps API", version="1.0.0", lifespan=lifespan)

# ============ MIDDLEWARE ============
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Request-ID", "X-Response-Time"],
)
app.add_middleware(TrustedHostMiddleware, allowed_hosts=["*"])

@app.middleware("http")
async def observability_middleware(request: Request, call_next):
    request_id = str(uuid.uuid4())
    start_time = time.time()
    ACTIVE_REQUESTS.inc()
    
    logger.info(json.dumps({
        "request_id": request_id,
        "event": "request_start",
        "method": request.method,
        "path": request.url.path,
        "client": request.client.host if request.client else "unknown",
    }))
    
    try:
        response = await call_next(request)
        process_time = time.time() - start_time
        
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code,
        ).inc()
        REQUEST_DURATION.labels(
            method=request.method,
            endpoint=request.url.path,
        ).observe(process_time)
        
        logger.info(json.dumps({
            "request_id": request_id,
            "event": "request_complete",
            "method": request.method,
            "path": request.url.path,
            "status": response.status_code,
            "duration_ms": round(process_time * 1000, 2),
        }))
        
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Response-Time"] = f"{process_time:.4f}"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        
        return response
        
    except Exception as exc:
        process_time = time.time() - start_time
        ERROR_COUNT.labels(type=type(exc).__name__).inc()
        logger.error(json.dumps({
            "request_id": request_id,
            "event": "error",
            "error": str(exc),
            "error_type": type(exc).__name__,
            "path": request.url.path,
        }))
        raise
    finally:
        ACTIVE_REQUESTS.dec()

# ============ ENDPOINTS ============
@app.get("/", response_model=dict)
async def root():
    return {
        "service": "DevOps Backend API",
        "version": "1.0.0",
        "status": "operational",
        "endpoints": ["/", "/health", "/metrics", "/items", "/items/{id}"],
        "docs": "/docs",
    }

@app.get("/health", response_model=HealthResponse)
async def health():
    return HealthResponse(
        status="healthy",
        version="1.0.0",
        timestamp=time.time(),
        uptime=round(time.time() - startup_time, 2),
    )

@app.get("/metrics", response_class=Response)
async def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/items", response_model=List[ItemResponse])
async def list_items():
    return [ItemResponse(**item) for item in items_db.values()]

@app.get("/items/{item_id}", response_model=ItemResponse)
async def get_item(item_id: str):
    if item_id not in items_db:
        raise HTTPException(status_code=404, detail="Item not found")
    return ItemResponse(**items_db[item_id])

@app.post("/items", response_model=ItemResponse, status_code=201)
async def create_item(item: ItemCreate):
    item_id = str(uuid.uuid4())
    new_item = {
        "id": item_id,
        "name": item.name,
        "description": item.description,
        "price": item.price,
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat(),
    }
    items_db[item_id] = new_item
    ITEMS_COUNT.inc()
    
    logger.info(json.dumps({
        "event": "item_created",
        "item_id": item_id,
        "name": item.name,
        "price": item.price,
    }))
    
    return ItemResponse(**new_item)

@app.put("/items/{item_id}", response_model=ItemResponse)
async def update_item(item_id: str, item: ItemUpdate):
    if item_id not in items_db:
        raise HTTPException(status_code=404, detail="Item not found")
    
    current = items_db[item_id]
    updated_item = {
        "id": item_id,
        "name": item.name if item.name is not None else current["name"],
        "description": item.description if item.description is not None else current["description"],
        "price": item.price if item.price is not None else current["price"],
        "created_at": current["created_at"],
        "updated_at": datetime.now().isoformat(),
    }
    items_db[item_id] = updated_item
    
    logger.info(json.dumps({
        "event": "item_updated",
        "item_id": item_id,
        "name": updated_item["name"],
    }))
    
    return ItemResponse(**updated_item)

@app.delete("/items/{item_id}", status_code=204)
async def delete_item(item_id: str):
    if item_id not in items_db:
        raise HTTPException(status_code=404, detail="Item not found")
    
    del items_db[item_id]
    ITEMS_COUNT.dec()
    
    logger.info(json.dumps({
        "event": "item_deleted",
        "item_id": item_id,
    }))

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    request_id = request.headers.get("X-Request-ID", "unknown")
    ERROR_COUNT.labels(type=type(exc).__name__).inc()
    
    logger.error(json.dumps({
        "request_id": request_id,
        "event": "unhandled_error",
        "error": str(exc),
        "type": type(exc).__name__,
        "path": request.url.path,
    }))
    
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "request_id": request_id,
            "detail": "An unexpected error occurred"
        }
    )