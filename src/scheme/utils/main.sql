SET NAMES UTF8;

#if defined("DEBUG")
DROP DATABASE IF EXISTS `$DB_NAME`;
#endif

CREATE SCHEMA IF NOT EXISTS `$DB_NAME` DEFAULT CHARSET utf8 COLLATE utf8_unicode_ci;
ALTER DATABASE `$DB_NAME` DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;

USE `$DB_NAME`;

#if not defined("MAJOR")
#define MAJOR 1
#endif
#if not defined("MINOR")
#define MINOR 1
#endif
#if not defined("RELEASE")
#define RELEASE 1
#endif
