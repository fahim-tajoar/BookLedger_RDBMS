from flask import Flask, redirect, url_for
from flask_login import LoginManager
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

# Initialize LoginManager
login_manager = LoginManager()

def create_app():
    app = Flask(__name__)
    
    # Configuration
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'default-key')
    app.config['DB_HOST'] = os.getenv('DB_HOST', 'localhost')
    app.config['DB_PORT'] = os.getenv('DB_PORT', '5432')
    app.config['DB_NAME'] = os.getenv('DB_NAME', 'postgres')
    app.config['DB_USER'] = os.getenv('DB_USER', 'postgres')
    app.config['DB_PASS'] = os.getenv('DB_PASS', 'postgres')

    # Initialize extensions
    login_manager.init_app(app)
    login_manager.login_view = 'auth.login'  # type: ignore
    login_manager.login_message_category = 'warning'
    
    from extensions import bcrypt
    bcrypt.init_app(app)

    # User loader callback for Flask-Login
    from models import get_user_by_id  # We will create this
    @login_manager.user_loader
    def load_user(user_id):
        return get_user_by_id(user_id)

    # Register Blueprints
    from routes.auth import auth_bp
    from routes.customer import customer_bp
    from routes.admin import admin_bp

    app.register_blueprint(auth_bp, url_prefix='/auth')
    app.register_blueprint(customer_bp)
    app.register_blueprint(admin_bp, url_prefix='/admin')

    return app

if __name__ == '__main__':
    app = create_app()
    app.run(debug=True)
