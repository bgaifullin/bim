CREATE TABLE IF NOT EXISTS `journal` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `from_user_id` $TYPE_USER_ID NOT NULL,
  `to_user_id` $TYPE_USER_ID NOT NULL,
  `amount` $TYPE_MONEY NOT NULL,
  `direction` TINYINT NOT NULL DEFAULT 1,  -- -1 or 1
  `timepoint` DATETIME NOT NULL,
  `status` TINYINT NOT NULL, -- see JOURNAL_STATUS_*,
  `object_class` ENUM('payments', 'withdraw'),
  `object_id` BIGINT,
  PRIMARY KEY (`id`),
  INDEX `user_direction_id_idx` (`from_user_id`, `direction`, `id`),
  INDEX `object_user_direction_idx` (`object_class`, `from_user_id`, `direction`, `object_id`),
  CONSTRAINT `from_user_fk` FOREIGN KEY (`from_user_id`)
    REFERENCES `accounts` (`user_id`)
    ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `to_user_fk` FOREIGN KEY (`to_user_id`)
    REFERENCES `accounts` (`user_id`)
    ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;


DELIMITER $$

DROP PROCEDURE IF EXISTS `journal::put`$$
CREATE PROCEDURE `journal::put` (
    object_class VARCHAR(24), object_id BIGINT,
    from_user_id $TYPE_USER_ID, to_user_id $TYPE_USER_ID, amount $TYPE_MONEY, status TINYINT
)
BEGIN
  DECLARE timepoint DATETIME DEFAULT NOW();

  -- spent money
  INSERT INTO journal (from_user_id, to_user_id, amount, direction, status, timepoint, object_class, object_id)
    VALUES(from_user_id, to_user_id, amount, -1, status, timepoint, object_class, object_id);

  -- earn money
  INSERT INTO journal (from_user_id, to_user_id, amount, direction, status, timepoint, object_class, object_id)
    VALUES(to_user_id, from_user_id, amount, 1, status, timepoint, object_class, object_id);
END$$


DROP FUNCTION  IF EXISTS __journal_get_last_id$$
CREATE FUNCTION __journal_get_last_id() RETURNS BIGINT READS SQL DATA
BEGIN
  DECLARE max_id BIGINT;
  SELECT MAX(journal.id) INTO max_id FROM journal;
  RETURN max_id + 1;
END$$


DROP PROCEDURE IF EXISTS `journal::__get_by_object`$$
CREATE PROCEDURE `journal::__get_by_object`(user_id $TYPE_USER_ID, object_class VARCHAR(20), object_id BIGINT, OUT id BIGINT)
BEGIN
  DECLARE CONTINUE HANDLER FOR NOT FOUND $THROW2("InternalError", "Journal record not found for object. ID: ", object_id);
  SELECT j.id INTO id FROM journal j
    WHERE j.from_user_id = user_id AND j.object_class = object_class AND j.object_id = object_id ORDER BY j.id DESC LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS `journal::get_payments_by_class`$$
CREATE PROCEDURE `journal::get_payments_by_class`(user_id $TYPE_USER_ID, class_name VARCHAR(20), lower_bound BIGINT)
BEGIN
  DECLARE first_id BIGINT;
  DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

  SET lower_bound = IFNULL(lower_bound, 0);

  SELECT j.object_id INTO first_id FROM journal j
    WHERE j.from_user_id = user_id AND j.id > lower_bound AND j.object_class = class_name ORDER BY j.id LIMIT 1;

  SELECT
      j.id,
      j.timepoint,
      j.from_user_id AS `user_id`,
      j.to_user_id AS `other_user_id`,
      j.amount,
      j.status,
      j.object_class,
      j.object_id
    FROM journal j
      WHERE j.id IN (
        SELECT MAX(j2.id) FROM journal j2
          WHERE j2.from_user_id = user_id AND j2.object_class = class_name AND j2.direction = -1 AND j2.object_id >= first_id
            GROUP BY j2.from_user_id, j2.object_class, j2.object_id
      ) AND j.status IN ($JOURNAL_STATUS_SUCCESS, $JOURNAL_STATUS_IN_PROCESS) ORDER BY j.id; -- > array
END$$


DROP PROCEDURE IF EXISTS `journal::get_all_payments`$$
CREATE PROCEDURE `journal::get_all_payments` (user_id $TYPE_USER_ID, lower_bound BIGINT)
BEGIN
  SET lower_bound = IFNULL(lower_bound, 0);

  SELECT
      j.id,
      j.timepoint,
      j.from_user_id AS `user_id`,
      j.to_user_id AS `other_user_id`,
      j.amount,
      j.status,
      j.object_class,
      j.object_id
    FROM journal j
    WHERE j.id IN (
        SELECT MAX(j2.id) FROM journal j2 WHERE j2.from_user_id = user_id AND j2.direction = -1 AND j2.id > lower_bound
          GROUP BY j2.from_user_id, j2.object_class, j2.object_id
      ) AND j.status IN ($JOURNAL_STATUS_SUCCESS, $JOURNAL_STATUS_IN_PROCESS) ORDER BY j.id; -- > array
END$$


DROP PROCEDURE IF EXISTS `journal::get_all`$$
CREATE PROCEDURE `journal::get_all` (user_id $TYPE_USER_ID, upper_bound BIGINT, max_count INTEGER)
BEGIN
  SET max_count = IFNULL(max_count, 100);
  SET upper_bound = IFNULL(upper_bound, __journal_get_last_id());

  SELECT
      journal.id,
      journal.timepoint,
      journal.from_user_id AS `user_id`,
      journal.to_user_id AS `other_user_id`,
      journal.amount * journal.direction AS `amount`,
      journal.status,
      journal.object_class,
      journal.object_id
    FROM journal
    WHERE journal.from_user_id = user_id AND journal.id < upper_bound ORDER BY journal.id DESC LIMIT max_count; -- > array
END$$


DROP PROCEDURE IF EXISTS `journal::__delete`$$
CREATE PROCEDURE `journal::__delete` (object_class VARCHAR(24))
BEGIN
  DELETE FROM journal
    WHERE journal.object_class = object_class AND
          object_id IN (SELECT __objects_ids.id FROM __objects_ids);
END$$


DROP PROCEDURE IF EXISTS `journal::poll`$$
CREATE PROCEDURE `journal::poll` (upper_bound BIGINT, max_count INT)
BEGIN
  SET max_count = IFNULL(max_count, 100);
  SET upper_bound = IFNULL(upper_bound, __journal_get_last_id());

  SELECT
      journal.id,
      journal.timepoint,
      journal.from_user_id AS `user_id`,
      journal.amount * journal.direction AS `amount`,
      journal.status,
      journal.object_class,
      journal.object_id
    FROM journal
    WHERE journal.id < upper_bound ORDER BY journal.id DESC LIMIT max_count; -- > array
END$$

DELIMITER ;
