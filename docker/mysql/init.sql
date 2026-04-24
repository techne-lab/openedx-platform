-- MySQL initialisation script for edx-platform Docker development.
-- Creates the databases needed by LMS and CMS.

CREATE DATABASE IF NOT EXISTS edxapp
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS edxapp_csmh
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Grant full access to the edxapp user on both databases
GRANT ALL PRIVILEGES ON edxapp.* TO 'edxapp'@'%';
GRANT ALL PRIVILEGES ON edxapp_csmh.* TO 'edxapp'@'%';

FLUSH PRIVILEGES;
