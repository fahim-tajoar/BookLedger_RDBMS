from flask import Blueprint, render_template, request, flash
from db import execute_query
import google.generativeai as genai
import os
import json
import re

ai_bp = Blueprint('ai', __name__)


def _get_inventory_context():
    """Fetch all in-stock books with details for the AI prompt."""
    books = execute_query("""
        SELECT b.isbn, b.title, b.description, b.price, b.stock_qty,
               g.genre_name, a.full_name as author_name
        FROM books b
        JOIN genres g ON b.genre_id = g.genre_id
        JOIN book_authors ba ON b.isbn = ba.isbn
        JOIN authors a ON ba.author_id = a.author_id
        WHERE b.stock_qty > 0
        ORDER BY b.title
    """)
    return books


def _build_prompt(user_query, books):
    """Build the Gemini prompt with inventory context."""
    book_list = "\n".join(
        f"- ISBN: {b['isbn']} | \"{b['title']}\" by {b['author_name']} | "
        f"Genre: {b['genre_name']} | ${b['price']} | "
        f"Description: {b['description'] or 'No description'}"
        for b in books
    )

    return f"""You are a knowledgeable bookstore assistant for BookLedger.
A customer is looking for book suggestions. Based on their request and ONLY the books
available in our inventory below, recommend the top 3 best matches.

CUSTOMER REQUEST: "{user_query}"

AVAILABLE INVENTORY:
{book_list}

Respond with EXACTLY this JSON format and nothing else:
{{
  "recommendations": [
    {{
      "isbn": "the book ISBN",
      "title": "the book title",
      "reason": "A warm, 1-2 sentence explanation of why this book matches what they're looking for"
    }},
    {{
      "isbn": "the book ISBN",
      "title": "the book title",
      "reason": "A warm, 1-2 sentence explanation"
    }},
    {{
      "isbn": "the book ISBN",
      "title": "the book title",
      "reason": "A warm, 1-2 sentence explanation"
    }}
  ],
  "message": "A friendly 1-sentence overall note to the customer about these picks"
}}

Rules:
- ONLY recommend books from the inventory list above
- Return valid JSON only, no markdown formatting, no code fences
- If fewer than 3 books match, return as many as you can
- Be enthusiastic but genuine in your reasons"""


def _parse_ai_response(response_text, all_books):
    """Parse the AI response and enrich with full book data."""
    # Strip markdown code fences if present
    cleaned = response_text.strip()
    cleaned = re.sub(r'^```(?:json)?\s*', '', cleaned)
    cleaned = re.sub(r'\s*```$', '', cleaned)

    data = json.loads(cleaned)

    # Build lookup dict
    book_map = {b['isbn']: b for b in all_books}

    recommendations = []
    for rec in data.get('recommendations', []):
        isbn = rec.get('isbn', '')
        if isbn in book_map:
            book = book_map[isbn]
            recommendations.append({
                'isbn': isbn,
                'title': book['title'],
                'author_name': book['author_name'],
                'genre_name': book['genre_name'],
                'price': book['price'],
                'description': book['description'],
                'stock_qty': book['stock_qty'],
                'reason': rec.get('reason', '')
            })

    message = data.get('message', '')
    return recommendations, message


@ai_bp.route('/recommend', methods=['GET', 'POST'])
def recommend():
    recommendations = []
    ai_message = ''
    user_query = ''
    error = None

    if request.method == 'POST':
        user_query = request.form.get('query', '').strip()

        if not user_query:
            flash('Please describe what kind of book you\'re looking for!', 'warning')
        else:
            try:
                api_key = os.getenv('GEMINI_API_KEY', '')
                if not api_key or api_key == 'your_gemini_api_key_here':
                    raise ValueError('Gemini API key not configured. Please set GEMINI_API_KEY in .env')

                genai.configure(api_key=api_key)
                model = genai.GenerativeModel('gemini-2.5-flash')

                books = _get_inventory_context()
                if not books:
                    flash('No books currently in stock.', 'warning')
                    return render_template('customer/recommend.html',
                                           recommendations=[], ai_message='', user_query=user_query)

                prompt = _build_prompt(user_query, books)
                response = model.generate_content(prompt)

                recommendations, ai_message = _parse_ai_response(response.text, books)

                if not recommendations:
                    flash('The AI couldn\'t find matching books. Try a different description!', 'info')

            except json.JSONDecodeError:
                error = 'The AI returned an unexpected format. Please try again.'
                flash(error, 'danger')
            except ValueError as e:
                flash(str(e), 'danger')
            except Exception as e:
                error_str = str(e)
                if 'API key expired' in error_str or 'API_KEY_INVALID' in error_str:
                    error = 'Your Gemini API key has expired or is invalid. Please update the GEMINI_API_KEY in your .env file.'
                else:
                    error = f'AI recommendation failed: {error_str}'
                flash(error, 'danger')

    return render_template('customer/recommend.html',
                           recommendations=recommendations,
                           ai_message=ai_message,
                           user_query=user_query)
