CREATE TABLE IF NOT EXISTS `withdraw_queue` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `timepoint` DATETIME NOT NULL,
  `user_id` $TYPE_USER_ID NOT NULL,
  `amount` $TYPE_MONEY UNSIGNED NOT NULL,
  `status` TINYINT NOT NULL DEFAULT $WITHDRAW_STATUS_IN_PROCESS,
  `account_info` VARCHAR(2048) NOT NULL, -- JSON
  PRIMARY KEY (`id`),
  INDEX status_idx (`status`, `timepoint`),
  INDEX user_status_idx (`user_id`, `status`),
  CONSTRAINT `withdraw_queue_user_id_fk` FOREIGN KEY (`user_id`)
    REFERENCES `accounts` (`user_id`)
    ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;


DELIMITER $$

DROP PROCEDURE IF EXISTS `withdraw_queue::put`$$
CREATE PROCEDURE `withdraw_queue::put`(user_id $TYPE_USER_ID, amount $TYPE_MONEY, account_info VARCHAR(2048))
BEGIN
  DECLARE timepoint DATETIME DEFAULT NOW();
  DECLARE record_id BIGINT;
  CALL `accounts::__lock_account` (user_id);

  INSERT INTO withdraw_queue (timepoint, user_id, amount, account_info)
    VALUES(timepoint, user_id, amount, account_info);

  SET record_id = LAST_INSERT_ID();
  CALL `accounts::__freeze_money`(user_id, amount);
  CALL `journal::put`('withdraw', record_id, user_id, $BANK_USER_ID, amount, $JOURNAL_STATUS_IN_PROCESS);
  SELECT record_id AS `id`;
END$$


DROP PROCEDURE IF EXISTS `withdraw_queue::get_all`$$
CREATE PROCEDURE `withdraw_queue::get_all` (lower_bound BIGINT, max_count INTEGER)
BEGIN
  SET max_count = IFNULL(max_count, 100);
  SET lower_bound = IFNULL(lower_bound, -1);

  SELECT
      q.id,
      q.status,
      q.user_id,
      q.timepoint,
      q.amount,
      q.account_info
    FROM withdraw_queue q WHERE q.status = $WITHDRAW_STATUS_IN_PROCESS AND q.id > lower_bound ORDER BY q.id LIMIT max_count; -- > array
END$$

DROP PROCEDURE IF EXISTS `withdraw_queue::get_one`$$
CREATE PROCEDURE `withdraw_queue::get_one`(record_id BIGINT)
BEGIN
  SELECT
      q.id,
      q.status,
      q.user_id,
      q.timepoint,
      q.amount,
      q.account_info
    FROM withdraw_queue q WHERE q.id = record_id;

  $ENSURE_FOUND(CONCAT("There is no record with ID: ", record_id));
END$$


DROP PROCEDURE IF EXISTS `withdraw_queue::get_for_user`$$
CREATE PROCEDURE `withdraw_queue::get_for_user`(user_id $TYPE_USER_ID)
BEGIN
  SELECT
      q.id,
      q.status,
      q.user_id,
      q.timepoint,
      q.amount,
      q.account_info
    FROM withdraw_queue q WHERE q.user_id = user_id; -- > array
END$$


DROP PROCEDURE IF EXISTS `withdraw_queue::complete`$$
CREATE PROCEDURE `withdraw_queue::complete`(record_id BIGINT)
main_scope:BEGIN
  DECLARE user_id $TYPE_USER_ID;
  DECLARE amount $TYPE_MONEY UNSIGNED;
  DECLARE q_status TINYINT;

  DECLARE CONTINUE HANDLER FOR NOT FOUND $THROW2("NotFound", "The record does not found. ID: ", record_id);

  SELECT q.user_id, q.amount INTO user_id, amount FROM withdraw_queue q WHERE q.id = record_id;

  -- the acount should be locked first, to avoid dead-lock
  CALL `accounts::__lock_account` (user_id);
  SELECT q.status INTO q_status FROM withdraw_queue q WHERE q.id = record_id FOR UPDATE;

  IF q_status = $WITHDRAW_STATUS_SUCCESS THEN
    LEAVE main_scope;
  ELSEIF q_status != $WITHDRAW_STATUS_IN_PROCESS THEN
    $THROW2("InternalError", "The record is inconsistent state. Please check journal. ID: ", record_id);
  END IF;

  CALL `accounts::__withdraw_money`(user_id, amount);

  UPDATE withdraw_queue q SET q.timepoint = NOW(), q.status = $WITHDRAW_STATUS_SUCCESS WHERE q.id = record_id;
  CALL `journal::put`('withdraw', record_id, user_id, $BANK_USER_ID, amount, $JOURNAL_STATUS_SUCCESS);
END$$


DROP PROCEDURE IF EXISTS `withdraw_queue::rollback`$$
CREATE PROCEDURE `withdraw_queue::rollback` (request_id BIGINT)
BEGIN
  DECLARE q_status TINYINT;
  DECLARE user_id $TYPE_USER_ID;
  DECLARE amount $TYPE_MONEY;

  DECLARE CONTINUE HANDLER FOR NOT FOUND $THROW2("NotFound", "The request does not found. ID: ", request_id);

  SELECT q.status, q.user_id, q.amount INTO q_status, user_id, amount
    FROM withdraw_queue q WHERE q.id = request_id FOR UPDATE;

  IF q_status = $WITHDRAW_STATUS_IN_PROCESS THEN
    UPDATE withdraw_queue q SET q.timepoint = NOW(), q.status = $WITHDRAW_STATUS_ROLLBACK WHERE q.id = request_id;
    CALL `accounts::__unfreeze_money`(user_id, amount);
    CALL `journal::put`('withdraw', request_id, user_id, $SYSTEM_USER_ID, amount, $JOURNAL_STATUS_ROLLBACK);
  END IF;
END$$


DROP PROCEDURE IF EXISTS `withdraw_queue::clean`$$
CREATE PROCEDURE `withdraw_queue::clean` (retention_period INTEGER)
BEGIN
  DECLARE expiration_date DATE DEFAULT NOW() - INTERVAL retention_period DAY;

  DROP TEMPORARY TABLE IF EXISTS __objects_ids;
  CREATE TEMPORARY TABLE IF NOT EXISTS __objects_ids (id BIGINT) ENGINE=MEMORY;

  INSERT INTO __objects_ids(id)
     (SELECT q.id FROM withdraw_queue q
        WHERE q.status IN ($WITHDRAW_STATUS_SUCCESS, $WITHDRAW_STATUS_ROLLBACK) AND q.timepoint <= expiration_date);

  DELETE FROM withdraw_queue WHERE withdraw_queue.id IN (SELECT __objects_ids.id FROM __objects_ids);
  CALL `journal::__delete`('withdraw');

  SELECT COUNT(1) AS `count` FROM __objects_ids;
END$$

DELIMITER ;
