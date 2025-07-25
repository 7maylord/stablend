import json
import sys
import tensorflow as tf
import numpy as np

# Load pre-trained TensorFlow model
model = tf.keras.models.load_model('rate_model.h5')

def predict_rate(market_data):
    """
    Predicts user-specific interest rate based on market data.
    
    Args:
        market_data (dict): JSON input with keys:
            - utilization (float): Pool utilization percentage
            - credit_score (float): User credit score (0-1000)
            - mnt_price (float): MNT/USD price from Chainlink
    
    Returns:
        int: Predicted interest rate in basis points (e.g., 500 = 5%)
    """
    try:
        # Extract features
        utilization = float(market_data['utilization'])
        credit_score = float(market_data['credit_score'])
        mnt_price = float(market_data['mnt_price'])
        
        # Normalize inputs (based on training assumptions)
        utilization_norm = utilization / 100.0  # 0-100% to 0-1
        credit_score_norm = credit_score / 1000.0  # 0-1000 to 0-1
        mnt_price_norm = mnt_price / 10.0  # Scale price (assuming max $10)
        
        # Prepare input array
        input_data = np.array([[utilization_norm, credit_score_norm, mnt_price_norm]])
        
        # Predict rate
        predicted_rate = model.predict(input_data)[0][0]
        
        # Convert to basis points and cap
        rate_bp = int(predicted_rate * 10000)  # Scale to basis points
        rate_bp = min(max(rate_bp, 100), 5000)  # Cap between 1% and 50%
        
        return rate_bp
    
    except Exception as e:
        print(f"Error predicting rate: {e}", file=sys.stderr)
        return 500  # Fallback 5% rate

if __name__ == "__main__":
    # Read JSON input from command line (passed by updateRates.ts)
    if len(sys.argv) != 2:
        print("Usage: python rateModel.py '<json_data>'", file=sys.stderr)
        sys.exit(1)
    
    try:
        market_data = json.loads(sys.argv[1])
        rate = predict_rate(market_data)
        print(rate)  # Output rate in basis points
    except json.JSONDecodeError as e:
        print(f"Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)
