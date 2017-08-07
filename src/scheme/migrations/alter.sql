DELIMITER $$

DROP FUNCTION IF EXISTS `__index_exists`$$
CREATE FUNCTION `__index_exists`(`db` VARCHAR(100), `tbl` VARCHAR(50), `name` VARCHAR(50)) RETURNS BOOL READS SQL DATA
BEGIN
  RETURN EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS WHERE
    TABLE_SCHEMA=`db` COLLATE utf8_unicode_ci
    AND TABLE_NAME=`tbl` COLLATE utf8_unicode_ci
    AND INDEX_NAME=IF(`name` = 'PRIMARY KEY', 'PRIMARY', `name`) COLLATE utf8_unicode_ci);
END$$


DROP FUNCTION IF EXISTS `__column_exists`$$
CREATE FUNCTION `__column_exists`(`db` VARCHAR(100), `tbl` VARCHAR(50), `name` VARCHAR(50)) RETURNS BOOL READS SQL DATA
BEGIN
  RETURN EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE
    TABLE_SCHEMA=`db` COLLATE utf8_unicode_ci
    AND TABLE_NAME=`tbl` COLLATE utf8_unicode_ci
    AND COLUMN_NAME=`name` COLLATE utf8_unicode_ci);
END$$


DROP FUNCTION IF EXISTS `__foreign_key_exists`$$
CREATE FUNCTION `__foreign_key_exists`(`db` VARCHAR(100), `tbl` VARCHAR(50), `name` VARCHAR(50)) RETURNS BOOL READS SQL DATA
BEGIN
  RETURN EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE
    TABLE_SCHEMA=`db` COLLATE utf8_unicode_ci
    AND TABLE_NAME=`tbl` COLLATE utf8_unicode_ci
    AND CONSTRAINT_NAME=`name` COLLATE utf8_unicode_ci);
END$$


DROP FUNCTION IF EXISTS `__table_exists`$$
CREATE FUNCTION `__table_exists`(`db` VARCHAR(100), `tbl` VARCHAR(50)) RETURNS BOOL READS SQL DATA
BEGIN
  RETURN EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE
   TABLE_SCHEMA=`db` COLLATE utf8_unicode_ci
   AND TABLE_NAME=`tbl` COLLATE utf8_unicode_ci);
END$$


DROP PROCEDURE IF EXISTS `__execute_sql`$$
CREATE PROCEDURE `__execute_sql`()
BEGIN
    PREPARE statement FROM @sql;
    EXECUTE statement;
    DEALLOCATE PREPARE statement;
END$$


DROP PROCEDURE IF EXISTS `__create_index_if_not_exists`$$
CREATE PROCEDURE `__create_index_if_not_exists`(`scheme` VARCHAR(100), `table_name` VARCHAR(50), `index_name` VARCHAR(50), `unique` BOOL, fields VARCHAR(200))
BEGIN
  IF NOT __index_exists(`scheme`, `table_name`, `index_name`) THEN
    SET @sql = CONCAT('ALTER TABLE `', `scheme`, '`.', `table_name`, ' ADD ', IF(`index_name`  = 'PRIMARY KEY', 'PRIMARY KEY ', CONCAT(IF(`unique`, 'UNIQUE', ''), ' INDEX ', `index_name`)), '(', fields, ');');
    CALL __execute_sql();
  END IF;
END$$


DROP PROCEDURE IF EXISTS `__drop_index_if_exists`$$
CREATE PROCEDURE `__drop_index_if_exists`(`scheme` VARCHAR(100), `table_name` VARCHAR(50), `index_name` VARCHAR(50))
BEGIN
  IF __index_exists(`scheme`, `table_name`, `index_name`) THEN
    SET @sql = CONCAT('ALTER TABLE `', `scheme`, '`.', `table_name`, ' DROP ', IF(index_name  = 'PRIMARY KEY', 'PRIMARY KEY', CONCAT('INDEX ', `index_name`)), ';');
    CALL __execute_sql();
  END IF;
END$$


DROP PROCEDURE IF EXISTS `__create_column_if_not_exists`$$
CREATE PROCEDURE `__create_column_if_not_exists`(`scheme` VARCHAR(100), `table_name` VARCHAR(50), `column_name` VARCHAR(50), `description` VARCHAR(200))
BEGIN
  IF NOT __column_exists(`scheme`, `table_name`, `column_name`) THEN
    SET @sql = CONCAT('ALTER TABLE `', `scheme`, '`.', `table_name`, ' ADD COLUMN ', `column_name`, ' ', `description`, ';');
    CALL __execute_sql();
  END IF;
END$$


DROP PROCEDURE IF EXISTS `__drop_column_if_exists`$$
CREATE  PROCEDURE `__drop_column_if_exists`(`scheme` VARCHAR(100), `table_name` VARCHAR(50), `column_name` VARCHAR(50))
BEGIN
  IF __column_exists(`scheme`, `table_name`, `column_name`) THEN
    SET @sql = CONCAT('ALTER TABLE `', `scheme`, '`.`', `table_name`, '` DROP COLUMN `', `column_name`, '`;');
    CALL __execute_sql();
  END IF;
END$$


DROP PROCEDURE IF EXISTS `__modify_column_if_exists`$$
CREATE PROCEDURE `__modify_column_if_exists`(`scheme` VARCHAR(100), `table_name` VARCHAR(50), `column_name` VARCHAR(50), `modification` VARCHAR(200))
BEGIN
  IF __column_exists(`scheme`, `table_name`, `column_name`) THEN
    SET @sql = CONCAT('ALTER TABLE `', `scheme`, '`.`', `table_name`, '` CHANGE COLUMN `', `column_name`, '` ', `modification`, ';');
    CALL __execute_sql();
  END IF;
END$$


DROP PROCEDURE IF EXISTS `__execute_if_column_exists`$$
CREATE PROCEDURE `__execute_if_column_exists`(`scheme` VARCHAR(100), `table_name` VARCHAR(50), `column_name` VARCHAR(50), `script` VARCHAR(1024))
BEGIN
  IF __column_exists(`scheme`, `table_name`, `column_name`) THEN
    SET @sql = script;
    CALL __execute_sql();
  END IF;
END$$


DROP PROCEDURE IF EXISTS `__add_foreign_key_if_not_exists`$$
CREATE PROCEDURE `__add_foreign_key_if_not_exists`(`scheme` VARCHAR(100), `table_name` VARCHAR(50), `constraint_name` VARCHAR(50), `column_names` VARCHAR(255), `referenced_table_name` VARCHAR(50), `referenced_column_names` VARCHAR(255))
BEGIN
  IF NOT __foreign_key_exists(`scheme`, `table_name`, `constraint_name`) THEN
    SET @sql = CONCAT('ALTER TABLE `', `scheme`, '`.`', `table_name`, '` ADD CONSTRAINT `', `constraint_name`, '` FOREIGN KEY (', `column_names`, ') REFERENCES `', `referenced_table_name`, '` (', `referenced_column_names`, ');');
    CALL __execute_sql();
  END IF;
END$$

DROP PROCEDURE IF EXISTS `__drop_foreign_key_if_exists`$$
CREATE PROCEDURE `__drop_foreign_key_if_exists`(`scheme` VARCHAR(100), `table_name` VARCHAR(50), `constraint_name` VARCHAR(50))
BEGIN
  IF __foreign_key_exists(`scheme`, `table_name`, `constraint_name`) THEN
    SET @sql = CONCAT('ALTER TABLE `', `scheme`, '`.`', `table_name`, '` DROP FOREIGN KEY `', `constraint_name`, '`;');
    CALL __execute_sql();
  END IF;
END$$

DROP PROCEDURE IF EXISTS `__rename_table_if_exists`$$
CREATE PROCEDURE `__rename_table_if_exists`(`scheme` VARCHAR(100), `table_name` VARCHAR(50), `new_name` VARCHAR(50))
BEGIN
  IF __table_exists(`scheme`, `table_name`) THEN
    SET @sql = CONCAT('ALTER TABLE `', `scheme`, '`.`', `table_name`, '` RENAME TO `', `scheme`, '`.`', `new_name`, '`;');
    CALL __execute_sql();
  END IF;
END$$

DELIMITER ;
