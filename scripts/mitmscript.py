from mitmproxy import ctx
import json
import os.path
import re
#import requests
import urllib.request
from io import BytesIO
import base64
import dbHelper as db
import base64
import json

class Counter:
    def __init__(self):
        self.num = 0

    
    def response(self, flow):
        
        self.num = self.num + 1
        ctx.log.info("We've seen %d flows" % self.num)
        #all_headers = flow.response.headers
        #for key, value in all_headers.items() :
        #    print (key, value)
        contentType = flow.response.headers.get("content-type") 
        if(contentType != None and contentType == "text/html; charset=utf-8"):
            ctx.log.info(contentType)
            content = flow.response.content
            #contentJSON = json.loads(content.decode("utf-8"))
            #this is where you signature packets
            #as example i am signaturing https://www.sunsetgrillpizza.com/ based on an image
            flow.response.content = flow.response.content.replace(b"/images/grilledcheese.jpg", b"https://i.ytimg.com/vi/6kzrFoXNYVg/maxresdefault.jpg")
            ctx.log.info("################################Message################################")
            dbRes = db.get_message()
            msg_str = dbRes.get('x-session-msg')
            if(msg_str != None):
                msg_decoded = base64.b64decode(msg_str).decode('utf-8')
                msg_dict = json.loads(msg_decoded)
                usr_msg = msg_dict.get('message')
                sender = msg_dict.get('sourceId')
                username, endpoint_id = db.get_endpoint_id()
                db.send_message(sender, username , usr_msg, 0, 1)
                ctx.log.info(usr_msg)


addons = [
    Counter()
]
