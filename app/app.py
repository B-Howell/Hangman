from flask import Flask, render_template, request, redirect, url_for, session
from config import Config
import random
import hangman_words
import mysql.connector

app = Flask(__name__)
app.config.from_object(Config)

def get_db_connection():
    try:
        conn = mysql.connector.connect(
            host=app.config['DB_HOST'],
            user=app.config['DB_USER'],
            password=app.config['DB_PASSWORD'],
            database=app.config['DB_NAME']
        )
        return conn
    except mysql.connector.Error as error:
        print(f"Error connecting to database: {error}")
        return None

@app.route('/', methods=['GET', 'POST'])
def base():
    conn = get_db_connection()
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM stats")
            stats = cursor.fetchall()
        except mysql.connector.Error as error:
            print(f"Error executing database query: {error}")
            stats = None
        finally:
            cursor.close()
            conn.close()
    else:
        stats = None

    return render_template('base.html', stats=stats)


@app.route('/category', methods=['GET', 'POST'])
def category():
    conn = get_db_connection()
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM stats")
            stats = cursor.fetchall()
        except mysql.connector.Error as error:
            print(f"Error executing database query: {error}")
            stats = None
        finally:
            cursor.close()
            conn.close()
    else:
        stats = None

    if request.method == 'POST':
        category = request.form.get('category')
        if category:
            word = get_random_word(category)
            session['game'] = initialize_game(word)
            session['category'] = category
            return redirect(url_for('play'))
    return render_template('category.html', stats=stats)

def initialize_game(word):
    hidden_word = ['_' if c != ' ' else ' ' for c in word]
    incorrect_letters = []
    lives = 6
    return {
        'word': word,
        'hidden_word': hidden_word,
        'incorrect_letters': incorrect_letters,
        'lives': lives
    }

def get_random_word(category):
    if category == 'Animals':
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

@app.route('/play', methods=['GET', 'POST'])
def play():
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
                            session['stats_updated'] = True  # Flag stats for update
                            session['win_streak'] = session.get('win_streak', 0) + 1  # Increment win streak
                            return redirect(url_for('win'))
                    elif letter not in game['incorrect_letters'] and letter not in game['hidden_word']:
                        game['incorrect_letters'].append(letter)
                        game['lives'] -= 1
                        if game['lives'] == 0:
                            session['stats_updated'] = True  # Flag stats for update
                            session.pop('win_streak', None)  # Reset win streak
                            return redirect(url_for('lose'))
                    session['game'] = game
            elif 'new_game' in request.form:
                session.pop('game')
                session.pop('win_streak', None)  # Reset win streak
                return redirect(url_for('category'))
        return render_template('play.html', category=session.get('category'), hidden_word=' '.join(game['hidden_word']), lives=game['lives'], incorrect_letters=game['incorrect_letters'])
    return redirect(url_for('category'))

def update_stats(won):
    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        player_id = 'Player 1'  # Assuming there is only one player
        cursor.execute("SELECT * FROM stats WHERE player_id = %s", (player_id,))
        row = cursor.fetchone()
        if row:
            wins = int(row[1]) + 1 if won else int(row[1])
            losses = int(row[2]) + 1 if not won else int(row[2])

            # Update current win streak and longest win streak based on game result
            current_win_streak = session.get('win_streak', 0)
            longest_win_streak = max(int(row[4]), current_win_streak)

            cursor.execute("UPDATE stats SET wins = %s, losses = %s, current_win_streak = %s, longest_win_streak = %s WHERE player_id = %s",
                           (wins, losses, current_win_streak, longest_win_streak, player_id))
            conn.commit()
        conn.close()

def get_player_stats():
    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        player_id = 'Player 1'  # Assuming there is only one player
        cursor.execute("SELECT * FROM stats WHERE player_id = %s", (player_id,))
        stats = cursor.fetchone()
        conn.close()
        if stats:
            return stats
    return []  # Return an empty list if no stats are found

@app.route('/win')
def win():
    game = session.get('game')
    if game:
        if 'stats_updated' in session:
            update_stats(True)  # Update stats for winning game
            session.pop('stats_updated')

        word = game['word']
        lives = game['lives']

        # Fetch updated stats from the database
        stats = get_player_stats()

        if stats:
            wins = stats[1]  # Use the values from the updated stats
            losses = stats[2]
            win_loss_ratio = round(wins / losses, 2) if losses > 0 else wins
            current_win_streak = stats[3] + 1  # Increment the current win streak
            longest_win_streak = max(stats[4], current_win_streak)
        else:
            wins = 1
            losses = 0
            win_loss_ratio = wins
            current_win_streak = 1
            longest_win_streak = 1

        return render_template('win.html', word=word, lives=lives, wins=wins, losses=losses,
                               win_loss_ratio=format(win_loss_ratio, ".2f"), current_win_streak=current_win_streak,
                               longest_win_streak=longest_win_streak, stats=stats)
    return redirect(url_for('category'))



@app.route('/lose')
def lose():
    game = session.get('game')
    if game:
        if 'stats_updated' in session:
            update_stats(False)  # Update stats for losing game
            session.pop('stats_updated')

        word = game['word']

        # Fetch updated stats from the database
        stats = get_player_stats()

        if stats:
            wins = stats[1]
            losses = stats[2] + 1  # Increment the losses
            win_loss_ratio = round(wins / losses, 2) if losses > 0 else wins
            current_win_streak = 0  # Reset win streak for the current game
            longest_win_streak = max(stats[4], stats[3])  # Use the value from the stats directly
        else:
            wins = 0
            losses = 1
            win_loss_ratio = wins
            current_win_streak = 0
            longest_win_streak = 0

        return render_template('lose.html', word=word, losses=losses, wins=wins,
                               win_loss_ratio=format(win_loss_ratio, ".2f"), current_win_streak=current_win_streak,
                               longest_win_streak=longest_win_streak, stats=stats)
    return redirect(url_for('category'))

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')

