#Testing
if __name__ == '__main__':
    app.run(debug=True)

#Deployment
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

#Docker
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')