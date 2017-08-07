import asyncio
import collections
import logging

from .helpers import query
from bim.models import accounts
from bim.models import constants
from bim.models import journal
from bim.models import payments
from bim.models import withdraw_queue

__all__ = ['rollback_payment']

logger = logging.getLogger('bim')


@asyncio.coroutine
def _rollback_transactions(connection, user_id, start_id, actual_amount):
    queue = collections.deque()
    queue.append((user_id, start_id, actual_amount))

    report = collections.defaultdict(lambda: dict.fromkeys(('actual', 'total'), 0))

    while len(queue) > 0:
        cur_user, cur_lower_bound, cur_amount = queue.popleft()
        report[cur_user]['total'] += cur_amount
        records = yield from journal.get_all_payments(connection, cur_user, cur_lower_bound)
        total = 0
        for record in records:
            if record.object_class == journal.ObjectClass.withdraw.value:
                if record.status == constants.JOURNAL_STATUS_SUCCESS:
                    logger.warning(
                        "The withdraw was completed. user_id: %s, transaction_id: %s, amount: %s",
                        cur_user, record.object_id, record.amount
                    )
                    actual_amount -= record.amount
                    continue
                yield from withdraw_queue.rollback(connection, record.object_id)

            total += record.amount
            if total >= cur_amount:
                break
        credit = (yield from accounts.chargeback(connection, cur_user, cur_amount)).credit
        report[cur_user]['actual'] += cur_amount - credit

    yield from accounts.adjust_total_balance(connection, actual_amount)
    return report


@query
def rollback_payment(connection, transaction_id=None):
    payment = yield from payments.rollback(connection, transaction_id)
    return (yield from _rollback_transactions(connection, payment.user_id, payment.journal.id, payment.amount))
