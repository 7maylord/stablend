import tensorflow as tf
import numpy as np
import pandas as pd

# Load sample market data
data = pd.read_json('../data/marketData.json')

# Prepare features and labels
X = data[['utilization', 'credit_score', 'mnt_price']].values
y = data['rate'].values / 10000  # Convert basis points to decimal

# Normalize features
X[:, 0] = X[:, 0] / 100.0  # Utilization: 0-100% to 0-1
X[:, 1] = X[:, 1] / 1000.0  # Credit score: 0-1000 to 0-1
X[:, 2] = X[:, 2] / 10.0  # MNT price: scale by max $10

# Define simple neural network
model = tf.keras.Sequential([
    tf.keras.layers.Dense(64, activation='relu', input_shape=(3,)),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dense(1, activation='sigmoid')
])

# Compile model
model.compile(optimizer='adam', loss='mse')

# Train model
model.fit(X, y, epochs=100, batch_size=32, verbose=1)

# Save model
model.save('rate_model.h5')

print("Model trained and saved as rate_model.h5")
