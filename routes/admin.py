from flask import Blueprint, render_template, flash, redirect, url_for, request
from flask_login import login_required, current_user
from functools import wraps
from db import execute_query, execute_procedure
from decimal import Decimal

admin_bp = Blueprint('admin', __name__)

def admin_required(f):
    @wraps(f)
    @login_required
    def decorated(*args, **kwargs):
        if current_user.role != 'admin':
            flash('Access denied. Admin privileges required.', 'danger')
            return redirect(url_for('customer.home'))
        return f(*args, **kwargs)
    return decorated

# ---------- Dashboard ----------
@admin_bp.route('/')
@admin_required
def dashboard():
    # Revenue KPIs
    revenue = execute_query("""
        SELECT 
            COUNT(*) as total_sales,
            COALESCE(SUM(total_amount), 0) as total_revenue,
            COALESCE(ROUND(AVG(total_amount), 2), 0) as avg_order
        FROM sales_header WHERE status = 'COMPLETED'
    """)
    kpis = revenue[0] if revenue else {'total_sales': 0, 'total_revenue': 0, 'avg_order': 0}

    # Low stock alerts
    low_stock = execute_query("""
        SELECT b.isbn, b.title, b.stock_qty, b.price
        FROM books b WHERE b.stock_qty < 5
        ORDER BY b.stock_qty ASC
    """)

    # Recent sales
    recent_sales = execute_query("""
        SELECT sh.sale_id, c.name as customer_name, sh.total_amount,
               sh.payment_method, sh.sale_date, sh.status
        FROM sales_header sh
        JOIN customers c ON sh.customer_id = c.customer_id
        ORDER BY sh.sale_date DESC LIMIT 10
    """)

    # Customer count
    cust_count = execute_query("SELECT COUNT(*) as count FROM customers")
    total_customers = cust_count[0]['count'] if cust_count else 0

    # Book count
    book_count = execute_query("SELECT COUNT(*) as count FROM books")
    total_books = book_count[0]['count'] if book_count else 0

    return render_template('admin/dashboard.html',
        kpis=kpis, low_stock=low_stock, recent_sales=recent_sales,
        total_customers=total_customers, total_books=total_books)

# ---------- Refresh Materialized Views ----------
@admin_bp.route('/refresh', methods=['POST'])
@admin_required
def refresh_views():
    try:
        execute_procedure('prc_refresh_dashboards')
        flash('Dashboard views refreshed successfully!', 'success')
    except Exception as e:
        flash(f'Failed to refresh views: {str(e)}', 'danger')
    return redirect(url_for('admin.dashboard'))

# ---------- Auto-Restock ----------
@admin_bp.route('/restock', methods=['POST'])
@admin_required
def auto_restock():
    try:
        execute_procedure('proc_auto_restock')
        flash('Auto-restock completed! Purchase orders created for low-stock items.', 'success')
    except Exception as e:
        flash(f'Restock failed: {str(e)}', 'danger')
    return redirect(url_for('admin.dashboard'))

# ---------- Inventory ----------
@admin_bp.route('/inventory')
@admin_required
def inventory():
    books = execute_query("""
        SELECT b.isbn, b.title, b.price, b.stock_qty, b.publication_date,
               g.genre_name, s.company_name as supplier_name
        FROM books b
        JOIN genres g ON b.genre_id = g.genre_id
        LEFT JOIN suppliers s ON b.supplier_id = s.supplier_id
        ORDER BY b.title
    """)
    genres = execute_query("SELECT genre_id, genre_name FROM genres ORDER BY genre_name")
    suppliers = execute_query("SELECT supplier_id, company_name FROM suppliers ORDER BY company_name")
    return render_template('admin/inventory.html', books=books, genres=genres, suppliers=suppliers)

@admin_bp.route('/inventory/add', methods=['POST'])
@admin_required
def add_book():
    try:
        isbn = request.form['isbn']
        title = request.form['title']
        genre_id = request.form['genre_id']
        price = request.form['price']
        stock_qty = request.form.get('stock_qty', 0)
        supplier_id = request.form.get('supplier_id') or None
        pub_date = request.form.get('publication_date') or None

        execute_query("""
            INSERT INTO books (isbn, title, genre_id, price, stock_qty, supplier_id, publication_date)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (isbn, title, genre_id, price, stock_qty, supplier_id, pub_date), fetch=False)
        flash(f'Book "{title}" added successfully!', 'success')
    except Exception as e:
        flash(f'Failed to add book: {str(e)}', 'danger')
    return redirect(url_for('admin.inventory'))

# ---------- Purchase Orders ----------
@admin_bp.route('/purchase-orders')
@admin_required
def purchase_orders():
    pos = execute_query("""
        SELECT po.po_id, s.company_name as supplier_name, po.order_date,
               po.status, po.total_amount, po.received_date
        FROM purchase_orders po
        JOIN suppliers s ON po.supplier_id = s.supplier_id
        ORDER BY po.order_date DESC
    """)
    # Get details for each PO
    for po in pos:
        po['details'] = execute_query("""
            SELECT pod.isbn, b.title, pod.quantity, pod.unit_cost, pod.line_total
            FROM purchase_order_details pod
            JOIN books b ON pod.isbn = b.isbn
            WHERE pod.po_id = %s
        """, (po['po_id'],))
    return render_template('admin/purchase_orders.html', purchase_orders=pos)

@admin_bp.route('/purchase-orders/<int:po_id>/receive', methods=['POST'])
@admin_required
def receive_po(po_id):
    try:
        execute_procedure('proc_receive_purchase_order', (po_id,))
        flash(f'Purchase Order #{po_id} received! Stock updated.', 'success')
    except Exception as e:
        flash(f'Failed to receive PO: {str(e)}', 'danger')
    return redirect(url_for('admin.purchase_orders'))

# ---------- Returns ----------
@admin_bp.route('/returns')
@admin_required
def returns():
    ret = execute_query("""
        SELECT r.return_id, r.sale_id, r.isbn, b.title, r.quantity,
               r.condition, r.reason, r.return_date, r.refund_amount,
               c.name as customer_name
        FROM returns r
        JOIN books b ON r.isbn = b.isbn
        JOIN sales_header sh ON r.sale_id = sh.sale_id
        JOIN customers c ON sh.customer_id = c.customer_id
        ORDER BY r.return_date DESC
    """)
    return render_template('admin/returns.html', returns=ret)

@admin_bp.route('/returns/process', methods=['POST'])
@admin_required
def process_return():
    try:
        sale_id = request.form['sale_id']
        isbn = request.form['isbn']
        quantity = request.form['quantity']
        condition = request.form['condition']
        reason = request.form.get('reason', '')

        # Look up unit price from the sale
        detail = execute_query(
            "SELECT unit_price FROM sales_details WHERE sale_id = %s AND isbn = %s",
            (sale_id, isbn))
        if not detail:
            flash('Sale detail not found for that sale + ISBN.', 'danger')
            return redirect(url_for('admin.returns'))

        refund = float(detail[0]['unit_price']) * int(quantity)

        execute_query("""
            INSERT INTO returns (sale_id, isbn, quantity, condition, reason, refund_amount)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (sale_id, isbn, quantity, condition, reason, refund), fetch=False)
        flash(f'Return processed. Refund: ${refund:.2f}', 'success')
    except Exception as e:
        flash(f'Return failed: {str(e)}', 'danger')
    return redirect(url_for('admin.returns'))

# ---------- Audit Logs ----------
@admin_bp.route('/audit')
@admin_required
def audit():
    logs = execute_query("""
        SELECT log_id, target_table, target_pk, action_type,
               column_changed, old_value, new_value, changed_by, change_time
        FROM audit_logs
        ORDER BY change_time DESC
        LIMIT 100
    """)
    return render_template('admin/audit.html', logs=logs)
