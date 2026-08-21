# backend/app.py
from fastapi import FastAPI
from routers import dashboard, inventory, analytics

app = FastAPI(title="Warehouse Analytics API", version="1.0")

app.include_router(dashboard.router, prefix="/dashboard", tags=["dashboard"])
app.include_router(inventory.router, prefix="/inventory", tags=["inventory"])
app.include_router(analytics.router, prefix="/analytics", tags=["analytics"])

@app.get("/")
def health():
    return {"status": "ok"}