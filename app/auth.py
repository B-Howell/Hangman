import boto3
from botocore.exceptions import BotoCoreError, ClientError
from flask import Blueprint, request, session, redirect, url_for, jsonify
from config import Config

auth = Blueprint('auth', __name__)

session = boto3.Session(profile_name='terraform') 
cognito = session.client('cognito-idp', region_name='us-east-1')

def handle_register():
    username = request.form.get('new_username')
    email = request.form.get('new_email')
    password = request.form.get('new_password')

    if not username or not email or not password:
        return 'Username, email, and password are required.'
    if '@' not in email:
        return 'Invalid email address.'

    try:
        response = cognito.sign_up(
            ClientId=Config.CLIENT_ID,
            Username=username,
            Password=password,
            UserAttributes=[
                {
                    'Name': 'email',
                    'Value': email
                },
                {
                    'Name': 'preferred_username',
                    'Value': username
                },
            ]
        )
    except ClientError as e:
        # Error handling
        error_message = e.response['Error']['Message']
        if 'UsernameExistsException' in error_message:
            return 'An account with this username already exists.'
        else:
            return 'An error occurred: ' + error_message

    session['username'] = username
    session['user'] = response['User']
    return None

@auth.route('/register', methods=['POST'])
def register():
    error = handle_register()
    if error:
        return jsonify({'error': error})
    else:
        return redirect(request.referrer or url_for('base'))

def handle_login():
    username_or_email = request.form.get('username')
    password = request.form.get('password')

    # Basic input validation
    if not username_or_email or not password:
        return 'Username/email and password are required.'

    try:
        response = cognito.initiate_auth(
            AuthFlow='USER_PASSWORD_AUTH',
            AuthParameters={
                'USERNAME': username_or_email,
                'PASSWORD': password,
            },
            ClientId=Config.CLIENT_ID
        )
    except ClientError as e:
        # Error handling
        error_message = e.response['Error']['Message']
        if 'UserNotFoundException' in error_message:
            return 'Username/email does not exist.'
        elif 'NotAuthorizedException' in error_message:
            return 'Incorrect password. Try again.'
        else:
            return 'An error occurred: ' + error_message

    session['username'] = username_or_email
    session['tokens'] = response['AuthenticationResult']
    return None


@auth.route('/login', methods=['POST'])
def login():
    error = handle_login()
    if error:
        return jsonify({'error': error})
    else:
        return redirect(request.referrer or url_for('base'))

@auth.route('/forgot-password', methods=['POST'])
def forgot_password():
    username_or_email = request.form.get('username')

    # Basic input validation
    if not username_or_email:
        return jsonify({'error': 'Username/email is required.'}), 400

    try:
        response = cognito.forgot_password(
            ClientId=Config.CLIENT_ID,
            Username=username_or_email
        )
    except ClientError as e:
        # Error handling
        error_message = e.response['Error']['Message']
        if 'UserNotFoundException' in error_message:
            return jsonify({'error': 'Username/email does not exist.'}), 400
        else:
            return jsonify({'error': 'An error occurred: ' + error_message}), 400

    # If the request was successful, return a success message
    return jsonify({'message': 'Password reset code sent to email.'}), 200

