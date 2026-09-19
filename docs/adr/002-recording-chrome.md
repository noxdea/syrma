# ADR 002: Recording chrome is composited in pixel space

Cursor, captions, keycaps, highlights, and zoom are drawn after the application
screenshot. They never become Zaniah elements, so recording cannot change the
application tree or layout.
