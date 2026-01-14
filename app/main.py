from contextlib import asynccontextmanager
from datetime import datetime
import json
import logging
import time
import uuid
from typing import Dict, List

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware  # ← AJOUTÉ
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest
from pydantic import BaseModel

# ============ MODELS ============
class ItemBase(BaseModel):
    name: str
    description: str = ""
    price: float

class ItemCreate(ItemBase):
    pass

class ItemResponse(ItemBase):
    id: str
    created_at: str
    updated_at: str

class HealthResponse(BaseModel):
    status: str
    timestamp: float
    uptime: float

# ============ METRICS ============
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"]
)
REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"]
)
ERROR_COUNT = Counter("http_errors_total", "Total HTTP errors", ["type"])
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
    """Handle startup and shutdown events"""
    # Startup
    logger.info(json.dumps({"event": "startup", "message": "Starting DevOps API"}))
    
    # Add sample data
    sample_items = [
        {"id": "1", "name": "Laptop", "description": "Gaming laptop", "price": 1299.99},
        {"id": "2", "name": "Mouse", "description": "Wireless mouse", "price": 49.99},
        {"id": "3", "name": "Keyboard", "description": "Mechanical keyboard", "price": 89.99},
    ]
    for item in sample_items:
        items_db[item["id"]] = {
            **item,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat(),
        }
    ITEMS_COUNT.set(len(items_db))
    
    yield
    
    # Shutdown
    logger.info(json.dumps({"event": "shutdown", "message": "Stopping DevOps API"}))

# ============ FASTAPI APP ============
app = FastAPI(
    title="DevOps Backend API",
    version="1.0.0",
    lifespan=lifespan,
)

# ============ MIDDLEWARE ============
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# AJOUTÉ: TrustedHost middleware pour la sécurité
# Note: Disabled in K8s as it blocks pod IPs - use Ingress/NetworkPolicy instead
# app.add_middleware(
#     TrustedHostMiddleware,
#     allowed_hosts=["localhost", "127.0.0.1", "0.0.0.0"]  # Restreindre en production
# )

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    """Middleware for metrics, logging, and security"""
    start_time = time.time()
    request_id = str(uuid.uuid4())
    
    # Log request
    logger.info(json.dumps({
        "request_id": request_id,
        "event": "request_start",
        "method": request.method,
        "path": request.url.path,
    }))
    
    try:
        response = await call_next(request)
        process_time = time.time() - start_time
        
        # Record metrics
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code,
        ).inc()
        
        REQUEST_DURATION.labels(
            method=request.method,
            endpoint=request.url.path,
        ).observe(process_time)
        
        # Log response
        logger.info(json.dumps({
            "request_id": request_id,
            "event": "request_complete",
            "method": request.method,
            "path": request.url.path,
            "status": response.status_code,
            "duration_ms": round(process_time * 1000, 2),
        }))
        
        # Add tracing headers
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Response-Time"] = f"{process_time:.3f}"
        
        # ============ SECURITY HEADERS ============
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "geolocation=(), microphone=()"
        # =========================================
        
        return response
        
    except Exception as e:
        process_time = time.time() - start_time
        ERROR_COUNT.labels(type=type(e).__name__).inc()
        
        logger.error(json.dumps({
            "request_id": request_id,
            "event": "error",
            "error": str(e),
            "type": type(e).__name__,
        }))
        
        raise

# ============ HEALTH & METRICS ENDPOINTS ============
@app.get("/", tags=["health"])
async def root():
    return {
        "service": "DevOps Backend API",
        "version": "1.0.0",
        "status": "healthy",
        "endpoints": {
            "root": "GET /",
            "health": "GET /health",
            "metrics": "GET /metrics",
            "docs": "GET /docs",
            "items": "GET /items, POST /items, GET /items/{id}, PUT /items/{id}, DELETE /items/{id}"
        }
    }

@app.get("/health", response_model=HealthResponse, tags=["health"])
async def health():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        timestamp=time.time(),
        uptime=round(time.time() - startup_time, 2),
    )

@app.get("/metrics", tags=["observability"])
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST,
    )

# ============ ITEMS CRUD ============
@app.get("/items", response_model=List[ItemResponse], tags=["items"])
async def list_items():
    """Get all items"""
    return [ItemResponse(**item) for item in items_db.values()]

@app.get("/items/{item_id}", response_model=ItemResponse, tags=["items"])
async def get_item(item_id: str):
    """Get item by ID"""
    if item_id not in items_db:
        raise HTTPException(status_code=404, detail="Item not found")
    return ItemResponse(**items_db[item_id])

@app.post("/items", response_model=ItemResponse, status_code=201, tags=["items"])
async def create_item(item: ItemCreate):
    """Create a new item"""
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
    }))
    
    return ItemResponse(**new_item)

@app.put("/items/{item_id}", response_model=ItemResponse, tags=["items"])
async def update_item(item_id: str, item: ItemCreate):
    """Update an existing item"""
    if item_id not in items_db:
        raise HTTPException(status_code=404, detail="Item not found")
    
    updated_item = {
        "id": item_id,
        "name": item.name,
        "description": item.description,
        "price": item.price,
        "created_at": items_db[item_id]["created_at"],
        "updated_at": datetime.now().isoformat(),
    }
    items_db[item_id] = updated_item
    
    logger.info(json.dumps({
        "event": "item_updated",
        "item_id": item_id,
    }))
    
    return ItemResponse(**updated_item)

@app.delete("/items/{item_id}", status_code=204, tags=["items"])
async def delete_item(item_id: str):
    """Delete an item"""
    if item_id not in items_db:
        raise HTTPException(status_code=404, detail="Item not found")
    
    del items_db[item_id]
    ITEMS_COUNT.dec()
    
    logger.info(json.dumps({
        "event": "item_deleted",
        "item_id": item_id,
    }))