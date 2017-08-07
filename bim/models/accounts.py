# Auto-generated file by wsql-codegen(part of WSQL-SDK)
# 2017-08-07 21:37:00.077256

from asyncio import coroutine
from wsql import Error, handle_error
from wsql.cluster import transaction

from . import exceptions


@coroutine
def adjust_total_balance(connection, amount=None):
    """
    adjust the total of balance of the accounts

    :param connection: the connection object
    :param amount: the amount(DECIMAL(28, 8), IN)
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"accounts::adjust_total_balance", (amount,))
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def block(connection, user_id=None):
    """
    block the accounts

    :param connection: the connection object
    :param user_id: the id of user(BIGINT, IN)
    :raises: NotFound
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"accounts::block", (user_id,))
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def chargeback(connection, user_id=None, amount=None):
    """
    chargeback the accounts

    :param connection: the connection object
    :param user_id: the id of user(BIGINT, IN)
    :param amount: the amount(DECIMAL(28, 8), IN)
    :returns: ("credit",)
    :raises: NotFound
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"accounts::chargeback", (user_id, amount))
            return (yield from __cursor.fetchxall())[0]
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def get(connection, user_id=None):
    """
    get the accounts

    :param connection: the connection object
    :param user_id: the id of user(BIGINT, IN)
    :returns: ("balance", "frozen", "status", "user_id")
    :raises: NotFound
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"accounts::get", (user_id,))
            return (yield from __cursor.fetchxall())[0]
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def lock_accounts(connection, __user_ids=None):
    """
    lock the accounts of the accounts

    :param connection: the connection object
    :param __user_ids: list of {user_id(BIGINT)}
    :returns: [("user_id",)]
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            if not __user_ids:
                return
            __args = ((x.get(y, None) for y in ("user_id",)) for x in __user_ids)
            yield from __cursor.execute(b"DROP TEMPORARY TABLE IF EXISTS `__user_ids`;")
            yield from __cursor.execute(b"CREATE TEMPORARY TABLE `__user_ids`(`user_id` BIGINT) ENGINE=MEMORY;")
            yield from __cursor.executemany(b"INSERT INTO `__user_ids` (`user_id`) VALUES (%s);", __args)
            yield from __cursor.callproc(b"accounts::lock_accounts", ())
            return (yield from __cursor.fetchxall())
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def put(connection, user_id=None, user_email=None):
    """
    put the accounts

    :param connection: the connection object
    :param user_id: the id of user(BIGINT, IN)
    :param user_email: the email of user(VARCHAR(255), IN)
    :returns: ("user_id",)
    :raises: Conflict
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"accounts::put", (user_id, user_email))
            return (yield from __cursor.fetchxall())[0]
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)
