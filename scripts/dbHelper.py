import sqlite3
from sqlite3 import Error

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
    sql = ''' INSERT INTO msgs_table(NAMEFROM,NAMETO,MESSAGE,READ)
              VALUES(?,?,?,?) '''
    cur = conn.cursor()
    cur.execute(sql, message)
    return cur.lastrowid

def send_message(msg_from, msg_to, msg, read):
    #database = r"../sdcard/msgs.db"
    database = r"Msgs.db"
 
    # create a database connection
    conn = create_connection(database)
    with conn:
        # create a new project
        #message = ('Arta', 'Database', 'Trash', 0);
        message = (msg_from, msg_to, msg, read);
        message_id = create_message(conn, message)
 
 
 
#if __name__ == '__main__':
#    main()