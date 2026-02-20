from flask_login import UserMixin
from db import execute_query

class User(UserMixin):
    def __init__(self, id, email, role, customer_id=None):
        self.id = id
        self.email = email
        self.role = role # 'admin' or 'customer'
        self.customer_id = customer_id

def get_user_by_id(user_id):
    rows = execute_query("SELECT * FROM app_users WHERE id = %s", (user_id,))
    if rows:
        r = rows[0]
        return User(id=r['id'], email=r['email'], role=r['role'], customer_id=r['customer_id'])
    return None

def get_user_by_email(email):
    rows = execute_query("SELECT * FROM app_users WHERE email = %s", (email,))
    if rows:
        r = rows[0]
        return User(id=r['id'], email=r['email'], role=r['role'], customer_id=r['customer_id'])
    return None
