import uuid

from bim.models import accounts
from bim.models import constants
from bim.models import journal
from bim.models import payments
from bim.models import statistics
from tests.base import TestCase


class TestPayments(TestCase):
    def setUp(self):
        super().setUp()
        self.user_id, self.user_email = self.user_id_and_email()
        self.synchronize(accounts.put(self.connection, user_id=self.user_id, user_email=self.user_email))

    def test_make_payment(self):
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(0, account.balance)

        balance = self.synchronize(statistics.get_per_day(self.connection)).balance
        transaction = self.synchronize(payments.start_transaction(self.connection, self.user_id, 10, merchant_id="test"))
        self.assertGreater(transaction.id, 0)
        transaction = self.synchronize(payments.get_one(self.connection, transaction.id))
        self.assertEqual(constants.PAYMENT_STATUS_IN_PROCESS, transaction.status)
        self.assertEqual('test', transaction.merchant_id)
        record = self.synchronize(journal.get_all(self.connection, self.user_id))[0]
        self.assertEqual(constants.JOURNAL_STATUS_IN_PROCESS, record.status)
        active_payments = self.synchronize(payments.get_all(self.connection))
        self.assertEqual(transaction.id, active_payments[-1].id)
        self.assertEqual(constants.PAYMENT_STATUS_IN_PROCESS, active_payments[-1].status)
        with self.assertRaises(payments.exceptions.Forbidden):
            self.synchronize(payments.finish_transaction(self.connection, transaction.id, imi_amount=11, status=0))
        self.synchronize(payments.finish_transaction(self.connection, transaction.id, imi_amount=10, status=0))
        balance_after = self.synchronize(statistics.get_per_day(self.connection)).balance
        self.assertEqual(balance.total + 10, balance_after.total)
        self.assertEqual(balance.debit, balance_after.debit)
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(10, account.balance)
        record = self.synchronize(journal.get_all(self.connection, self.user_id))[0]
        self.assertEqual(constants.BANK_USER_ID, record.other_user_id)
        self.assertEqual(journal.ObjectClass.payments.value, record.object_class)
        self.assertEqual(transaction.id, record.object_id)
        self.assertEqual(10, record.amount)
        self.assertEqual(constants.JOURNAL_STATUS_SUCCESS, record.status)

    def test_no_payment_if_transaction_fail(self):
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(0, account.balance)

        transaction = self.synchronize(payments.start_transaction(self.connection, self.user_id, 10))
        self.synchronize(payments.finish_transaction(self.connection, transaction.id, 10, 1))
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(0, account.balance)
        record = self.synchronize(journal.get_all(self.connection, self.user_id))[0]
        self.assertEqual(constants.JOURNAL_STATUS_ERROR, record.status)

    def test_no_double_payment_for_one_transaction(self):
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(0, account.balance)

        transaction = self.synchronize(payments.start_transaction(self.connection, self.user_id, 10))
        self.synchronize(payments.finish_transaction(self.connection, transaction.id, 10, 0))
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(10, account.balance)
        self.synchronize(payments.finish_transaction(self.connection, transaction.id, 10, 0))
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(10, account.balance)
        records = self.synchronize(journal.get_all(self.connection, self.user_id))
        self.assertEqual(2, len(records))

    def test_fail_if_transaction_is_invalid(self):
        with self.assertRaises(payments.exceptions.NotFound):
            self.synchronize(payments.finish_transaction(self.connection, -1, 10, 0))

    def test_clean(self):
        transaction = self.synchronize(payments.start_transaction(self.connection, self.user_id, 10))
        self.synchronize(payments.finish_transaction(self.connection, transaction.id, imi_amount=10, status=0))
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(10, account.balance)
        self.synchronize(payments.finish_transaction(self.connection, transaction.id, imi_amount=10, status=0))
        transaction = self.synchronize(payments.get_one(self.connection, transaction.id))
        self.synchronize(payments.clean(self.connection, -1))
        with self.assertRaises(payments.exceptions.NotFound):
            self.synchronize(payments.get_one(self.connection, transaction.id))
        records = self.synchronize(journal.get_all(self.connection, self.user_id))
        obj_ids = {x.object_id for x in records if x.object_class == journal.ObjectClass.payments.value}
        self.assertNotIn(transaction.id, obj_ids)

    def test_payments_add_card_to_black_list_if_error(self):
        card_number = str(uuid.uuid4())
        transaction = self.synchronize(payments.start_transaction(self.connection, self.user_id, 10, card_number=card_number))
        self.synchronize(payments.finish_transaction(self.connection, transaction.id, imi_amount=10, status=constants.PAYMENT_STATUS_NOT_ENOUGH_MONEY))
        with self.assertRaisesRegex(payments.exceptions.Forbidden, 'ID: %s' % card_number):
            self.synchronize(payments.start_transaction(self.connection, self.user_id, 10, card_number=card_number))

        transaction = self.synchronize(payments.start_transaction(self.connection, self.user_id, 10, card_number=card_number, black_list_tolerance=1))
        self.synchronize(payments.finish_transaction(self.connection, transaction.id, imi_amount=10, status=constants.PAYMENT_STATUS_NOT_ENOUGH_MONEY))
        with self.assertRaisesRegex(payments.exceptions.Forbidden, 'ID: %s' % card_number):
            self.synchronize(payments.start_transaction(self.connection, self.user_id, 10, card_number=card_number, black_list_tolerance=1))

        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual(0, account.balance)

    def test_payments_rollback(self):
        transaction = self.synchronize(payments.start_transaction(self.connection, self.user_id, 100))
        self.synchronize(payments.finish_transaction(self.connection, transaction.id, 100, constants.PAYMENT_STATUS_SUCCESS))
        journal_record = self.synchronize(journal.get_all(self.connection, self.user_id))[0]
        result = self.synchronize(payments.rollback(self.connection, transaction.id))
        self.assertEqual(journal_record.id, result.journal.id)
        self.assertEqual(
            constants.PAYMENT_STATUS_ROLLBACK,
            self.synchronize(payments.get_one(self.connection, transaction.id)).status
        )
        with self.assertRaises(payments.exceptions.InternalError):
            self.synchronize(payments.rollback(self.connection, transaction.id))

    def test_payments_raise_on_count_limit(self):
        self.synchronize(payments.start_transaction(self.connection, self.user_id, 10))
        self.synchronize(payments.start_transaction(self.connection, self.user_id, 10))

        with self.assertRaisesRegex(payments.exceptions.Forbidden, 'Count limit exceeded %d' % 2):
            self.synchronize(payments.start_transaction(self.connection, self.user_id, 10, tries_per_day=1))