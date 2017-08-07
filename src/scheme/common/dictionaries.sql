CREATE TABLE IF NOT EXISTS `dictionaries` (
    `key` VARCHAR(255) NOT NULL,
    `value` VARCHAR(4000) NULL,
    PRIMARY KEY (`key`)
);


DELIMITER $$

DROP PROCEDURE IF EXISTS `dictionaries.query`$$
CREATE PROCEDURE `dictionaries.query` (prefix VARCHAR(255))
BEGIN
  SELECT d.`key`, d.`value` FROM dictionaries d WHERE d.`key` LIKE CONCAT(prefix, '%'); -- > array
END$$


DROP PROCEDURE IF EXISTS `dictionaries.get`$$
CREATE PROCEDURE `dictionaries.get` (`key` VARCHAR(255))
BEGIN
  SELECT d.value FROM dictionaries d WHERE d.`key` = `key`;
  $ENSURE_FOUND(CONCAT("There is no value by key: ", `key`));
END$$


DROP PROCEDURE IF EXISTS `dictionaries.put`$$
CREATE PROCEDURE `dictionaries.put`(`key` VARCHAR(255), `value` VARCHAR(4000))
BEGIN
  INSERT INTO dictionaries (`key`, `value`) VALUES (`key`, `value`)
    ON DUPLICATE KEY UPDATE dictionaries.`value` = `value`;
END$$


DROP PROCEDURE IF EXISTS `dictionaries.delete`$$
CREATE PROCEDURE `dictionaries.delete` (`key` VARCHAR(255))
BEGIN
  DELETE FROM dictionaries WHERE dictionaries.`key` = `key`;
END$$

DELIMITER ;
