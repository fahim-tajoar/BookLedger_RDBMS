import psycopg2
from psycopg2.extras import RealDictCursor
from flask import current_app

def get_db_connection():
    conn = psycopg2.connect(
        host=current_app.config['DB_HOST'],
        database=current_app.config['DB_NAME'],
        user=current_app.config['DB_USER'],
        password=current_app.config['DB_PASS'],
        port=current_app.config['DB_PORT']
    )
    return conn

def execute_query(query, params=None, fetch=True):
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, params)
            if fetch:
                result = cur.fetchall()
                conn.commit()
                return result
            conn.commit()
    finally:
        conn.close()

def execute_procedure(proc_name, params=None):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            if params:
                cur.execute(f"CALL {proc_name}({','.join(['%s']*len(params))})", params)
            else:
                cur.execute(f"CALL {proc_name}()")
            conn.commit()
    finally:
        conn.close()

def execute_function(func_name, params=None, fetch=True):
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            if params:
                cur.execute(f"SELECT * FROM {func_name}({','.join(['%s']*len(params))})", params)
            else:
                cur.execute(f"SELECT * FROM {func_name}()")
            if fetch:
                return cur.fetchall()
            conn.commit()
    finally:
        conn.close()
