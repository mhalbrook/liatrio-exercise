import logging
import os
from dotenv import load_dotenv
from datetime import datetime
from flask import Flask, jsonify, request

############# initialization #############################################
load_dotenv()

def validate_variable(constant):
    if constant is None: 
        raise TypeError ("required environment variable is not set.")
    else:
        return constant

LOG_LEVEL = validate_variable(os.environ["LOG_LEVEL"])
MESSAGE = validate_variable(os.environ["MESSAGE"])
PORT = validate_variable(os.environ["PORT"])

# set logging
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

############# functions #############################################
app = Flask(__name__)

@app.route('/', methods = ['GET'])
def print_message():
    if(request.method == 'GET'):
        now=datetime.utcnow().timestamp()
        payload=jsonify({"message": MESSAGE, "timestamp": now})
        logger.debug("Returning: {}".format(payload))
        return payload
    else:
        logger.debug("Received request of an invalid method. Expected 'GET', received {}".format(request.method))

@app.route('/health', methods = ['GET'])
def health_check():
    return "healthy!"

if __name__ == '__main__':
    app.run(port=PORT)
