#if defined("DEBUG")

DROP TABLE IF EXISTS `trace_log`;
CREATE TABLE `trace_log` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `timestamp` TIMESTAMP(4) NOT NULL,
    `message` VARCHAR(4000),
    PRIMARY KEY (`id`)
);

DELIMITER $$
DROP PROCEDURE IF EXISTS `__trace`$$
CREATE PROCEDURE `__trace` (message VARCHAR(4000))
BEGIN
  INSERT INTO `trace_log` (`timestamp`, `message`) VALUES(CURRENT_TIMESTAMP(), message);
END$$

DELIMITER ;

#define TRACE(message) CALL __trace($message);
#else
#define TRACE(message)
#endif
