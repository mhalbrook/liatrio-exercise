#!/bin/bash
echo "Starting application on port $PORT"
python3 -m flask run --host=0.0.0.0 --port=$PORT
