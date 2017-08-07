# Auto-generated file by wsql-codegen(part of WSQL-SDK)
# 2017-08-07 21:37:00.079211

from asyncio import coroutine
from wsql import Error, handle_error
from wsql.cluster import transaction

from . import exceptions


@coroutine
def clean(connection, retention_period=None):
    """
    clean the withdraw_queue

    :param connection: the connection object
    :param retention_period: the period of retention(INTEGER, IN)
    :returns: ("count",)
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"withdraw_queue::clean", (retention_period,))
            return (yield from __cursor.fetchxall())[0]
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def complete(connection, record_id=None):
    """
    complete the withdraw_queue

    :param connection: the connection object
    :param record_id: the id of record(BIGINT, IN)
    :raises: InternalError, NotFound
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"withdraw_queue::complete", (record_id,))
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def get_all(connection, lower_bound=None, max_count=None):
    """
    get the all of the withdraw_queue

    :param connection: the connection object
    :param lower_bound: the bound of lower(BIGINT, IN)
    :param max_count: the count of max(INTEGER, IN)
    :returns: [("account_info", "amount", "id", "status", "timepoint", "user_id")]
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"withdraw_queue::get_all", (lower_bound, max_count))
            return (yield from __cursor.fetchxall())
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def get_for_user(connection, user_id=None):
    """
    get the for of user of the withdraw_queue

    :param connection: the connection object
    :param user_id: the id of user(BIGINT, IN)
    :returns: [("account_info", "amount", "id", "status", "timepoint", "user_id")]
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"withdraw_queue::get_for_user", (user_id,))
            return (yield from __cursor.fetchxall())
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def get_one(connection, record_id=None):
    """
    get the one of the withdraw_queue

    :param connection: the connection object
    :param record_id: the id of record(BIGINT, IN)
    :returns: ("account_info", "amount", "id", "status", "timepoint", "user_id")
    :raises: NotFound
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"withdraw_queue::get_one", (record_id,))
            return (yield from __cursor.fetchxall())[0]
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def put(connection, user_id=None, amount=None, account_info=None):
    """
    put the withdraw_queue

    :param connection: the connection object
    :param user_id: the id of user(BIGINT, IN)
    :param amount: the amount(DECIMAL(28, 8), IN)
    :param account_info: the info of account(VARCHAR(2048), IN)
    :returns: ("id",)
    :raises: NotEnoughMoney, NotFound
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"withdraw_queue::put", (user_id, amount, account_info))
            return (yield from __cursor.fetchxall())[0]
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def rollback(connection, request_id=None):
    """
    rollback the withdraw_queue

    :param connection: the connection object
    :param request_id: the id of request(BIGINT, IN)
    :raises: InternalError, NotFound
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"withdraw_queue::rollback", (request_id,))
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)
