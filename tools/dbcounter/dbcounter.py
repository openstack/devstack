import json
import logging
import os
import threading
import time
import queue

import sqlalchemy
from sqlalchemy.engine import CreateEnginePlugin
from sqlalchemy import event

# https://docs.sqlalchemy.org/en/14/core/connections.html?
# highlight=createengineplugin#sqlalchemy.engine.CreateEnginePlugin

LOG = logging.getLogger(__name__)

# The theory of operation here is that we register this plugin with
# sqlalchemy via an entry_point. It gets loaded by virtue of plugin=
# being in the database connection URL, which gives us an opportunity
# to hook the engines that get created.
#
# We opportunistically spawn a thread, which we feed "hits" to over a
# queue, and which occasionally writes those hits to a special
# database called 'stats'. We access that database with the same user,
# pass, and host as the main connection URL for simplicity.


class LogCursorEventsPlugin(CreateEnginePlugin):
    def __init__(self, url, kwargs):
        self.db_name = url.database
        LOG.info('Registered counter for database %s' % self.db_name)
        new_url = sqlalchemy.engine.URL.create(url.drivername,
                                               url.username,
                                               url.password,
                                               url.host,
                                               url.port,
                                               'stats')

        self.engine = sqlalchemy.create_engine(new_url)
        self.queue = queue.Queue()
        self.thread = None

    def update_url(self, url):
        return url.difference_update_query(["dbcounter"])

    def engine_created(self, engine):
        """Hook the engine creation process.

        This is the plug point for the sqlalchemy plugin. Using
        plugin=$this in the URL causes this method to be called when
        the engine is created, giving us a chance to hook it below.
        """
        event.listen(engine, "before_cursor_execute", self._log_event)

    def ensure_writer_thread(self):
        self.thread = threading.Thread(target=self.stat_writer, daemon=True)
        self.thread.start()

    def _log_event(self, conn, cursor, statement, parameters, context,
                   executemany):
        """Queue a "hit" for this operation to be recorded.

        Attepts to determine the operation by the first word of the
        statement, or 'OTHER' if it cannot be determined.
        """

        # Start our thread if not running. If we were forked after the
        # engine was created and this plugin was associated, our
        # writer thread is gone, so respawn.
        if not self.thread or not self.thread.is_alive():
            self.ensure_writer_thread()

        try:
            op = statement.strip().split(' ', 1)[0] or 'OTHER'
        except Exception:
            op = 'OTHER'

        self.queue.put((self.db_name, op))

    def do_incr(self, db, op, count):
        """Increment the counter for (db,op) by count."""

        query = sqlalchemy.text('INSERT INTO queries (db, op, count) '
                                '  VALUES (:db, :op, :count) '
                                '  ON DUPLICATE KEY UPDATE count=count+:count')
        try:
            with self.engine.begin() as conn:
                r = conn.execute(query, {'db': db, 'op': op, 'count': count})
        except Exception as e:
            LOG.error('Failed to account for access to database %r: %s',
                      db, e)

    def stat_writer(self):
        """Consume messages from the queue and write them in batches.

        This reads "hists" from from a queue fed by _log_event() and
        writes (db,op)+=count stats to the database after ten seconds
        of no activity to avoid triggering a write for every SELECT
        call. Write no less often than every sixty seconds to avoid being
        starved by constant activity.
        """
        LOG.debug('[%i] Writer thread running' % os.getpid())
        while True:
            to_write = {}
            last = time.time()
            while time.time() - last < 60:
                try:
                    item = self.queue.get(timeout=10)
                    to_write.setdefault(item, 0)
                    to_write[item] += 1
                except queue.Empty:
                    break

            if to_write:
                LOG.debug('[%i] Writing DB stats %s' % (
                    os.getpid(),
                    ','.join(['%s:%s=%i' % (db, op, count)
                              for (db, op), count in to_write.items()])))

            for (db, op), count in to_write.items():
                self.do_incr(db, op, count)
