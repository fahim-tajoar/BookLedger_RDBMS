from flask import Blueprint, render_template, request, session, flash, redirect, url_for
from flask_login import login_required, current_user
from db import execute_query, execute_function, execute_procedure

customer_bp = Blueprint('customer', __name__)

@customer_bp.route('/')
def home():
    # Fetch data from materialized views
    top_authors = execute_query("SELECT * FROM mv_dashboard_top_authors LIMIT 4")
    genre_trends = execute_query("SELECT * FROM mv_dashboard_genre_trends LIMIT 6")
    return render_template('customer/home.html', top_authors=top_authors, genre_trends=genre_trends)

@customer_bp.route('/books')
def catalog():
    title = request.args.get('title')
    author = request.args.get('author')
    genre = request.args.get('genre')
    
    # Utilizing the fn_smart_search stored function
    books = execute_function('fn_smart_search', (title, author, genre, None, None))
    return render_template('customer/catalog.html', books=books)

@customer_bp.route('/books/<isbn>')
def book_details(isbn):
    book_query = """
        SELECT b.isbn, b.title, b.price, b.stock_qty, b.publication_date,
               g.genre_name, a.full_name as author_name, ba.preview_text
        FROM books b
        JOIN genres g ON b.genre_id = g.genre_id
        JOIN book_authors boa ON b.isbn = boa.isbn
        JOIN authors a ON boa.author_id = a.author_id
        LEFT JOIN book_assets ba ON b.isbn = ba.isbn
        WHERE b.isbn = %s
    """
    rows = execute_query(book_query, (isbn,))
    if not rows:
        return "Book not found", 404
    book = rows[0]
    return render_template('customer/book_details.html', book=book)

# ---------- Cart (session-based) ----------
@customer_bp.route('/cart')
def view_cart():
    cart = session.get('cart', {})
    cart_items = []
    total = 0
    
    if cart:
        isbns = tuple(cart.keys())
        in_clause = ','.join(['%s']*len(isbns))
        query = f"SELECT isbn, title, price FROM books WHERE isbn IN ({in_clause})"
        books = execute_query(query, isbns)
        
        for book in books:
            qty = cart[book['isbn']]
            line_total = float(book['price']) * qty
            total += line_total
            book['quantity'] = qty
            book['line_total'] = line_total
            cart_items.append(book)
            
    return render_template('customer/cart.html', items=cart_items, total=total)

@customer_bp.route('/cart/add/<isbn>', methods=['POST'])
def add_to_cart(isbn):
    cart = session.get('cart', {})
    cart[isbn] = cart.get(isbn, 0) + 1
    session['cart'] = cart
    flash('Book added to cart!', 'success')
    return redirect(request.referrer or url_for('customer.catalog'))

@customer_bp.route('/cart/remove/<isbn>', methods=['POST'])
def remove_from_cart(isbn):
    cart = session.get('cart', {})
    if isbn in cart:
        del cart[isbn]
        session['cart'] = cart
    flash('Item removed from cart.', 'info')
    return redirect(url_for('customer.view_cart'))

@customer_bp.route('/cart/update/<isbn>', methods=['POST'])
def update_cart(isbn):
    qty = int(request.form.get('quantity', 1))
    cart = session.get('cart', {})
    if qty > 0:
        cart[isbn] = qty
    else:
        cart.pop(isbn, None)
    session['cart'] = cart
    return redirect(url_for('customer.view_cart'))

@customer_bp.route('/checkout/<isbn>', methods=['POST'])
@login_required
def checkout(isbn):
    qty = 1 # simplified to 1 for direct buy logic
    customer_id = current_user.customer_id
    
    try:
        # Calls the atomic checkout procedure
        execute_procedure('proc_atomic_checkout', (customer_id, isbn, qty))
        # Remove from cart if present
        cart = session.get('cart', {})
        cart.pop(isbn, None)
        session['cart'] = cart
        flash('Purchase successful! Thank you.', 'success')
        return redirect(url_for('customer.home'))
    except Exception as e:
        flash(f"Checkout failed: {str(e)}", 'danger')
        return redirect(url_for('customer.book_details', isbn=isbn))

@customer_bp.route('/checkout/cart', methods=['POST'])
@login_required
def checkout_cart():
    cart = session.get('cart', {})
    if not cart:
        flash('Your cart is empty.', 'warning')
        return redirect(url_for('customer.view_cart'))
    
    customer_id = current_user.customer_id
    errors = []
    successes = 0
    
    for isbn, qty in cart.items():
        try:
            execute_procedure('proc_atomic_checkout', (customer_id, isbn, qty))
            successes += 1
        except Exception as e:
            errors.append(f"{isbn}: {str(e)}")
    
    session['cart'] = {}
    
    if successes:
        flash(f'Successfully purchased {successes} item(s)!', 'success')
    if errors:
        flash(f'Some items failed: {"; ".join(errors)}', 'danger')
    
    return redirect(url_for('customer.profile'))

# ---------- Profile ----------
@customer_bp.route('/profile')
@login_required
def profile():
    # Get customer info
    customer = execute_query("""
        SELECT name, email, membership_pts, trust_score, created_at
        FROM customers WHERE customer_id = %s
    """, (current_user.customer_id,))
    
    if not customer:
        flash('Customer profile not found.', 'danger')
        return redirect(url_for('customer.home'))
    
    customer = customer[0]
    
    # Purchase history
    purchases = execute_query("""
        SELECT sh.sale_id, sh.sale_date, sh.total_amount, sh.payment_method,
               sd.isbn, b.title, sd.quantity, sd.unit_price
        FROM sales_header sh
        JOIN sales_details sd ON sh.sale_id = sd.sale_id
        JOIN books b ON sd.isbn = b.isbn
        WHERE sh.customer_id = %s
        ORDER BY sh.sale_date DESC
    """, (current_user.customer_id,))
    
    return render_template('customer/profile.html', customer=customer, purchases=purchases)
