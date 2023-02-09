#!/bin/bash
echo "Starting application on port $1"
python3 -m flask run --host=0.0.0.0 --port=$1
