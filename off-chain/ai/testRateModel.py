import json
import pytest
from offchain.ai.rateModel import predict_rate

def test_predict_rate():
    # Test case: typical input
    data = {"utilization": 50, "credit_score": 800, "mnt_price": 0.8}
    rate = predict_rate(data)
    assert isinstance(rate, int), "Rate should be an integer"
    assert 100 <= rate <= 5000, "Rate out of valid range"

    # Test case: edge case (high utilization, low credit)
    data = {"utilization": 90, "credit_score": 400, "mnt_price": 1.2}
    rate = predict_rate(data)
    assert rate >= 500, "Rate should be higher for risky profile"

    # Test case: invalid input
    data = {"utilization": -10, "credit_score": 800, "mnt_price": 0.8}
    rate = predict_rate(data)
    assert rate == 500, "Should return fallback rate on error"

if __name__ == "__main__":
    pytest.main(["-v"])
