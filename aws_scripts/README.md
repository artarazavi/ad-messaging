# Ad Server Control Center
## [Full API Documentation](https://documenter.getpostman.com/view/5379321/SW7T6WKi)
Full API documentation is hosted on Postman at: https://documenter.getpostman.com/view/5379321/SW7T6WKi

## Initiation
```
$ brew install terraform
$ terraform init
$ terraform apply
```
visit for instructions  
[here](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)


## API Paths
- POST `/messages/send`
  - Send a message to an endpoint: 
      ```json
      {
          "sourceId": "A1838s",
          "endpointId": "c12h3s",
          "message": "This is my third test message"
      }
      ```
 - POST `/messages/{messageId}`
    - Get a message by ID
 - POST `/endpoint/{endpointId}/messages`
     - Get messages for a client. By default only new messages
     - OPTIONAL BODY: `{"delivered":false, "new":true}`
        - `delivered`: Get delivered messages
        - `new`: Get new messages
 - POST `/endpoint/register`
    - Register/Update a new client
    - Requires:
        ```json
        {
          "clientId": "c12h3s",
          "alias": "arta",
          "publicKey": "--------PUBLIC KEY---------....."
        }
        ```
 - GET `/endpoint/{endpointId}/checkin`
     - Record a endpoint checkin and return oldest unread message base64 encoded in the `x-msg` header
     
 - GET `/cdn/images/{endpointId}_random.png`
    - Do the same as check in but can also send messages by setting header values
      - `x-msg`: message to send
      - `x-target`: Message target
      
 - GET `/endpoint/{endpointId}`
     - Get info about an endpoint


