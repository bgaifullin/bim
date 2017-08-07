# Auto-generated file by wsql-codegen(part of WSQL-SDK)
# 2017-08-07 21:37:00.078006

from asyncio import coroutine
from wsql import Error, handle_error
from wsql.cluster import transaction

from . import exceptions

from enum import Enum


class ObjectClass(Enum):
    payments = 'payments'
    withdraw = 'withdraw'


@coroutine
def get_all(connection, user_id=None, upper_bound=None, max_count=None):
    """
    get the all of the journal

    :param connection: the connection object
    :param user_id: the id of user(BIGINT, IN)
    :param upper_bound: the bound of upper(BIGINT, IN)
    :param max_count: the count of max(INTEGER, IN)
    :returns: [("amount", "id", "other_user_id", "timepoint", "user_id")]
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"journal::get_all", (user_id, upper_bound, max_count))
            return (yield from __cursor.fetchxall())
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def get_all_payments(connection, user_id=None, lower_bound=None):
    """
    get the all of payments of the journal

    :param connection: the connection object
    :param user_id: the id of user(BIGINT, IN)
    :param lower_bound: the bound of lower(BIGINT, IN)
    :returns: [("amount", "id", "object_class", "object_id", "other_user_id", "status", "timepoint",
    "user_id")]
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"journal::get_all_payments", (user_id, lower_bound))
            return (yield from __cursor.fetchxall())
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def get_payments_by_class(connection, user_id=None, class_name=None, lower_bound=None):
    """
    get the payments of by of class of the journal

    :param connection: the connection object
    :param user_id: the id of user(BIGINT, IN)
    :param class_name: the name of class(VARCHAR(20), IN)
    :param lower_bound: the bound of lower(BIGINT, IN)
    :returns: [("amount", "id", "object_class", "object_id", "other_user_id", "status", "timepoint",
    "user_id")]
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"journal::get_payments_by_class", (user_id, class_name, lower_bound))
            return (yield from __cursor.fetchxall())
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def poll(connection, upper_bound=None, max_count=None):
    """
    poll the journal

    :param connection: the connection object
    :param upper_bound: the bound of upper(BIGINT, IN)
    :param max_count: the count of max(INT, IN)
    :returns: [("amount", "id", "timepoint", "user_id")]
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"journal::poll", (upper_bound, max_count))
            return (yield from __cursor.fetchxall())
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)


@coroutine
def put(connection, object_class=None, object_id=None, from_user_id=None, to_user_id=None, amount=None, status=None):
    """
    put the journal

    :param connection: the connection object
    :param object_class: the class of object(VARCHAR(24), IN)
    :param object_id: the id of object(BIGINT, IN)
    :param from_user_id: the id of user of from(BIGINT, IN)
    :param to_user_id: the id of user of to(BIGINT, IN)
    :param amount: the amount(DECIMAL(28, 8), IN)
    :param status: the status(TINYINT, IN)
    """

    @transaction
    @coroutine
    def __query(__connection):
        __cursor = __connection.cursor()
        try:
            yield from __cursor.callproc(b"journal::put", (object_class, object_id, from_user_id, to_user_id, amount, status))
        finally:
            yield from __cursor.close()

    try:
        return (yield from connection.execute(__query))
    except Error as e:
        raise handle_error(exceptions, e)
