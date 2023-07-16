from flask import Blueprint, request, session, redirect, url_for, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from flask_mysqldb import MySQL
import MySQLdb.cursors

auth = Blueprint('auth', __name__)

def handle_login(cur):
    username = request.form.get('username')
    password = request.form.get('password')
    
    cur.execute("SELECT * FROM users WHERE username = %s", (username,))
    user = cur.fetchone()

    if user:
        if check_password_hash(user['password'], password):
            session['user_id'] = user['user_id']
            session['username'] = username
            return None
        else:
            return "Incorrect password"
    else:
        return "Username does not exist"

@auth.route('/login', methods=['POST'])
def login():
    mysql = MySQL()
    conn = mysql.connection
    cur = conn.cursor(MySQLdb.cursors.DictCursor)
    error = handle_login(cur)
    cur.close()
    if error:
        return jsonify({'error': error})
    else:
        return redirect(request.referrer or url_for('base'))

def handle_register(cur, conn):
    username = request.form.get('new_username')
    cur.execute("SELECT * FROM users WHERE username = %s", (username,))
    existing_user = cur.fetchone()

    if existing_user:
        return 'Username already taken. Please choose another.'
    else:
        password = request.form.get('new_password')
        if len(password) < 8:  # Password should be at least 8 characters
            return 'Password is not long enough. It must be at least 8 characters.'
        elif len(password) > 25:  # Password should not exceed 25 characters
            return 'Password is too long. It must not exceed 25 characters.'

        password = generate_password_hash(password)
        cur.execute("INSERT INTO users (user_id, username, password, provider) VALUES (%s, %s, %s, %s)", (None, username, password, 'manual'))
        conn.commit()
        user_id = cur.lastrowid
        cur.execute("INSERT INTO stats (user_id, wins, losses, win_loss_ratio, current_win_streak, longest_win_streak) VALUES (%s, 0, 0, 0.0, 0, 0)", (user_id,))
        conn.commit()
        session['user_id'] = user_id
        return None

@auth.route('/register', methods=['POST'])
def register():
    mysql = MySQL()
    conn = mysql.connection
    cur = conn.cursor(MySQLdb.cursors.DictCursor)
    error = handle_register(cur, conn)
    cur.close()
    if error:
        return jsonify({'error': error})
    else:
        return redirect(request.referrer or url_for('base'))

@auth.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('base'))
