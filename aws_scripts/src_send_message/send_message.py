import boto3
import json
from datetime import datetime
from uuid import uuid4
from base64 import b64encode
import os
from typing import List, NoReturn, Union

from boto3.dynamodb.conditions import Key, And

MESSAGES_TABLE = os.environ.get("MESSAGES_TABLE")
ENDPOINTS_TABLE = os.environ.get("ENDPOINTS_TABLE")

PIXEL = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEX/TQBcNTh/AAAAAXRSTlPM0jRW"
    "/QAAAApJREFUeJxjYgAAAAYAAzY3fKgAAAAASUVORK5CYII="
)


class Message(object):
    def __init__(
        self,
        sourceId,
        endpointId,
        message,
        delivered="",
        deliveredTime=None,
        messageId=None,
        timestamp=None,
        **kwargs,
    ):
        self.source_id = sourceId
        self.endpoint_id = endpointId
        self.message = message
        self._delivered = True if delivered.lower() == "true" else False
        self.delivered_time = float(deliveredTime) if delivered else None
        self._message_id = messageId if messageId is not None else str(uuid4())
        self.timestamp = float(timestamp) if timestamp else datetime.now().timestamp()

    @property
    def delivered(self):
        return self._delivered

    @delivered.setter
    def delivered(self, value):
        if type(value) is not bool:
            raise TypeError("message delivered is not a boolean")
        self._delivered = value

    @property
    def message_id(self):
        return self._message_id

    @property
    def db_obj(self):
        return {
            "sourceId": {"S": self.source_id},
            "endpointId": {"S": self.endpoint_id},
            "messageId": {"S": self.message_id},
            "message": {"S": self.message},
            "timestamp": {"N": str(self.timestamp)},
            "delivered": {"S": str(self.delivered)},
            "deliveredTime": {
                "N": str(self.delivered_time) if self.delivered_time else "-1"
            },
        }

    @property
    def json(self):
        return {
            "sourceId": self.source_id,
            "endpointId": self.endpoint_id,
            "messageId": self.message_id,
            "message": self.message,
            "timestamp": self.timestamp,
            "delivered": self.delivered,
            "deliveredTime": self.delivered_time,
        }


def send_message(message: Message):
    client = boto3.client("dynamodb")
    client.put_item(TableName="AdMessagingMessages", Item=message.db_obj)


def update_endpoint_last_checkin(endpoint_id):
    """Update the endpoint last checkin time.

    Parameters
    ----------
    endpoint_id : str
        endpoint id to be updated

    Returns
    -------

    """
    client = boto3.resource("dynamodb")
    table = client.Table(ENDPOINTS_TABLE)
    r = table.update_item(
        Key={"endpointId": endpoint_id},
        UpdateExpression="set lastCheckin = :now",
        ExpressionAttributeValues={":now": int(datetime.now().timestamp())},
        ReturnValues="NONE",
    )
    print(f"Updating checkin result: {r}")


def mark_message_as_delivered(message: Message):
    """Mark a message as delivered in the db.

    Parameters
    ----------
    message : Message
        the message object representing the message to update

    Returns
    -------
    No Return

    """
    client = boto3.resource("dynamodb")
    table = client.Table(MESSAGES_TABLE)
    r = table.update_item(
        Key={"messageId": message.message_id},
        UpdateExpression="set deliveredTime = :now, delivered = :d",
        ExpressionAttributeValues={
            ":now": int(datetime.now().timestamp()),
            ":d": "True",
        },
        ReturnValues="NONE",
    )
    print(f"Updating message result: {r}")


def get_oldest_unread_message(endpoint_id, mark_delivered=True) -> Union[Message, None]:
    """Get the oldest unread message for an endpoint.

    Parameters
    ----------
    endpoint_id : str
        endpoint to check for messages
    mark_delivered : bool, optional
        make the message as delivered in the message db (default: True)

    Returns
    -------
    Message:
        message object
    """
    client = boto3.resource("dynamodb")
    table = client.Table(MESSAGES_TABLE)
    messages = table.query(
        IndexName="MessagesByEndpointId",
        KeyConditionExpression=Key("endpointId").eq(endpoint_id)
        & Key("delivered").eq("False"),
        ScanIndexForward=False,
        Limit=1,
    )
    msg = [Message(**m) for m in messages.get("Items", [])]  # type: List[Message]

    if len(msg) == 1:
        if mark_delivered:
            mark_message_as_delivered(msg[0])
        return msg[0]
    return None


def get_message_by_message_id(message_id):
    """Get a message by the messageId.

    Parameters
    ----------
    message_id : str
        message id of message to get

    Returns
    -------
    Message:
        the message object

    Raises
    ------
    KeyError:
        KeyError is raised if the message is not found

    """
    client = boto3.resource("dynamodb")
    table = client.Table(MESSAGES_TABLE)

    message = table.query(KeyConditionExpression=Key("messageId").eq(message_id))
    if len(message.get("Items", [])) != 1:
        raise KeyError("messageId:{} not found".format(message_id))
    message = message.get("Items", [])[0]
    message = Message(**message)
    return message


def get_messages_for_an_endpoint(endpoint_id, delivered=None) -> List[Message]:
    """Get messages for an endpoint.

    Parameters
    ----------
    endpoint_id : str
        endpoint id to get messages for
    delivered : book, optional
        filter messages by delivery status (default: None - all messages)

    Returns
    -------

    """
    client = boto3.resource("dynamodb")
    table = client.Table(MESSAGES_TABLE)

    if delivered is not None:
        delivered = str(delivered)
        messages = table.scan(
            IndexName="MessagesByEndpointId",
            FilterExpression=Key("delivered").eq(delivered)
            & Key("endpointId").eq(endpoint_id),
        )
        print(messages)
    else:
        messages = table.query(
            IndexName="MessagesByEndpointId",
            KeyConditionExpression=Key("endpointId").eq(endpoint_id),
        )
        print(messages)

    m = [Message(**m) for m in messages.get("Items", [])]
    return m


def get_messages(message_id=None, endpoint_id=None, source_id=None, delivered=None):
    if message_id:
        return get_message_by_message_id(message_id)
    if endpoint_id:
        return get_messages_for_an_endpoint(endpoint_id, delivered)
    return


def get_messages_by_endpoint_id(
    endpoint_id: str, new: bool = True, delivered: bool = False
):
    if not (delivered and new):
        return []
    show_delivered = delivered
    if new and delivered:
        show_delivered = None
    messages_obj = get_messages(endpoint_id=endpoint_id, delivered=show_delivered)
    messages = [m.json for m in messages_obj]
    return messages


# TODO: Get Client List
# TODO: Get Client Details
# TODO: Get message when requesting image


def get_endpoint_info(endpoint_id):
    """Get endpoint info.

    Parameters
    ----------
    endpoint_id : str
        endpoint id to get info about

    Returns
    -------
    dict:
        endpoint info

    Notes
    -----
    This function does not handle errors
    """
    client = boto3.resource("dynamodb")
    table = client.Table(ENDPOINTS_TABLE)

    endpoint = table.query(
        KeyConditionExpression=Key("endpointId").eq(endpoint_id), Limit=1,
    ).get("Items")[0]
    for k, v in endpoint.items():
        if str(type(v)) == "<class 'decimal.Decimal'>":
            endpoint[k] = int(v)
    return endpoint


def endpoint_checkin_workflow(endpoint_id):
    """Shared workflow for endpoint checkin.

    Parameters
    ----------
    endpoint_id : str
        endpoint to checkin

    Returns
    -------
    dict:
        http response with secret message
    """
    message = get_oldest_unread_message(endpoint_id)
    update_endpoint_last_checkin(endpoint_id)

    if not message:
        return {
            "headers": {"content-type": "image/png",},
            "statusCode": 200,
            "isBase64Encoded": True,
            "body": PIXEL,
        }

    return {
        "headers": {
            "content-type": "image/png",
            "x-session-msg": str(b64encode(json.dumps(message.json).encode()).decode()),
        },
        "statusCode": 200,
        "isBase64Encoded": True,
        "body": PIXEL,
    }


###################################################################################################
###################################################################################################
#
#       LAMBDA HANDLERS
#
###################################################################################################
###################################################################################################


def endpoint_id_checkin(event, context):
    """Endpoint Checkin

    Path
    ----
    /endpoint/{endpointId}/checkin
    """
    endpoint_id = event.get("pathParameters", {}).get("endpointId")
    print("Checking in endpoint")
    return endpoint_checkin_workflow(endpoint_id)


def get_endpoint_handler(event, context):
    """Lambda function to get Endpoint Info

    Path
    ----
    /endpoint/{endpointId}
    """
    endpoint_id = event.get("pathParameters", {}).get("endpointId")

    try:
        endpoint = get_endpoint_info(endpoint_id)
        return {
            "headers": {"content-type": "application/json"},
            "statusCode": 200,
            "body": json.dumps(endpoint),
        }
    except:
        print("error getting endpoint")
        return {
            "headers": {"content-type": "application/json"},
            "statusCode": 404,
            "body": "error getting endpoint",
        }


def get_image_handler(event, context):
    """Get secret message hidden by what seems to be an image

    Path
    ----
    /cdn/images/{endpointId}_randome_text.jpg

    """
    image_name = event.get("pathParameters", {}).get("image")
    endpoint_id = image_name.split("_")[0]
    headers = event.get("headers", {})

    message_to_send = headers.get("x-msg")
    message_target = headers.get("x-target")

    if message_target and message_to_send:
        message = Message(endpoint_id, message_target, message_to_send)
        send_message(message)

    return endpoint_checkin_workflow(endpoint_id)


def register_client(event, context):
    """Register a new client

    Path
    ----
    /endpoint/register
    """
    body = json.loads(event.get("body", "{}"))
    client_id = body.get("endpointId")
    client_public_key = body.get("publicKey")
    client_alias = body.get("alias")

    if client_id is None or client_alias is None or client_public_key is None:
        return {"statusCode": 404}

    client = boto3.client("dynamodb")
    client_object = {
        "endpointId": {"S": client_id},
        "endpointAlias": {"S": client_alias},
        "publicKey": {"S": client_public_key},
        "lastCheckin": {"N": str(int(datetime.now().timestamp()))},
    }
    client.put_item(TableName="AdMessagingEndpoints", Item=client_object)

    return {
        "headers": {"content-type": "application/json"},
        "statusCode": 200,
        "body": json.dumps({"success": True}),
    }


def get_message_by_id(event, context):
    # This can be used for later for the headers
    # print(json.dumps(event, indent=4))
    message_id = event.get("pathParameters", {}).get("messageId")

    if not message_id:
        return {"statusCode": 404}

    message = get_messages(message_id=message_id)

    return {
        "headers": {"content-type": "application/json"},
        "statusCode": 200,
        "body": json.dumps({"success": True, "message": message.json}),
    }


def get_messages_for_endpoint(event, context):
    # This can be used for later for the headers
    # print(json.dumps(event, indent=4))
    endpoint_id = event.get("pathParameters", {}).get("endpointId")
    body = json.loads(event.get("body", {}))
    new = body.get("new", True)
    delivered = body.get("delivered", False)

    if not endpoint_id:
        return {"statusCode": 404}

    messages = get_messages_by_endpoint_id(endpoint_id, new, delivered)

    return {
        "headers": {"content-type": "application/json"},
        "statusCode": 200,
        "body": json.dumps({"success": True, "messages": messages}),
    }


def lambda_handler(event, context):
    body = json.loads(event.get("body", {}))
    message_object = Message(**body)
    send_message(message_object)

    return {
        "headers": {"content-type": "application/json"},
        "statusCode": 200,
        "body": json.dumps({"success": True, "messageId": message_object.message_id}),
    }
