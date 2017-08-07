# Auto-generated file by wsql-codegen(part of WSQL-SDK)
# 2017-08-07 21:37:00.078502

from asyncio import coroutine
from wsql import Error, handle_error
from wsql.cluster import transaction

from . import exceptions


@coroutine
def clean(connection, retention_period=None):
    """
    clean the payments

    :param connection: the connection object
    :param retention_period: the period of retention(INTEGER, IN)
    :returns: ("count",)
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"payments::clean", (retention_period,))
            return (yield from __cursor.fetchxall())[0]
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def finish_transaction(connection, transaction_id=None, imi_amount=None, status=None, details=None):
    """
    finish the transaction of the payments

    :param connection: the connection object
    :param transaction_id: the id of transaction(BIGINT, IN)
    :param imi_amount: the amount of imi(DECIMAL(28, 8), IN)
    :param status: the status(INTEGER, IN)
    :param details: the details(VARCHAR(2048), IN)
    :raises: Forbidden, NotFound
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"payments::finish_transaction", (transaction_id, imi_amount, status, details))
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def get_all(connection, lower_bound=None, max_count=None):
    """
    get the all of the payments

    :param connection: the connection object
    :param lower_bound: the bound of lower(BIGINT, IN)
    :param max_count: the count of max(INTEGER, IN)
    :returns: [("details", "id", "imi_amount", "merchant_id", "status", "timepoint", "user_id")]
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"payments::get_all", (lower_bound, max_count))
            return (yield from __cursor.fetchxall())
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def get_one(connection, transaction_id=None):
    """
    get the one of the payments

    :param connection: the connection object
    :param transaction_id: the id of transaction(BIGINT, IN)
    :returns: ("details", "id", "imi_amount", "merchant_id", "status", "timepoint")
    :raises: NotFound
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"payments::get_one", (transaction_id,))
            return (yield from __cursor.fetchxall())[0]
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def rollback(connection, transaction_id=None):
    """
    rollback the payments

    :param connection: the connection object
    :param transaction_id: the id of transaction(BIGINT, IN)
    :returns: ("amount", "id", "journal.id", "status", "user_id")
    :raises: InternalError, NotFound
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"payments::rollback", (transaction_id,))
            return (yield from __cursor.fetchxall())[0]
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def start_transaction(connection, user_id=None, imi_amount=None, card_number=None, merchant_id=None, details=None, black_list_tolerance=None, tries_per_day=None):
    """
    start the transaction of the payments

    :param connection: the connection object
    :param user_id: the id of user(BIGINT, IN)
    :param imi_amount: the amount of imi(DECIMAL(28, 8), IN)
    :param card_number: the number of card(VARCHAR(255), IN)
    :param merchant_id: the id of merchant(VARCHAR(255), IN)
    :param details: the details(VARCHAR(2048), IN)
    :param black_list_tolerance: the tolerance of list of black(INTEGER, IN)
    :param tries_per_day: the day of per of tries(INTEGER, IN)
    :returns: ("id",)
    :raises: AccountBlocked, Forbidden, NotFound
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"payments::start_transaction", (user_id, imi_amount, card_number, merchant_id, details, black_list_tolerance, tries_per_day))
            return (yield from __cursor.fetchxall())[0]
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)
