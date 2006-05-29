PRAGMA fullfsync = 0;
PRAGMA synchronous = FULL;
PRAGMA page_size = 4096;

BEGIN EXCLUSIVE TRANSACTION;

CREATE TABLE IF NOT EXISTS session (
    id INTEGER PRIMARY KEY ON CONFLICT ROLLBACK AUTOINCREMENT,
    context INTEGER NOT NULL ON CONFLICT ROLLBACK,
    start TEXT DEFAULT CURRENT_TIMESTAMP,
    end TEXT,
    identifier TEXT,
    comments TEXT
);

CREATE INDEX IF NOT EXISTS session_context_index ON session (context);

CREATE TABLE IF NOT EXISTS digest (
    position INTEGER PRIMARY KEY ON CONFLICT ROLLBACK AUTOINCREMENT,
    session INTEGER NOT NULL ON CONFLICT ROLLBACK,
    context INTEGER NOT NULL ON CONFLICT ROLLBACK,
    entity TEXT NOT NULL ON CONFLICT ROLLBACK,
    link INTEGER NOT NULL ON CONFLICT ROLLBACK
);

CREATE INDEX IF NOT EXISTS digest_session_index ON digest (session);
CREATE INDEX IF NOT EXISTS digest_context_index ON digest (context);
CREATE INDEX IF NOT EXISTS digest_entity_link_index ON digest (entity, link);

CREATE TABLE IF NOT EXISTS message (
    id INTEGER PRIMARY KEY ON CONFLICT ROLLBACK AUTOINCREMENT,
    context INTEGER NOT NULL ON CONFLICT ROLLBACK,
    session INTEGER NOT NULL ON CONFLICT ROLLBACK,
    user INTEGER NOT NULL ON CONFLICT ROLLBACK,
    received TEXT DEFAULT CURRENT_TIMESTAMP,
    action INTEGER DEFAULT 0,
    highlighted INTEGER DEFAULT 0,
    ignored TEXT,
    type TEXT,
    content TEXT NOT NULL ON CONFLICT ROLLBACK
);

CREATE INDEX IF NOT EXISTS message_session_index ON message (session);
CREATE INDEX IF NOT EXISTS message_context_index ON message (context);
CREATE INDEX IF NOT EXISTS message_user_index ON message (user);

CREATE TABLE IF NOT EXISTS event (
    id INTEGER PRIMARY KEY ON CONFLICT ROLLBACK AUTOINCREMENT,
    context INTEGER NOT NULL ON CONFLICT ROLLBACK,
    session INTEGER NOT NULL ON CONFLICT ROLLBACK,
    name TEXT NOT NULL ON CONFLICT ROLLBACK,
    occurred TEXT DEFAULT CURRENT_TIMESTAMP,
    content TEXT NOT NULL ON CONFLICT ROLLBACK
);

CREATE INDEX IF NOT EXISTS event_session_index ON event (session);
CREATE INDEX IF NOT EXISTS event_context_index ON event (context);

CREATE TABLE IF NOT EXISTS context (
    id INTEGER PRIMARY KEY ON CONFLICT ROLLBACK AUTOINCREMENT,
    protocol TEXT NOT NULL ON CONFLICT ROLLBACK,
    server TEXT NOT NULL ON CONFLICT ROLLBACK,
    name TEXT NOT NULL ON CONFLICT ROLLBACK,
    url TEXT
);

CREATE INDEX IF NOT EXISTS context_protocol_server_name_index ON context (protocol, server, name);

CREATE TABLE IF NOT EXISTS user (
    id INTEGER PRIMARY KEY ON CONFLICT ROLLBACK AUTOINCREMENT,
    self INTEGER DEFAULT 0,
    name TEXT NOT NULL ON CONFLICT ROLLBACK,
    identifier TEXT,
    nickname TEXT,
    hostmask TEXT,
    class TEXT,
    buddy TEXT
);

CREATE INDEX IF NOT EXISTS user_index ON user (self, name, identifier, nickname, hostmask, class, buddy);

CREATE TABLE IF NOT EXISTS attribute (
    id INTEGER PRIMARY KEY ON CONFLICT ROLLBACK AUTOINCREMENT,
    entity TEXT NOT NULL ON CONFLICT ROLLBACK,
    link INTEGER,
    identifier TEXT NOT NULL ON CONFLICT ROLLBACK,
    type TEXT DEFAULT "text/plain",
    value TEXT
);

CREATE INDEX IF NOT EXISTS attribute_entity_link_index ON attribute (entity, link);

COMMIT TRANSACTION;

BEGIN EXCLUSIVE TRANSACTION;

CREATE TRIGGER session_id_change AFTER UPDATE OF id ON session
	FOR EACH ROW BEGIN
		UPDATE message SET session = new.id WHERE session = old.id;
		UPDATE event SET session = new.id WHERE session = old.id;
		UPDATE digest SET session = new.id WHERE session = old.id;
	END;

CREATE TRIGGER session_delete AFTER DELETE ON session
	FOR EACH ROW BEGIN
		DELETE FROM message WHERE session = old.id;
		DELETE FROM event WHERE session = old.id;
		DELETE FROM digest WHERE session = old.id;
	END;

CREATE TRIGGER message_digest_insert AFTER INSERT ON message
	FOR EACH ROW BEGIN
		INSERT INTO digest (session, context, entity, link) VALUES (new.session, new.context, "message", new.id);
	END;

CREATE TRIGGER message_digest_delete AFTER DELETE ON message
	FOR EACH ROW BEGIN
		DELETE FROM digest WHERE link = old.id AND entity = "message";
		DELETE FROM attribute WHERE link = old.id AND entity = "message";
	END;

CREATE TRIGGER message_id_change AFTER UPDATE OF id ON message
	FOR EACH ROW BEGIN
		UPDATE digest SET link = new.id WHERE link = old.id AND entity = "message";
		UPDATE attribute SET link = new.id WHERE link = old.id AND entity = "message";
	END;

CREATE TRIGGER message_session_change AFTER UPDATE OF session ON message
	FOR EACH ROW BEGIN
		UPDATE digest SET session = new.session WHERE link = old.id AND entity = "message";
	END;

CREATE TRIGGER message_context_change AFTER UPDATE OF context ON message
	FOR EACH ROW BEGIN
		UPDATE digest SET context = new.context WHERE link = old.id AND entity = "message";
	END;

CREATE TRIGGER event_digest_insert AFTER INSERT ON event
	FOR EACH ROW BEGIN
		INSERT INTO digest (session, context, entity, link) VALUES (new.session, new.context, "event", new.id);
	END;

CREATE TRIGGER event_digest_delete AFTER DELETE ON event
	FOR EACH ROW BEGIN
		DELETE FROM digest WHERE link = old.id AND entity = "event";
		DELETE FROM attribute WHERE link = old.id AND entity = "event";
	END;

CREATE TRIGGER event_id_change AFTER UPDATE OF id ON event
	FOR EACH ROW BEGIN
		UPDATE digest SET link = new.id WHERE link = old.id AND entity = "event";
		UPDATE attribute SET link = new.id WHERE link = old.id AND entity = "event";
	END;

CREATE TRIGGER event_session_change AFTER UPDATE OF session ON event
	FOR EACH ROW BEGIN
		UPDATE digest SET session = new.session WHERE link = old.id AND entity = "event";
	END;

CREATE TRIGGER event_context_change AFTER UPDATE OF context ON event
	FOR EACH ROW BEGIN
		UPDATE digest SET context = new.context WHERE link = old.id AND entity = "event";
	END;

CREATE TRIGGER context_id_change AFTER UPDATE OF id ON context
	FOR EACH ROW BEGIN
		UPDATE message SET context = new.id WHERE context = old.id;
		UPDATE event SET context = new.id WHERE context = old.id;
		UPDATE digest SET context = new.id WHERE context = old.id;
		UPDATE session SET context = new.id WHERE context = old.id;
	END;

CREATE TRIGGER context_delete AFTER DELETE ON context
	FOR EACH ROW BEGIN
		DELETE FROM message WHERE context = old.id;
		DELETE FROM event WHERE context = old.id;
		DELETE FROM digest WHERE context = old.id;
		DELETE FROM session WHERE context = old.id;
	END;

CREATE TRIGGER user_id_change AFTER UPDATE OF id ON user
	FOR EACH ROW BEGIN
		UPDATE message SET user = new.id WHERE user = old.id;
	END;

CREATE TRIGGER user_delete AFTER DELETE ON user
	FOR EACH ROW BEGIN
		DELETE FROM message WHERE user = old.id;
	END;

COMMIT TRANSACTION;
