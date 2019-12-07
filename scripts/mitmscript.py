from mitmproxy import ctx
import json
import os.path
import re
#import requests
import urllib.request
from io import BytesIO
import base64
import dbHelper as db

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
            ctx.log.info("this is before test")
            ctx.log.info(content.decode("utf-8"))
            flow.response.content = flow.response.content.replace(b"/images/grilledcheese.jpg", b"https://i.ytimg.com/vi/6kzrFoXNYVg/maxresdefault.jpg")

            #db.send_message('Arta', 'Database', 'Trash', 0)
            #tx.log.info("timestamp")
            #ctx.log.info(flow.metadata)
            
            content = flow.response.content
            ctx.log.info("this is after test")
            ctx.log.info(content.decode("utf-8"))
        if(contentType != None and contentType.startswith("image")):
            ctx.log.info("################################IMAGE################################")
            content = flow.response.headers
            
            for x in content:
                ctx.log.info(x)
                ctx.log.info(flow.response.headers[x])



addons = [
    Counter()
]
