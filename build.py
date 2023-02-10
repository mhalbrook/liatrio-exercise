import logging
import os
from dotenv import load_dotenv
from python_terraform import *
import docker
import botocore
import boto3
import base64
import requests
from optparse import OptionParser
import time

############# initialization #############################################
load_dotenv()

def validate_variable(constant):
    if constant is None: 
        raise TypeError ("required environment variable is not set.")
    else:
        return constant

LOG_LEVEL = "INFO"
REPO_DIR=os.path.dirname(os.path.realpath("README.MD"))
INFRA_DIR=REPO_DIR + "/infrastructure/"
SERVICE_DIR=REPO_DIR + "/service/"
MODULES = ["backend-state", "core/networking/vpc", "core/ecr", "core/clusters", "services/service-a"]
WORKSPACE = "demo-us-east-1"
PROFILE="default"

# set logging
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

# init clients
parser = OptionParser()
boto_cfg = botocore.config.Config(region_name="us-east-1")
ecr = boto3.client("ecr", config=boto_cfg)
elb = boto3.client("elbv2", config=boto_cfg)
tf = Terraform()
docker = docker.APIClient(base_url='unix://var/run/docker.sock')

# parse option
parser.add_option("-a", "--action", dest="action", type="str", default="apply")
(options, args) = parser.parse_args()
ACTION=options.action

# ############# functions #############################################

def manage_module(module, action, backend_config=None):
    retries = 3
    return_code = 1
    os.chdir(INFRA_DIR + module)
    logger.info("Initializing module {}".format(module))
    if backend_config is None: 
        return_code = tf.init_cmd(no_color=IsFlagged,)
        if return_code[0] != 0:
            return_code = tf.init_cmd(no_color=IsFlagged, reconfigure=IsFlagged)
    else:
        return_code = tf.init_cmd(no_color=IsFlagged, backend_config=backend_config)
        if return_code[0] != 0:
            return_code = tf.init_cmd(no_color=IsFlagged, reconfigure=IsFlagged, backend_config=backend_config)
    if return_code[0] != 0:
        return return_code

    workspaces = [v.removesuffix("\n") for v in tf.show_workspace()[1:-1]]
    if WORKSPACE not in workspaces:
        logger.info("Creating workspace: {}".format(WORKSPACE))
        tf.create_workspace(WORKSPACE)
    logger.info("Setting workspace: {}".format(WORKSPACE))
    tf.set_workspace(WORKSPACE)
    while return_code != 0 and retries > 0:
        if action == "apply":
            logger.info("Applying module {}".format(module))
            if backend_config is None:
                return_code, stdout, stderr = tf.apply(no_color=IsFlagged, skip_plan=True, capture_output=True)
            else:
                return_code, stdout, stderr = tf.apply(no_color=IsFlagged, skip_plan=True, capture_output=True, backend_config='backend.hcl')
        elif action == "destroy":
            logger.info("Destroying module {}".format(module))
            if backend_config is None:
                return_code, stdout, stderr = tf.apply(no_color=IsFlagged, skip_plan=True, destroy=IsFlagged, capture_output=True)
            else:
                return_code, stdout, stderr = tf.apply(no_color=IsFlagged, skip_plan=True, destroy=IsFlagged, capture_output=True, backend_config=backend_config)
        if return_code == 0:
            output = tf.output(json=IsFlagged)
            return output
        else:
            retries-=1
            output = stderr 
    return output

    

def create_backend_config(output):
    config = "bucket = " + "\"" + output["bucket_config"]["value"]["bucket"] + "\"\n" + "region = " + "\"" + output["bucket_config"]["value"]["region"] + "\"\n" + "profile = " +  "\"" + PROFILE + "\"\n"
    backend_config=REPO_DIR + "/backend.hcl"
    print(backend_config)
    backend_file = open(backend_config, "w")
    backend_file.write(config)
    backend_file.close
    return backend_config

def get_repository(output):
    repository = output["repository_url"]["value"]["service-a"]
    return repository

def get_endpoint(output):
    endpoint = output["service_url"]["value"]
    logger.info("Fetched service endpoint: {}".format(endpoint))
    return endpoint

def get_elb_status(output):
    name = output["load_balancer_name"]["value"]
    load_balancer = elb.describe_load_balancers(Names=[name])["LoadBalancers"]
    status = [ v["State"]["Code"] for v in load_balancer][0]
    logger.info("Fetched Load Balancer Status: {}".format(status))
    return status

def build_docker(directory, repository, tag, port=8080):
    logger.info("Fetching authentication token for {}".format(repository))
    account = repository[0:12]
    auth = ecr.get_authorization_token(registryIds=[account])["authorizationData"][0]
    token = auth["authorizationToken"]
    registry = auth["proxyEndpoint"]
    username, password = base64.b64decode(token).decode('utf-8').split(':')
    logger.info("Building image: {}".format(repository + ":" + tag))
    build = [line for line in docker.build(
        path=directory, 
        tag=repository + ":" + tag, 
        buildargs={
            "PORT": str(port)
        }
    )]
    logger.info("Authenticating to: {}".format(repository))
    docker.login(registry=registry, username=username, password=password)
    logger.info("Pushing image: {}".format(repository + ":" + tag))
    push = docker.push(repository=repository + ":" + tag)


def test_endpoint(endpoint):
    url = "http://" + endpoint
    logger.info("Testing: {}".format(url))
    response = requests.get(url)
    if response.ok == True:
        logger.info("{} returned 200".format(url))
        response_dict = response.json()
        payload_keys = response_dict.keys()
        if "message" in payload_keys and "timestamp" in payload_keys:
            logger.info("{} returned 'message' and 'timestamp'. Test passed.")
            test_result = True
        else: 
            logger.info("{} did not return 'message' and 'timestamp'. Test failed.")
            test_result = False
    else: 
        logger.info("{} did not return 200'. Test failed.")
        test_result = False
    return test_result


# ############# handler #############################################
for m in MODULES:
    if ACTION == "apply":
        if MODULES.index(m) > 0:
            output = manage_module(m, ACTION)
            if m == "core/ecr":
                repository = get_repository(output)
                build_docker(SERVICE_DIR, repository, "v1.0")
            elif m == "services/service-a":
                endpoint = get_endpoint(output)
                while get_elb_status(output) != "active":
                    time.sleep(30)
                test_endpoint(endpoint)
    elif ACTION == "destroy":
        modules = MODULES.reverse()
        for m in modules:
            if modules.index(m) < len(modules):
                manage_module(m, "destroy")


