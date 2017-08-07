CREATE TABLE IF NOT EXISTS `accounts` (
  `user_id` $TYPE_USER_ID NOT NULL,
  `email` $TYPE_USER_EMAIL NOT NULL,
  `balance` $TYPE_MONEY UNSIGNED NOT NULL DEFAULT 0,
  `frozen` $TYPE_MONEY UNSIGNED NOT NULL DEFAULT 0,
  `status` TINYINT NOT NULL DEFAULT $ACCOUNT_STATUS_ACTIVE,
  PRIMARY KEY (`user_id`),
  UNIQUE INDEX `email_idx` (`email`)
) ENGINE=InnoDB;

-- Null Account
INSERT IGNORE INTO accounts(`user_id`, `email`) VALUES($NULL_USER_ID, '');

-- System Account
INSERT IGNORE INTO accounts(`user_id`, `email`) VALUES($SYSTEM_USER_ID, $SYSTEM_USER_ID);

-- External Payment Account
INSERT IGNORE INTO accounts(`user_id`, `email`) VALUES($BANK_USER_ID, $BANK_USER_ID);

-- Money aggregator
INSERT IGNORE INTO accounts(`user_id`, `email`) VALUES($AGGREGATOR_ID, $AGGREGATOR_ID);


DELIMITER $$

DROP PROCEDURE IF EXISTS `accounts::put`$$
CREATE PROCEDURE `accounts::put` (user_id $TYPE_USER_ID, user_email $TYPE_USER_EMAIL)
BEGIN
  DECLARE account_exists BOOL DEFAULT FALSE;
  DECLARE CONTINUE HANDLER FOR $_ERR_DUP_ENTRY SET account_exists = TRUE;

  INSERT INTO accounts (user_id, email) VALUES(user_id, user_email);
  SELECT accounts.user_id FROM accounts WHERE accounts.email = user_email;
  $ENSURE_FOUND2("Conflict", "Duplicate user_id");
END$$


DROP PROCEDURE IF EXISTS `accounts::get`$$
CREATE PROCEDURE `accounts::get` (user_id $TYPE_USER_ID)
BEGIN
  SELECT
        accounts.user_id,
        accounts.balance,
        accounts.frozen,
        accounts.status
    FROM accounts
    WHERE accounts.user_id = user_id;

  $ENSURE_FOUND(CONCAT("There is no account for user. ID: ", user_id));
END$$


DROP PROCEDURE IF EXISTS `accounts::__lock_account`$$
CREATE PROCEDURE `accounts::__lock_account` (user_id $TYPE_USER_ID)
BEGIN
  DECLARE CONTINUE HANDLER FOR NOT FOUND $THROW2("NotFound", "The account for user does not found. ID: ", IFNULL(user_id, 'null'));

  SELECT a.user_id INTO user_id FROM accounts a WHERE a.user_id = user_id FOR UPDATE;
END$$


DROP PROCEDURE IF EXISTS `accounts::__lock_account2`$$
CREATE PROCEDURE `accounts::__lock_account2` (user1_id $TYPE_USER_ID, user2_id $TYPE_USER_ID)
BEGIN
  -- always lock in same order to prevent dead-lock
  IF user1_id < user2_id THEN
     CALL `accounts::__lock_account`(user1_id);
     CALL `accounts::__lock_account`(user2_id);
  ELSE
     CALL `accounts::__lock_account`(user2_id);
     CALL `accounts::__lock_account`(user1_id);
  END IF;
END$$


DROP PROCEDURE IF EXISTS `accounts::lock_accounts`$$
CREATE PROCEDURE `accounts::lock_accounts` () COMMENT "__user_ids (user_id $TYPE_USER_ID);"
BEGIN
  SELECT a.user_id FROM accounts a
    WHERE a.user_id IN (SELECT __user_ids.user_id FROM __user_ids) ORDER BY a.user_id FOR UPDATE; -- > array
END$$


DROP PROCEDURE IF EXISTS `accounts::__ensure_enough_money`$$
CREATE PROCEDURE `accounts::__ensure_enough_money` (user_id $TYPE_USER_ID, amount $TYPE_MONEY)
BEGIN
  DECLARE account_balance $TYPE_MONEY UNSIGNED;
  -- The account should be locked (move lock to outside for optimization)
  SELECT accounts.balance INTO account_balance FROM accounts WHERE accounts.user_id = user_id;

  IF account_balance < amount THEN
    $THROW2("NotEnoughMoney", "There is not enough money in balance. ID: ", user_id);
  END IF;
END$$


DROP PROCEDURE IF EXISTS `accounts::__freeze_money_safe`$$
CREATE PROCEDURE `accounts::__freeze_money_safe` (user_id $TYPE_USER_ID, amount $TYPE_MONEY, OUT succeed BOOL)
BEGIN
  DECLARE account_balance $TYPE_MONEY UNSIGNED;

  -- The account should be locked (move lock to outside for optimization)

  UPDATE accounts SET
     accounts.balance = IF(@__freeze_money_succeed := accounts.balance >= amount, accounts.balance - amount, accounts.balance),
     accounts.frozen = accounts.frozen + amount
  WHERE accounts.user_id = user_id;

  SET succeed = @__freeze_money_succeed;
END$$


DROP PROCEDURE IF EXISTS `accounts::__freeze_money`$$
CREATE PROCEDURE `accounts::__freeze_money` (user_id $TYPE_USER_ID, amount $TYPE_MONEY)
BEGIN
  DECLARE succeed BOOL;
  CALL `accounts::__freeze_money_safe`(user_id, amount, succeed);
  IF NOT succeed THEN
    $THROW2("NotEnoughMoney", "There is not enough money in balance. ID: ", user_id);
  END IF;
END$$

DROP PROCEDURE IF EXISTS `accounts::__unfreeze_money`$$
CREATE PROCEDURE `accounts::__unfreeze_money` (user_id $TYPE_USER_ID, amount $TYPE_MONEY)
BEGIN
  UPDATE accounts SET
      accounts.balance = accounts.balance + amount,
      accounts.frozen = IF(@__unfreeze_money_succeed := accounts.frozen >= amount, accounts.frozen - amount, accounts.frozen)
    WHERE accounts.user_id = user_id;

  IF NOT @__unfreeze_money_succeed THEN
    $THROW2("InternalError", "There is not enough frozen money. ID: ", user_id);
  END IF;
END$$

DROP PROCEDURE IF EXISTS `accounts::__transfer_money`$$
CREATE PROCEDURE `accounts::__transfer_money` (from_user_id $TYPE_USER_ID, to_user_id $TYPE_USER_ID, amount $TYPE_MONEY)
BEGIN
  -- The account should be locked (move lock to outside for optimization)
  -- transfer to and from skrill is handled as special case

  UPDATE accounts SET
      accounts.frozen = IF(@__transfer_money_succeed := accounts.frozen >= amount, accounts.frozen - amount, accounts.frozen)
    WHERE accounts.user_id = from_user_id;

  IF NOT @__transfer_money_succeed THEN
    $THROW2("InternalError", "The money should be frozen before transfer. ID: ", from_user_id);
  END IF;

  UPDATE accounts SET accounts.balance = accounts.balance + amount WHERE accounts.user_id = to_user_id;
END$$


DROP PROCEDURE IF EXISTS `accounts::__enter_money`$$
CREATE PROCEDURE `accounts::__enter_money` (user_id $TYPE_USER_ID, amount $TYPE_MONEY)
BEGIN
  -- The account should be locked (move lock to outside for optimization)
  -- transfer to and from skrill is handled as special case

  UPDATE accounts SET accounts.balance = accounts.balance + amount WHERE accounts.user_id = user_id;

  -- update aggregator
  UPDATE accounts SET accounts.balance = accounts.balance + amount WHERE accounts.user_id = $AGGREGATOR_ID;
END$$


DROP PROCEDURE IF EXISTS `accounts::__withdraw_money`$$
CREATE PROCEDURE `accounts::__withdraw_money` (user_id $TYPE_USER_ID, amount $TYPE_MONEY)
BEGIN
  -- The account should be locked (move lock to outside for optimization)
  -- transfer to and from skrill is handled as special case

  UPDATE accounts SET
    accounts.frozen = IF(@__withdraw_money_succeed := accounts.frozen >= amount, accounts.frozen - amount, accounts.frozen)
    WHERE accounts.user_id = user_id;

  IF NOT @__withdraw_money_succeed THEN
    $THROW2("InternalError", "The money should be frozen before. ID: ", user_id);
  END IF;

  -- update overal progress
  UPDATE accounts SET accounts.balance = accounts.balance - amount WHERE accounts.user_id = $AGGREGATOR_ID;
END$$


DROP PROCEDURE IF EXISTS `accounts::__cash_back`$$
CREATE PROCEDURE `accounts::__cash_back`(user_id $TYPE_USER_ID, amount $TYPE_MONEY)
BEGIN
  UPDATE accounts a SET a.balance = a.balance +  amount WHERE a.user_id = user_id;
END$$


DROP PROCEDURE IF EXISTS `accounts::chargeback`$$
CREATE PROCEDURE `accounts::chargeback` (user_id $TYPE_USER_ID, amount $TYPE_MONEY)
BEGIN
  DECLARE account_balance $TYPE_MONEY UNSIGNED;
  DECLARE CONTINUE HANDLER FOR NOT FOUND $THROW2("NotFound", "The account for user does not found. ID: ", IFNULL(user_id, 'null'));

  SELECT a.balance INTO account_balance FROM accounts a WHERE a.user_id = user_id FOR UPDATE;
  IF account_balance > amount THEN
    SET account_balance = account_balance - amount;
    SET amount = 0;
  ELSE
    SET amount = amount - account_balance;
    SET account_balance = 0;
  END IF;

  UPDATE accounts a SET a.balance = account_balance WHERE a.user_id = user_id;
  SELECT amount AS `credit`;
END$$


DROP PROCEDURE IF EXISTS `accounts::block`$$
CREATE PROCEDURE `accounts::block`(user_id $TYPE_USER_ID)
BEGIN
  CALL `accounts::__lock_account`(user_id);
  UPDATE accounts SET status = $ACCOUNT_STATUS_FROZEN WHERE accounts.user_id = user_id;
END$$


DROP PROCEDURE IF EXISTS `accounts::adjust_total_balance`$$
CREATE PROCEDURE `accounts::adjust_total_balance`(amount $TYPE_MONEY)
BEGIN
  UPDATE accounts SET accounts.balance = accounts.balance - amount WHERE accounts.user_id = $AGGREGATOR_ID;
END$$

DELIMITER ;
