CREATE TABLE IF NOT EXISTS `__changelog__` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `timestamp` DATETIME NOT NULL,
    `version`  VARCHAR(100) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE INDEX `version_idx` (`version`)
);

DELIMITER $$

DROP PROCEDURE IF EXISTS `__publish`$$
CREATE PROCEDURE `__publish` ()
BEGIN
  DECLARE EXIT HANDLER FOR $_ERR_DUP_ENTRY BEGIN END;

  INSERT INTO `__changelog__` (`timestamp`, `version`)
    VALUES(NOW(), CONCAT_WS('.', $MAJOR, $MINOR, $RELEASE));
   SELECT CONCAT_WS('.', $MAJOR, $MINOR, $RELEASE) AS `Current Version:`;
END$$

DELIMITER ;

CALL __publish();
