```python
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict
from handler import predict_rate

app = FastAPI(title="Stablend AI API", description="AI-powered rate prediction for Stablend lending protocol")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for hackathon; restrict in production
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)

# Define request model for /predict
class MarketData(BaseModel):
    utilization: float
    credit_score: float
    mnt_price: float

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "stablend-ai"}

@app.post("/predict")
async def predict(data: MarketData):
    """Predict interest rate endpoint"""
    try:
        # Convert Pydantic model to dict for handler
        market_data = data.dict()
        
        # Validate required fields (handled by Pydantic, but explicit for clarity)
        required_fields = ["utilization", "credit_score", "mnt_price"]
        for field in required_fields:
            if not market_data.get(field):
                raise HTTPException(status_code=400, detail=f"Missing required field: {field}")
        
        # Predict rate using handler
        rate = predict_rate(market_data)
        
        return {
            "rate": rate,
            "rate_percentage": rate / 100,
            "success": True
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")
```