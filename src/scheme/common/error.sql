DELIMITER $$

DROP PROCEDURE IF EXISTS `__throw`$$
CREATE PROCEDURE `__throw` (`class` VARCHAR(28), `message` VARCHAR(100))
BEGIN
	DECLARE message VARCHAR(129) DEFAULT CONCAT(`class`, ';', `message`);
	SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = message;
END$$

#define THROW(class, message) CALL __throw($class, $message)
#define THROW2(class, message, arg) CALL __throw($class, CONCAT($message, $arg))

#define ENSURE_FOUND(message) IF FOUND_ROWS() = 0 THEN $THROW("NotFound", $message); END IF
#define ENSURE_FOUND2(class, message) IF FOUND_ROWS() = 0 THEN $THROW($class, $message); END IF

DELIMITER ;
