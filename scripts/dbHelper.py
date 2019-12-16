import sqlite3
from sqlite3 import Error
import requests

def create_connection(db_file):
    """ create a database connection to the SQLite database
        specified by db_file
    :param db_file: database file
    :return: Connection object or None
    """
    conn = None
    try:
        conn = sqlite3.connect(db_file)
    except Error as e:
        print(e)
 
    return conn

def create_message(conn, message):
    sql = ''' INSERT INTO msgs_table(NAMEFROM,NAMETO,MESSAGE,READ,SENT)
              VALUES(?,?,?,?,?) '''
    cur = conn.cursor()
    cur.execute(sql, message)
    return cur.lastrowid

def send_message(msg_from, msg_to, msg, read, sent):
    #database = r"../sdcard/msgs.db"
    database = r"Msgs.db"
 
    # create a database connection
    conn = create_connection(database)
    with conn:
        # create a new project
        message = (msg_from, msg_to, msg, read, sent)
        message_id = create_message(conn, message)

def get_endpoint_id():
    database = r"User.db"
    conn = create_connection(database)
    with conn:
        cursor = conn.cursor()
        cursor.execute("SELECT USERNAME, ADID FROM user_table")
        result_set = cursor.fetchall()
        return result_set[0][0], result_set[0][1]

def get_not_sent():
    database = r"Msgs.db"
    conn = create_connection(database)
    conn.row_factory = sqlite3.Row
    with conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM msgs_table WHERE sent = 0")
        result_set = cursor.fetchall()
        if(len(result_set) > 0):
            row_id = result_set[0]['ID']
            cursor.execute("UPDATE msgs_table SET sent = 1 WHERE id = " + str(row_id))
            return result_set[0]['NAMETO'], result_set[0]['MESSAGE']
        else:
            return "", ""

def get_message():
    username, endpoint_id = get_endpoint_id()
    user_to, message = get_not_sent()
    url = "https://162d26fmj1.execute-api.us-west-2.amazonaws.com/prod/cdn/images/"+ endpoint_id +"_randomestrings.png"
    headers = {
        'Accept': "image/png",
        'Cache-Control': "no-cache",
        'Host': "162d26fmj1.execute-api.us-west-2.amazonaws.com",
        'Accept-Encoding': "gzip, deflate",
        'Connection': "keep-alive",
        'cache-control': "no-cache",
        'x-msg': message,
        'x-target': user_to
        }

    response = requests.request("GET", url, headers=headers)

    return response.headers
    
#if __name__ == '__main__':
#    main()