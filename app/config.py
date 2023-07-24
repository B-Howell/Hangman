import os

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'p14y-h4ngm4n!')
    MYSQL_HOST = os.getenv('MYSQL_HOST', 'localhost')
    MYSQL_USER = os.getenv('MYSQL_USER', 'root')
    MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD', 'Bh_661399!')
    MYSQL_DB = os.getenv('MYSQL_DB', 'hangman_stats')
    USER_POOL_ID = os.getenv('USER_POOL_ID', 'us-east-1_tCOk1O7gm')
    CLIENT_ID = os.getenv('CLIENT_ID', 'tbbn8p1mjs7ol8207lsi4it7')

'''
import os

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY')
    MYSQL_HOST = os.getenv('MYSQL_HOST')
    MYSQL_USER = os.getenv('MYSQL_USER')
    MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD')
    MYSQL_DB = os.getenv('MYSQL_DB')
    USER_POOL_ID = os.getenv('USER_POOL_ID')
    CLIENT_ID = os.getenv('CLIENT_ID')
'''