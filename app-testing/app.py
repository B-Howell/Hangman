from flask import Flask, render_template, request, redirect, url_for, session
from config import Config
import random
import hangman_words

app = Flask(__name__)
app.config.from_object(Config)

@app.route('/', methods=['GET', 'POST'])
def base():
    if request.method == 'POST':
        return redirect(url_for('category'))
    return render_template('base.html')

@app.route('/category', methods=['GET', 'POST'])
def category():
    if request.method == 'POST':
        category = request.form.get('category')
        if category:
            word = get_random_word(category)
            session['game'] = initialize_game(word)
            session['category'] = category
            return redirect(url_for('play'))
    return render_template('category.html')

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
                            return redirect(url_for('win'))
                    elif letter not in game['incorrect_letters'] and letter not in game['hidden_word']:
                        game['incorrect_letters'].append(letter)
                        game['lives'] -= 1
                        if game['lives'] == 0:
                            return redirect(url_for('lose'))
                    session['game'] = game
            elif 'new_game' in request.form:
                session.pop('game')
                return redirect(url_for('category'))
        return render_template('play.html', category=session.get('category'), hidden_word=' '.join(game['hidden_word']), lives=game['lives'], incorrect_letters=game['incorrect_letters'])
    return redirect(url_for('category'))


@app.route('/win')
def win():
    game = session.get('game')
    if game:
        word = game['word']
        lives = game['lives']
        session.clear()
        return render_template('win.html', word=word, lives=lives)
    return redirect(url_for('category'))

@app.route('/lose')
def lose():
    game = session.get('game')
    if game:
        word = game['word']
        session.clear()
        return render_template('lose.html', word=word)
    return redirect(url_for('category'))

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')

