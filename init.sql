-- NOTE: ALL num_* FIELDS ARE AUTOMATICALLY SET BY TRIGGERS

CREATE DOMAIN uint AS integer
	CHECK (VALUE >= 0);

CREATE DOMAIN url AS text
	CHECK (VALUE ~* '^https?://.*$');

CREATE DOMAIN media_file AS text
	CHECK (VALUE ~* '^.+?\.(png|jpe?g)$');

CREATE TABLE sites (
	id smallserial NOT NULL PRIMARY KEY,
	-- used to identify the site (e.g. 'twitter', 'discord')
	name text NOT NULL UNIQUE,
	-- e.g. 'https://pbs.twimg.com/'
	base_media_url url NOT NULL UNIQUE,
	num_images uint NOT NULL DEFAULT 0,
	num_votes uint NOT NULL DEFAULT 0,
	num_approved uint NOT NULL DEFAULT 0,
	identifier_validation_regex text NOT NULL
);

INSERT INTO sites (name, base_media_url, identifier_validation_regex) VALUES ('twitter', 'http://pbs.twimg.com/', '/\d{,19}/');

CREATE TABLE source_states (
	id smallserial NOT NULL PRIMARY KEY,
	name text NOT NULL
);

INSERT INTO source_states (name) VALUES ('pending'), ('populating'), ('standby'), ('refreshing'), ('inactive');

CREATE TABLE sources (
	id serial NOT NULL PRIMARY KEY,
	site_id smallint NOT NULL REFERENCES sites(id),
	state smallint NOT NULL REFERENCES source_states(id),
	-- the unique id we use to query for stuff from this source
	remote_identifier text NOT NULL UNIQUE,
	last_processed_id text,
	-- last time this source was refreshed
	last_refreshed timestamp,
	num_images uint NOT NULL DEFAULT 0,
	num_votes uint NOT NULL DEFAULT 0,
	num_approved uint NOT NULL DEFAULT 0,
	position_points json NOT NULL DEFAULT '[]'::json
);

-- partial index to be used when looking for sources to refresh (only sources on standby get refreshed)
CREATE INDEX ON sources(last_refreshed) WHERE last_refreshed IS NOT NULL AND state = 2;
CREATE INDEX ON sources(state);

CREATE TABLE images (
	id bigserial NOT NULL PRIMARY KEY,
	source_id integer NOT NULL REFERENCES sources(id),
	-- this URL is appended onto the source's site's base_media_url
	source_url media_file NOT NULL UNIQUE,
	-- the URL once media is uploaded onto s3
	s3_url media_file,
	-- original discord message or tweet contents
	description text,
	date_added timestamp NOT NULL DEFAULT NOW(),
	-- set automatically via trigger, when s3_url is added
	date_uploaded timestamp,
	num_votes uint NOT NULL DEFAULT 0,
	num_approved uint NOT NULL DEFAULT 0,
	-- md5 hash of the image, to check for duplicate images
	md5 uuid,

	UNIQUE (source_id, source_url)
);

CREATE INDEX ON images(source_id);
CREATE INDEX ON images(md5) WHERE md5 IS NOT NULL;

CREATE TABLE users (
	id serial NOT NULL PRIMARY KEY,
	password text NOT NULL,
	num_votes uint NOT NULL DEFAULT 0,
	num_approved uint NOT NULL DEFAULT 0
);

CREATE TABLE votes (
	user_id integer NOT NULL REFERENCES users(id),
	image_id bigint NOT NULL REFERENCES images(id),
	vote boolean NOT NULL,
	time timestamp NOT NULL DEFAULT NOW(),

	UNIQUE (user_id, image_id)
);

-- table for metadata (categories, tags, etc)?

-- do we want to index num_* columns for finding best/worst images/users/sites/sources?

CREATE FUNCTION update_image_date_uploaded() RETURNS TRIGGER AS $$
	BEGIN
		UPDATE images
			SET date_uploaded = NOW()
			WHERE images.id = NEW.id;
		RETURN NEW;
	END
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER update_image_date_uploaded
	AFTER UPDATE OF s3_url
		ON images
	FOR EACH ROW
	EXECUTE PROCEDURE update_image_date_uploaded();

CREATE FUNCTION update_num_images() RETURNS TRIGGER AS $$
	DECLARE
		change_amount integer;
		site_id integer;
	BEGIN
		site_id := (
			SELECT sites.id
				FROM sites
				JOIN sources
					ON sources.site_id = sites.id
				WHERE sources.id = NEW.source_id
		);

		IF (TG_OP = 'DELETE') THEN
			change_amount := -1;
		ELSE
			change_amount := 1;
		END IF;

		UPDATE sources
			SET num_images = num_images + change_amount
			WHERE id = NEW.source_id;

		UPDATE sites
			SET num_images = num_images + change_amount
			WHERE id = site_id;

		RETURN NEW;
	END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER update_num_images
	AFTER INSERT OR DELETE
		ON images
	FOR EACH ROW
	EXECUTE PROCEDURE update_num_images();

-- Maybe split this out so that a vote triggers an update in num_* for images (and users)
-- which triggers an update in num_* for that image's source, which triggers...
-- that would allow for a single function that we could just parametrize
CREATE FUNCTION update_num_votes_num_approved() RETURNS TRIGGER AS $$
	DECLARE
		votes_change_amount integer;
		approved_change_amount integer;
		source_id integer;
		site_id integer;
		vote votes;
	BEGIN

		IF (TG_OP = 'INSERT') THEN
			vote := NEW;
			votes_change_amount := 1;
			approved_change_amount := vote.vote::integer;
		ELSIF (TG_OP = 'DELETE') THEN
			vote := OLD;
			votes_change_amount := -1;
			approved_change_amount := (-1 * vote.vote::integer);
		ELSE -- UPDATE
			vote := NEW;
			votes_change_amount := 0;

			IF (NEW.vote) THEN
				approved_change_amount := 1;
			ELSE
				approved_change_amount := -1;
			END IF;
		END IF;

		source_id := (
			SELECT sources.id
				FROM sources
				JOIN images
					ON images.source_id = sources.id
				WHERE images.id = vote.image_id
		);

		site_id := (
			SELECT sites.id
				FROM sites
				JOIN sources
					ON sources.site_id = sites.id
				WHERE sources.id = source_id
		);

		UPDATE users
			SET
				num_votes = num_votes + votes_change_amount,
				num_approved = num_approved + approved_change_amount
			WHERE id = vote.user_id;

		UPDATE images
			SET
				num_votes = num_votes + votes_change_amount,
				num_approved = num_approved + approved_change_amount
			WHERE id = vote.image_id;

		UPDATE sources
			SET
				num_votes = num_votes + votes_change_amount,
				num_approved = num_approved + approved_change_amount
			WHERE id = source_id;

		UPDATE sites
			SET
				num_votes = num_votes + votes_change_amount,
				num_approved = num_approved + approved_change_amount
			WHERE id = site_id;

		RETURN NEW;
	END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER update_num_votes_num_approved
	AFTER INSERT OR DELETE OR UPDATE OF vote
		ON votes
	FOR EACH ROW
	EXECUTE PROCEDURE update_num_votes_num_approved();

-- raise errors for trying to manually set num_*
CREATE FUNCTION raise_error_on_num_modification() RETURNS TRIGGER AS $$
	BEGIN
		RAISE 'Do not modify num_* values yourself, they will be updated by the appropriate triggers';
		RETURN NULL;
	END;
$$ LANGUAGE PLPGSQL;

-- there has to be a better way NotLikeThis
CREATE TRIGGER raise_error_on_num_modification
	BEFORE UPDATE OF num_votes, num_approved
		ON images
	FOR EACH ROW
	WHEN (pg_trigger_depth() < 1)
	EXECUTE PROCEDURE raise_error_on_num_modification();

CREATE TRIGGER raise_error_on_num_modification
	BEFORE UPDATE OF num_votes, num_approved
		ON users
	FOR EACH ROW
	WHEN (pg_trigger_depth() < 1)
	EXECUTE PROCEDURE raise_error_on_num_modification();

CREATE TRIGGER raise_error_on_num_modification
	BEFORE UPDATE OF num_votes, num_approved, num_images
		ON sources
	FOR EACH ROW
	WHEN (pg_trigger_depth() < 1)
	EXECUTE PROCEDURE raise_error_on_num_modification();

CREATE TRIGGER raise_error_on_num_modification
	BEFORE UPDATE OF num_votes, num_approved, num_images
		ON sites
	FOR EACH ROW
	WHEN (pg_trigger_depth() < 1)
	EXECUTE PROCEDURE raise_error_on_num_modification();
