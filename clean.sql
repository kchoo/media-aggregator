DROP TRIGGER IF EXISTS log_event ON sites;
DROP TRIGGER IF EXISTS log_event ON sources;
DROP TRIGGER IF EXISTS log_event ON images;
DROP TRIGGER IF EXISTS log_event ON users;
DROP TRIGGER IF EXISTS log_event ON votes;
DROP FUNCTION IF EXISTS log_event();

DROP TABLE IF EXISTS logs;

DROP TYPE IF EXISTS action;
DROP TYPE IF EXISTS table_name;

DROP TRIGGER IF EXISTS raise_error_on_num_modification ON sites;
DROP TRIGGER IF EXISTS raise_error_on_num_modification ON sources;
DROP TRIGGER IF EXISTS raise_error_on_num_modification ON images;
DROP TRIGGER IF EXISTS raise_error_on_num_modification ON users;
DROP FUNCTION IF EXISTS raise_error_on_num_modification();

DROP TRIGGER IF EXISTS update_num_votes_num_approved ON votes;
DROP FUNCTION IF EXISTS update_num_votes_num_approved();

DROP TRIGGER IF EXISTS update_num_images ON images;
DROP FUNCTION IF EXISTS update_num_images();

DROP TRIGGER IF EXISTS update_image_date_uploaded ON images;
DROP FUNCTION IF EXISTS update_image_date_uploaded();

DROP TABLE IF EXISTS votes;
DROP TABLE IF EXISTS users;

DROP INDEX IF EXISTS images_source_id_idx;
DROP INDEX IF EXISTS images_md5_idx;

DROP TABLE IF EXISTS images;

DROP INDEX IF EXISTS sources_state_idx;
DROP INDEX IF EXISTS sources_last_refreshed_idx;

DROP TABLE IF EXISTS sources;
DROP TABLE IF EXISTS source_states;
DROP TABLE IF EXISTS sites;

DROP DOMAIN IF EXISTS media_file;
DROP DOMAIN IF EXISTS url;
DROP DOMAIN IF EXISTS uint;
