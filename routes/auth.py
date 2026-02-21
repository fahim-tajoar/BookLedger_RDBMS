from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import login_user, logout_user, login_required, current_user
from forms import LoginForm, RegisterForm
from models import get_user_by_email, User
from db import execute_query, get_db_connection
from psycopg2.extras import RealDictCursor
from extensions import bcrypt

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('customer.home'))
        
    form = LoginForm()
    if form.validate_on_submit():
        user = get_user_by_email(form.email.data)
        
        # We query the DB again to get the password_hash
        rows = execute_query("SELECT id, password_hash, role, customer_id FROM app_users WHERE email = %s", (form.email.data,))
        
        if rows and bcrypt.check_password_hash(rows[0]['password_hash'], form.password.data):
            login_user(user)
            flash('Logged in successfully.', 'success')
            next_page = request.args.get('next')
            return redirect(next_page or url_for('customer.home'))
        else:
            flash('Login Unsuccessful. Please check email and password', 'danger')
            
    return render_template('auth/login.html', form=form)

@auth_bp.route('/register', methods=['GET', 'POST'])
def register():
    if current_user.is_authenticated:
        return redirect(url_for('customer.home'))
        
    form = RegisterForm()
    if form.validate_on_submit():
        hashed_password = bcrypt.generate_password_hash(form.password.data).decode('utf-8')
        
        # Check if email exists
        if get_user_by_email(form.email.data):
            flash('Email already registered', 'danger')
            return render_template('auth/register.html', form=form)

        # Use a single connection so both inserts are in one transaction
        conn = get_db_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # 1. Create customer record
                cur.execute(
                    "INSERT INTO customers (name, email) VALUES (%s, %s) RETURNING customer_id",
                    (form.name.data, form.email.data)
                )
                new_cust_id = cur.fetchone()['customer_id']

                # 2. Create app_user record mapped to customer
                cur.execute(
                    "INSERT INTO app_users (email, password_hash, role, customer_id) VALUES (%s, %s, %s, %s)",
                    (form.email.data, hashed_password, 'customer', new_cust_id)
                )

            conn.commit()
            flash('Account created! You are now able to log in', 'success')
            return redirect(url_for('auth.login'))
        except Exception as e:
            conn.rollback()
            flash(f"An error occurred: {str(e)}", "danger")
        finally:
            conn.close()

    return render_template('auth/register.html', form=form)

@auth_bp.route('/logout')
@login_required
def logout():
    logout_user()
    flash('You have been logged out.', 'info')
    return redirect(url_for('auth.login'))
