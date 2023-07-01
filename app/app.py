from flask import Flask, render_template, request, redirect, url_for, session, flash
from flask_mysqldb import MySQL
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config
import random
import hangman_words

app = Flask(__name__)
app.config.from_object(Config)
mysql = MySQL(app)

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')

        hashed_password = generate_password_hash(password)
        conn = mysql.connect
        cur = conn.cursor()
        cur.execute("INSERT INTO user (username, password) VALUES (%s, %s)", (username, hashed_password))
        conn.commit()

        cur.close()
        conn.close()

        return redirect(url_for('base'))

    return render_template('register.html')  # You need to create this template

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')

        conn = mysql.connect
        cur = conn.cursor()
        cur.execute("SELECT * FROM user WHERE username = %s", (username,))
        user = cur.fetchone()

        cur.close()
        conn.close()

        if user and check_password_hash(user[3], password):  # user[3] is password field
            session['user_id'] = user[0]  # user[0] is id field
            return redirect(url_for('base'))

        flash('Invalid username or password')

    return render_template('login.html')  # You need to create this template

@app.route('/', methods=['GET', 'POST'])
def base():
    if 'user_id' in session:
        # you will need to create a function to fetch the username based on the user_id from the session
        # username = get_username_from_db(session['user_id'])
        username = 'Logged in user'  # replace this with the actual username
    else:
        username = 'Guest'

    try:
        conn = mysql.connect
        cur = conn.cursor()
        cur.execute("SELECT * FROM stats")
        stats = cur.fetchall()
        cur.close()
    except Exception as e:
        print(f"Error executing database query: {e}")
        stats = None
    finally:
        conn.close()

    return render_template('base.html', stats=stats, name=username)  # now base.html receives a name to display

@app.route('/category', methods=['GET', 'POST'])
def category():
    conn = mysql.connect
    try:
        conn = mysql.connect
        cur = conn.cursor()
        cur.execute("SELECT * FROM stats")
        stats = cur.fetchall()
        cur.close()
    except Exception as e:
        print(f"Error executing database query: {e}")
        stats = None
    finally:
        conn.close()

    if request.method == 'POST':
        category = request.form.get('category')
        if category:
            word = get_random_word(category)
            session['game'] = initialize_game(word)
            session['category'] = category
            return redirect(url_for('play'))
    return render_template('category.html', stats=stats)

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
    conn = mysql.connect
    try:
        conn = mysql.connect
        cur = conn.cursor()
        cur.execute("SELECT * FROM stats")
        stats = cur.fetchall()
        cur.close()
    except Exception as e:
        print(f"Error executing database query: {e}")
        stats = None
    finally:
        conn.close()

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
                               correct_letters=[letter for letter in game['hidden_word'] if letter != '_'])
    return redirect(url_for('category'))

def update_stats(won):
    conn = mysql.connect
    if conn:
        cursor = conn.cursor()
        player_id = 'Player 1'
        cursor.execute("SELECT * FROM stats WHERE player_id = %s", (player_id,))
        row = cursor.fetchone()
        if row:
            wins = row[1] + 1 if won else row[1]
            losses = row[2] + 1 if not won else row[2]
            win_loss_ratio = round(wins / losses, 2) if losses > 0 else wins
            current_win_streak = row[4] + 1 if won else 0
            longest_win_streak = max(row[5], current_win_streak)

            cursor.execute(
                "UPDATE stats SET wins = %s, losses = %s, win_loss_ratio = %s, current_win_streak = %s, longest_win_streak = %s WHERE player_id = %s",
                (wins, losses, win_loss_ratio, current_win_streak, longest_win_streak, player_id))
            conn.commit()

        cursor.close()
        conn.close()

def get_player_stats():
    conn = mysql.connect
    if conn:
        cursor = conn.cursor()
        player_id = 'Player 1'
        cursor.execute("SELECT * FROM stats WHERE player_id = %s", (player_id,))
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
        return render_template('win.html', word=word, lives=lives, stats=stats)
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
        return render_template('lose.html', word=word, stats=stats)
    return redirect(url_for('category'))

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')

