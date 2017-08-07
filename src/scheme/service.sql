CREATE TABLE IF NOT EXISTS `services` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `description` VARCHAR(255),
  `price` $TYPE_MONEY UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

DELIMITER $$


DROP PROCEDURE IF EXISTS `services::put`$$
CREATE PROCEDURE `services::put` (description VARCHAR(255), price $TYPE_MONEY)
BEGIN
END$$


DROP PROCEDURE IF EXISTS `subscriptions::rollback`$$
CREATE PROCEDURE `subscriptions::rollback` (subscription_id BIGINT, amount $TYPE_MONEY, payment_date DATE)
BEGIN
  DECLARE type TINYINT;
  DECLARE user_id $TYPE_USER_ID;

  DECLARE CONTINUE HANDLER FOR NOT FOUND $THROW2("NotFound", "The subscription does not found. ID: ", subscription_id);

  -- the user should be locked
  SELECT s.type, s.user_id INTO type, user_id FROM subscriptions s WHERE s.id = subscription_id FOR UPDATE;

  IF type = $SUBSCRIPTIONS_TYPE_PRE_PAID THEN
    UPDATE subscriptions s SET
        s.active = NULL, s.end_date = payment_date, s.next_payment = payment_date + INTERVAL 1 DAY
      WHERE s.id = subscription_id;
  ELSEIF type = $SUBSCRIPTIONS_TYPE_POST_PAID THEN
    UPDATE subscriptions s SET
        s.frozen_date = LEAST(IFNULL(s.frozen_date, payment_date), payment_date), s.next_payment = payment_date
      WHERE s.id = subscription_id;
  END IF;

  CALL `journal::put`('subscriptions', subscription_id, user_id, $SYSTEM_USER_ID, amount, $JOURNAL_STATUS_ROLLBACK);
  CALL `accounts::__freeze_money`($SYSTEM_USER_ID, amount);
  CALL `accounts::__transfer_money`($SYSTEM_USER_ID, user_id, amount);
END$$


DROP PROCEDURE IF EXISTS `subscriptions::__process`$$
CREATE PROCEDURE `subscriptions::__process` (subscription_id BIGINT, OUT user_id $TYPE_USER_ID, OUT result INTEGER)
main_scope:BEGIN
    DECLARE succeed BOOL DEFAULT FALSE;
    DECLARE type TINYINT;
    DECLARE payment_period INTEGER;
    DECLARE price $TYPE_MONEY;
    DECLARE next_payment DATE;
    DECLARE end_date DATE;
    DECLARE frozen_date DATE;
    DECLARE today DATE DEFAULT CURRENT_DATE();

    DECLARE CONTINUE HANDLER FOR NOT FOUND $THROW2("NotFound", "The subscription does not found. ID: ", subscription_id);

    SELECT s.user_id, s.type, s.price, s.payment_period, s.next_payment, s.end_date, s.frozen_date
      INTO user_id, type, price, payment_period, next_payment, end_date, frozen_date
      FROM subscriptions s WHERE s.id = subscription_id;

    -- keep locking order, first account, second subscription
    CALL `accounts::__lock_account` (user_id);
    SELECT s.user_id INTO user_id FROM subscriptions s WHERE s.id = subscription_id FOR UPDATE;

    IF frozen_date IS NULL AND end_date < today THEN
      -- mark as inactive
      UPDATE subscriptions SET active = NULL WHERE subscriptions.id = subscription_id;
      SET result = $SUBSCRIPTIONS_PROCESS_RESULT_DELETED;
      LEAVE main_scope;
    END IF;

    IF type != $SUBSCRIPTIONS_TYPE_POST_PAID OR next_payment > today THEN
      SET result = $SUBSCRIPTIONS_PROCESS_RESULT_NOP;
      LEAVE main_scope;
    END IF;

    IF frozen_date IS NOT NULL THEN
      SET end_date = end_date + INTERVAL DATEDIFF(today, frozen_date) DAY;
    END IF;

    IF next_payment > end_date THEN
      -- adjust last payment
      SET price = price - FLOOR((DATEDIFF(next_payment, end_date) * price) / payment_period);
      SET next_payment = end_date;
    END IF;

    IF next_payment = end_date THEN
      -- drop subscription on next day after end
      SET next_payment = next_payment + INTERVAL 1 DAY;
    ELSE
      SET next_payment = next_payment + INTERVAL payment_period DAY;
    END IF;

    CALL `accounts::__freeze_money_safe`(user_id, price, succeed);
    IF succeed THEN
      SET result = $SUBSCRIPTIONS_PROCESS_RESULT_PAID;
      CALL `accounts::__transfer_money`(user_id, $SYSTEM_USER_ID, price);
      CALL `journal::put`('subscriptions', subscription_id, user_id, $SYSTEM_USER_ID, price, $JOURNAL_STATUS_SUCCESS);
      UPDATE subscriptions SET
          subscriptions.next_payment = next_payment,
          subscriptions.frozen_date = NULL,
          subscriptions.end_date = end_date
        WHERE subscriptions.id = subscription_id;
    ELSE
      -- freeze subscription
      SET result = $SUBSCRIPTIONS_PROCESS_RESULT_FROZE;
      UPDATE subscriptions s SET s.frozen_date = IFNULL(s.frozen_date, today) WHERE s.id = subscription_id;
    END IF;
END$$


DROP PROCEDURE IF EXISTS `subscriptions::process`$$
CREATE PROCEDURE `subscriptions::process` (subscription_id BIGINT)
BEGIN
  DECLARE user_id $TYPE_USER_ID;
  DECLARE code INTEGER;

  CALL `subscriptions::__process`(subscription_id, user_id, code);
  SELECT user_id, code;
END$$


DROP PROCEDURE IF EXISTS `subscriptions::get_wait_for_payment`$$
CREATE PROCEDURE `subscriptions::get_wait_for_payment` (max_count INTEGER)
BEGIN
  DECLARE today DATE DEFAULT CURRENT_DATE();
  SET max_count = IFNULL(max_count, 100);
  SELECT s.id FROM subscriptions s
    WHERE s.active AND s.next_payment <= today AND s.frozen_date IS NULL LIMIT max_count; -- > array
END$$


DROP PROCEDURE IF EXISTS `subscriptions::get_all`$$
CREATE PROCEDURE `subscriptions::get_all` (user_id $TYPE_USER_ID)
BEGIN
  DECLARE today DATE DEFAULT CURRENT_DATE();
  SELECT
      s.id, s.type, s.price, s.payment_period, s.frozen_date,
      IF(s.next_payment > s.end_date, NULL, s.next_payment) AS `next_payment`,
      s.end_date + INTERVAL DATEDIFF(today, IFNULL(s.frozen_date, today)) DAY AS `end_date`
  FROM subscriptions s
    WHERE s.user_id = user_id AND s.active AND (frozen_date IS NOT NULL OR end_date >= today); -- > array
END$$


DROP PROCEDURE IF EXISTS `subscriptions::get_one`$$
CREATE PROCEDURE `subscriptions::get_one` (subscription_id BIGINT)
BEGIN
  DECLARE today DATE DEFAULT CURRENT_DATE();

  SELECT
      s.id, s.type, s.active, s.price, s.payment_period, s.frozen_date,
      IF(s.next_payment > s.end_date, NULL, s.next_payment) AS `next_payment`,
      s.end_date + INTERVAL DATEDIFF(today, IFNULL(s.frozen_date, today)) DAY AS `end_date`
  FROM subscriptions s WHERE s.id = subscription_id;

  $ENSURE_FOUND(CONCAT("There is no subscription with ID: ", subscription_id));
END$$


DROP PROCEDURE IF EXISTS `subscriptions::get_count`$$
CREATE PROCEDURE `subscriptions::get_count` (user_id $TYPE_USER_ID)
BEGIN
  DECLARE today DATE DEFAULT CURRENT_DATE();
  SELECT COUNT(1) AS `total` FROM subscriptions s
    WHERE s.user_id = user_id AND s.active AND (frozen_date IS NOT NULL OR end_date >= today);
END$$


DROP PROCEDURE IF EXISTS `subscriptions::clean`$$
CREATE PROCEDURE `subscriptions::clean` (retention_period INTEGER)
BEGIN
  DECLARE expiration_date DATE DEFAULT CURRENT_DATE() - INTERVAL retention_period DAY;

  DROP TEMPORARY TABLE IF EXISTS __objects_ids;
  CREATE TEMPORARY TABLE IF NOT EXISTS __objects_ids (id BIGINT) ENGINE=MEMORY;

  INSERT INTO __objects_ids(id)
     (SELECT s.id FROM subscriptions s WHERE s.end_date <= expiration_date AND s.frozen_date IS NULL);

  DELETE FROM subscriptions WHERE subscriptions.id IN (SELECT __objects_ids.id FROM __objects_ids);
  CALL `journal::__delete`('subscriptions');

  SELECT COUNT(1) AS `count` FROM __objects_ids;
END$$

DELIMITER ;
