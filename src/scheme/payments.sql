CREATE TABLE IF NOT EXISTS `payments` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `timepoint` DATETIME NOT NULL,
  `user_id` $TYPE_USER_ID NOT NULL,
  `imi_amount` $TYPE_MONEY UNSIGNED NOT NULL,
  `status` TINYINT NOT NULL,
  `card_number` VARCHAR(255),
  `merchant_id` VARCHAR(255),
  `details` VARCHAR(2048), -- JSON
  PRIMARY KEY (`id`),
  INDEX `status_id_idx` (`status`, `id`),
  INDEX `timepoint_idx` (`timepoint`),
  INDEX `user_time_idx` (`user_id`, `timepoint`),
  CONSTRAINT `user_id_idx` FOREIGN KEY (`user_id`)
    REFERENCES `accounts` (`user_id`)
    ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;

DELIMITER $$


DROP PROCEDURE IF EXISTS `payments::__tries_check`$$
CREATE PROCEDURE `payments::__tries_check` (user_id $TYPE_USER_ID, tries_per_day INTEGER)
BEGIN
  DECLARE errors_count INTEGER DEFAULT 0;

  SELECT COUNT(1) INTO errors_count FROM payments p WHERE
    p.user_id = user_id AND
    p.timepoint > NOW() - INTERVAL 1 DAY;

  IF errors_count > tries_per_day THEN
    $THROW2("Forbidden", "Count limit exceeded ", errors_count);
  END IF;
END$$


DROP PROCEDURE IF EXISTS `payments::start_transaction`$$
CREATE PROCEDURE `payments::start_transaction` (user_id $TYPE_USER_ID, imi_amount $TYPE_MONEY, card_number VARCHAR(255), merchant_id VARCHAR(255), details VARCHAR(2048), black_list_tolerance INTEGER, tries_per_day INTEGER)
BEGIN
  DECLARE transaction_id BIGINT;
  DECLARE account_status TINYINT;
  DECLARE CONTINUE HANDLER FOR NOT FOUND $THROW2("NotFound", "The account for user does not found. ID: ", IFNULL(user_id, 'null'));

  IF card_number IS NOT NULL THEN
    CALL `__black_list_check_card`(card_number, IFNULL(black_list_tolerance, 0));
  END IF;

  IF tries_per_day IS NOT NULL THEN
     CALL `payments::__tries_check`(user_id, tries_per_day);
  END IF;

  SELECT a.status INTO account_status FROM accounts a WHERE a.user_id = user_id;

  IF account_status = $ACCOUNT_STATUS_FROZEN THEN
    $THROW2("AccountBlocked", "The account is blocked, please contact support to remove block: ", user_id);
  END IF;

  INSERT INTO payments (`user_id`, `timepoint`, imi_amount, `status`, `card_number`, `merchant_id`, `details`)
    VALUES(user_id, NOW(), imi_amount, $PAYMENT_STATUS_IN_PROCESS, card_number, merchant_id, details);

  SET transaction_id = LAST_INSERT_ID();
  CALL `journal::put`('payments', transaction_id, $BANK_USER_ID, user_id, imi_amount, $JOURNAL_STATUS_IN_PROCESS);
  SELECT transaction_id AS `id`;
END$$


DROP PROCEDURE IF EXISTS `payments::finish_transaction`$$
CREATE PROCEDURE `payments::finish_transaction` (
  transaction_id BIGINT, imi_amount $TYPE_MONEY, status INTEGER, details VARCHAR(2048)
)
main_scope:BEGIN
  DECLARE user_id $TYPE_USER_ID;
  DECLARE declared_amount $TYPE_MONEY UNSIGNED;
  DECLARE payment_status TINYINT;
  DECLARE card_number VARCHAR(255);
  DECLARE CONTINUE HANDLER FOR NOT FOUND $THROW2("NotFound", "The transaction does not found. ID: ", IFNULL(transaction_id, 'null'));

  SELECT p.user_id, p.imi_amount, p.status, p.card_number INTO user_id, declared_amount, payment_status, card_number
    FROM payments p WHERE p.id = transaction_id FOR UPDATE;

  IF payment_status != $PAYMENT_STATUS_IN_PROCESS THEN
    LEAVE main_scope;
  END IF;

  IF declared_amount != imi_amount THEN
    $THROW2("Forbidden", "The transaction sum mismatch. ID: ", transaction_id);
  END IF;

  CALL `accounts::__lock_account`(user_id);

  UPDATE payments SET
      payments.timepoint = NOW(),
      payments.imi_amount = imi_amount,
      payments.status = status,
      payments.details = details
    WHERE payments.id = transaction_id;

  IF status = $PAYMENT_STATUS_SUCCESS THEN
    CALL `journal::put`('payments', transaction_id, $BANK_USER_ID, user_id, imi_amount, $JOURNAL_STATUS_SUCCESS);
    CALL `accounts::__enter_money`(user_id, imi_amount);
  ELSE
    CALL `journal::put`('payments', transaction_id, $BANK_USER_ID, user_id, imi_amount, $JOURNAL_STATUS_ERROR);
    IF (card_number IS NOT NULL) AND (status = $PAYMENT_STATUS_NOT_ENOUGH_MONEY) THEN
      CALL `__black_list_add_card`(card_number);
    END IF;
  END IF;
END$$

DROP PROCEDURE IF EXISTS `payments::rollback`$$
CREATE PROCEDURE `payments::rollback` (transaction_id BIGINT)
BEGIN
  DECLARE journal_id BIGINT;
  DECLARE user_id $TYPE_USER_ID;
  DECLARE amount $TYPE_MONEY UNSIGNED;
  DECLARE status TINYINT;

  DECLARE CONTINUE HANDLER FOR NOT FOUND $THROW2("NotFound", "The transaction does not found. ID: ", IFNULL(transaction_id, 'null'));

  SELECT p.user_id, p.imi_amount, p.status INTO user_id, amount, status FROM payments p WHERE p.id = transaction_id FOR UPDATE;

  IF status != $PAYMENT_STATUS_SUCCESS THEN
    $THROW2("InternalError", "The transaction is not completed successfully. ID: ", transaction_id);
  END IF;

  CALL `journal::__get_by_object`(user_id, 'payments', transaction_id, journal_id);

  UPDATE payments SET payments.status = $PAYMENT_STATUS_ROLLBACK WHERE payments.id = transaction_id;
  CALL `journal::put`('payments', transaction_id, $BANK_USER_ID, user_id, amount, $JOURNAL_STATUS_ROLLBACK);

  SELECT
    transaction_id AS `id`,
    user_id,
    amount,
    status,
    journal_id AS `journal.id`;
END$$


DROP PROCEDURE IF EXISTS `payments::get_one`$$
CREATE PROCEDURE `payments::get_one` (transaction_id BIGINT)
BEGIN
  SELECT
      p.id,
      p.timepoint,
      p.imi_amount,
      p.status,
      p.merchant_id,
      p.details
    FROM payments p
    WHERE p.id = transaction_id;

    $ENSURE_FOUND(CONCAT("There is no transaction with ID: ", transaction_id));
END$$


DROP PROCEDURE IF EXISTS `payments::get_all`$$
CREATE PROCEDURE `payments::get_all` (lower_bound BIGINT, max_count INTEGER)
BEGIN
  SET max_count = IFNULL(max_count, 100);
  SET lower_bound = IFNULL(lower_bound, -1);

  SELECT
      p.id,
      p.timepoint,
      p.imi_amount,
      p.status,
      p.merchant_id,
      p.user_id,
      p.details
    FROM payments p
    WHERE p.status = $PAYMENT_STATUS_IN_PROCESS AND p.id > lower_bound ORDER BY p.id LIMIT max_count; -- > array
END$$


DROP PROCEDURE IF EXISTS `payments::clean`$$
CREATE PROCEDURE `payments::clean`(retention_period INTEGER)
BEGIN
  DECLARE expiration_date DATE DEFAULT NOW() - INTERVAL retention_period DAY;

  DROP TEMPORARY TABLE IF EXISTS __objects_ids;
  CREATE TEMPORARY TABLE IF NOT EXISTS __objects_ids (id BIGINT) ENGINE=MEMORY;

  INSERT INTO __objects_ids(id)
     (SELECT p.id FROM payments p WHERE p.timepoint <= expiration_date);

  DELETE FROM payments WHERE payments.id IN (SELECT __objects_ids.id FROM __objects_ids);
  CALL `journal::__delete`('payments');

  SELECT COUNT(1) AS `count` FROM __objects_ids;
END$$

DELIMITER ;
