# This SQL queries contained in this file will be executed on every database container startup.

# Required for timezones usage.
# This may be executed before automatic `glpi` user creation, so we retain the
# internal user identifier and apply it only to the IT Central database.
CREATE USER IF NOT EXISTS 'glpi'@'%' IDENTIFIED BY 'glpi';
SET PASSWORD FOR 'glpi'@'%' = PASSWORD('glpi');
