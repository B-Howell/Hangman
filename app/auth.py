from flask import Blueprint, request, session, flash, redirect, url_for
from werkzeug.security import generate_password_hash, check_password_hash
from flask_mysqldb import MySQL
import MySQLdb.cursors

auth = Blueprint('auth', __name__)

def handle_login(cur):
    username = request.form.get('username')
    password = request.form.get('password')
    
    cur.execute("SELECT * FROM users WHERE username = %s", (username,))
    user = cur.fetchone()

    if user and check_password_hash(user['password'], password):
        session['user_id'] = user['user_id']
        session['username'] = username 
    else:
        flash("Login failed", 'error')

@auth.route('/login', methods=['POST'])
def login():
    mysql = MySQL()
    conn = mysql.connection
    cur = conn.cursor(MySQLdb.cursors.DictCursor)
    handle_login(cur)
    cur.close()
    return redirect(request.referrer or url_for('base'))

def handle_register(cur, conn):
    username = request.form.get('new_username')
    cur.execute("SELECT * FROM users WHERE username = %s", (username,))
    existing_user = cur.fetchone()

    if existing_user:
        flash('Username already taken. Please choose another.', 'error')
    else:
        password = generate_password_hash(request.form.get('new_password'))
        cur.execute("INSERT INTO users (user_id, username, password, provider) VALUES (%s, %s, %s, %s)", (None, username, password, 'manual'))
        conn.commit()
        user_id = cur.lastrowid
        cur.execute("INSERT INTO stats (user_id, wins, losses, win_loss_ratio, current_win_streak, longest_win_streak) VALUES (%s, 0, 0, 0.0, 0, 0)", (user_id,))
        conn.commit()
        session['user_id'] = user_id

@auth.route('/register', methods=['POST'])
def register():
    mysql = MySQL()
    conn = mysql.connection
    cur = conn.cursor(MySQLdb.cursors.DictCursor)
    handle_register(cur, conn)
    cur.close()
    return redirect(request.referrer or url_for('base'))

@auth.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('base'))
