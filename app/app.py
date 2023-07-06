from flask import Flask, render_template, request, redirect, url_for, session, flash
from flask_mysqldb import MySQL
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config
import random
import hangman_words
import MySQLdb.cursors

app = Flask(__name__)
app.config.from_object(Config)
mysql = MySQL(app)

class User:
    def __init__(self, id, username, password):
        self.id = id
        self.username = username
        self.password = password

@app.route('/', methods=['GET', 'POST'])
def base():
    if request.method == 'POST':
        conn = mysql.connect
        cur = conn.cursor(MySQLdb.cursors.DictCursor)

        if 'login' in request.form:
            username = request.form.get('username')
            password = request.form.get('password')

            cur.execute("SELECT * FROM users WHERE username = %s", (username,))
            user = cur.fetchone()

            if user and check_password_hash(user['password'], password):
                session['user_id'] = user['user_id']
                session['username'] = username 
            else:
                print("Login failed")

        elif 'register' in request.form:
            username = request.form.get('new_username')
            cur.execute("SELECT * FROM users WHERE username = %s", (username,))
            existing_user = cur.fetchone()

            if existing_user:
                print('User already exists')
                flash('Username already taken. Please choose another.', 'error')
            else:
                password = generate_password_hash(request.form.get('new_password'))
                cur.execute("INSERT INTO users (user_id, username, password, provider) VALUES (%s, %s, %s, %s)", (None, username, password, 'manual'))
                conn.commit()
                user_id = cur.lastrowid
                cur.execute("INSERT INTO stats (user_id, wins, losses, win_loss_ratio, current_win_streak, longest_win_streak) VALUES (%s, 0, 0, 0.0, 0, 0)", (user_id,))
                conn.commit()
                session['user_id'] = user_id


        cur.close()

    stats = None
    if 'user_id' in session:
        conn = mysql.connect
        cur = conn.cursor(MySQLdb.cursors.DictCursor)   # Use a dictionary cursor
        cur.execute("SELECT * FROM stats WHERE user_id = %s", (session['user_id'],))
        stats = cur.fetchone()
        cur.close()
        conn.close()


        return render_template('base.html', logged_in=True, stats=stats, username=session.get('username', ''))
    else:
        return render_template('base.html', logged_in=False, stats=stats, username=session.get('username', ''))
    
@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('base'))

@app.route('/category', methods=['GET', 'POST'])
def category():
    conn = mysql.connect
    try:
        cur = conn.cursor()
        print(f"Fetching stats for user id {session.get('user_id')}")
        cur.execute("SELECT * FROM stats WHERE user_id = %s", (session.get('user_id'),))
        stats = cur.fetchone()
        print(f"Fetched stats: {stats}")
    except Exception as e:
        print(f"Error executing database query: {e}")
        stats = None
    finally:
        cur.close()
        conn.close()

    if request.method == 'POST':
        category = request.form.get('category')
        if category:
            word = get_random_word(category)
            session['game'] = initialize_game(word)
            session['category'] = category
            return redirect(url_for('play'))
    return render_template('category.html', stats=stats, logged_in='user_id' in session, username=session.get('username', ''))

def initialize_game(word):
    hidden_word = ['_' if c != ' ' else '\u00A0' for c in word]
    incorrect_letters = []
    lives = 6
    return {
        'word': word,
        'hidden_word': hidden_word,
        'incorrect_letters': incorrect_letters,
        'lives': lives
    }

def get_random_word(category):
    if category == 'Alcohol':
        return random.choice(hangman_words.alcohol)
    elif category == 'Animals':
        return random.choice(hangman_words.animals)
    elif category == 'Countries':
        return random.choice(hangman_words.countries)
    elif category == 'Fruits':
        return random.choice(hangman_words.fruits)
    elif category == 'Professions':
        return random.choice(hangman_words.professions)
    elif category == 'Sports':
        return random.choice(hangman_words.sports)
    elif category == 'Instruments':
        return random.choice(hangman_words.instruments)
    elif category == 'Brands':
        return random.choice(hangman_words.brands)
    elif category == 'Cities':
        return random.choice(hangman_words.cities)
    elif category == 'Movies':
        return random.choice(hangman_words.movies)
    elif category == 'TV Shows':
        return random.choice(hangman_words.tv_shows)
    elif category == 'Books':
        return random.choice(hangman_words.books)

@app.route('/play', methods=['GET', 'POST'])
def play():
    if 'user_id' in session:
        conn = mysql.connect
        try:
            conn = mysql.connect
            cur = conn.cursor()
            cur.execute("SELECT * FROM stats WHERE user_id = %s", (session['user_id'],))
            stats = cur.fetchone()
            cur.close()
        except Exception as e:
            print(f"Error executing database query: {e}")
            stats = None
        finally:
            conn.close()
    else:
        return redirect(url_for('base'))

    game = session.get('game')
    if game:
        if request.method == 'POST':
            if 'letter' in request.form:
                letter = request.form['letter']
                if letter:
                    letter = letter.upper()
                    if letter in game['word'] and letter not in game['hidden_word']:
                        for i, char in enumerate(game['word']):
                            if char == letter:
                                game['hidden_word'][i] = letter
                        if '_' not in game['hidden_word']:
                            update_stats(won=True)
                            return redirect(url_for('win'))
                    elif letter not in game['incorrect_letters'] and letter not in game['hidden_word']:
                        game['incorrect_letters'].append(letter)
                        game['lives'] -= 1
                        if game['lives'] == 0:
                            update_stats(won=False)
                            return redirect(url_for('lose'))
                    session['game'] = game
            elif 'new_game' in request.form:
                update_stats(won=False)
                session.pop('game')
                return redirect(url_for('category'))
        return render_template('play.html', stats=stats, category=session.get('category'),
                           hidden_word=' '.join(game['hidden_word']), lives=game['lives'],
                           incorrect_letters=game['incorrect_letters'],
                           correct_letters=[letter for letter in game['hidden_word'] if letter != '_'],
                           logged_in='user_id' in session, username=session.get('username', ''))
    return redirect(url_for('category'))

def update_stats(won):
    if 'user_id' in session:
        conn = mysql.connect
        if conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM stats WHERE user_id = %s", (session['user_id'],))
            row = cursor.fetchone()
        if row:
            wins = row[1] + 1 if won else row[1]
            losses = row[2] + 1 if not won else row[2]
            win_loss_ratio = round(wins / losses, 2) if losses > 0 else wins
            current_win_streak = row[4] + 1 if won else 0
            longest_win_streak = max(row[5], current_win_streak)

            cursor.execute(
                "UPDATE stats SET wins = %s, losses = %s, win_loss_ratio = %s, current_win_streak = %s, longest_win_streak = %s WHERE user_id = %s",
                (wins, losses, win_loss_ratio, current_win_streak, longest_win_streak, session['user_id']))
            conn.commit()

        cursor.close()
        conn.close()

def get_player_stats():
    if 'user_id' in session:
        conn = mysql.connect
        if conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM stats WHERE user_id = %s", (session['user_id'],))
            stats = cursor.fetchone()
            conn.close()
            if stats:
                return stats
    return []

@app.route('/win')
def win():
    game = session.get('game')
    if game:
        if 'stats_updated' in session:
            update_stats(True)
            session.pop('stats_updated')
        word = game['word']
        lives = game['lives']
        stats = get_player_stats()
        return render_template('win.html', word=word, lives=lives, stats=stats, logged_in='user_id' in session, username=session.get('username', ''))
    return redirect(url_for('category'))

@app.route('/lose')
def lose():
    game = session.get('game')
    if game:
        if 'stats_updated' in session:
            update_stats(False)
            session.pop('stats_updated')

        word = game['word']
        stats = get_player_stats()
        return render_template('lose.html', word=word, stats=stats, logged_in='user_id' in session, username=session.get('username', ''))
    return redirect(url_for('category'))

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')

