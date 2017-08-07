import datetime

from bim import actions
from bim.models import accounts
from bim.models import constants
from bim.models import journal
from bim.models import payments
from bim.models import statistics
from bim.models import withdraw_queue
from tests.base import TestCase


class TestPaymentsActions(TestCase):
    def setUp(self):
        self.today = datetime.date.today()
        self.user_id, self.user_email = self.user_id_and_email()
        self.synchronize(accounts.put(self.connection, user_id=self.user_id, user_email=self.user_email))

    def test_rollback_one_payment(self):
        stats_before = self.synchronize(statistics.get_per_day(self.connection))
        payment = self.add_money_for(self.user_id, 50)
        result = self.synchronize(actions.rollback_payment(self.connection, payment.id))
        self.assertEqual(1, len(result))
        self.assertEqual({'actual': 50, 'total': 50}, result[self.user_id])
        payment = self.synchronize(payments.get_one(self.connection, payment.id))
        self.assertEqual(constants.PAYMENT_STATUS_ROLLBACK, payment.status)
        log = self.synchronize(journal.get_all(self.connection, self.user_id))
        self.assertEqual(constants.JOURNAL_STATUS_ROLLBACK, log[0].status)
        account = self.synchronize(accounts.get(self.connection, self.user_id))
        self.assertEqual((0, 0), (account.balance, account.frozen))
        stats_after = self.synchronize(statistics.get_per_day(self.connection))
        self.assertEqual(stats_before.balance, stats_after.balance)

    def test_rollback_if_withdraw_completed(self):
        stats_before = self.synchronize(statistics.get_per_day(self.connection))
        payment = self.add_money_for(self.user_id, 100)
        request = self.synchronize(withdraw_queue.put(self.connection, self.user_id, 20, '{}'))
        self.synchronize(withdraw_queue.complete(self.connection, request.id))
        report = self.synchronize(actions.rollback_payment(self.connection, payment.id))
        self.assertEqual({'total': 100, 'actual': 80}, report[self.user_id])
        stats_after = self.synchronize(statistics.get_per_day(self.connection))
        self.assertEqual(stats_before.balance, stats_after.balance)
