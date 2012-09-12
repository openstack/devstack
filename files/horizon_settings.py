import os

DEBUG = True
TEMPLATE_DEBUG = DEBUG
PROD = False
USE_SSL = False

LOCAL_PATH = os.path.dirname(os.path.abspath(__file__))

# FIXME: We need to change this to mysql, instead of sqlite.
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': os.path.join(LOCAL_PATH, 'dashboard_openstack.sqlite3'),
        'TEST_NAME': os.path.join(LOCAL_PATH, 'test.sqlite3'),
    },
}

# The default values for these two settings seem to cause issues with apache
CACHE_BACKEND = 'dummy://'
SESSION_ENGINE = 'django.contrib.sessions.backends.cached_db'

# Set a secure and unique SECRET_KEY (the Django default is '')
from horizon.utils import secret_key
SECRET_KEY = secret_key.generate_or_read_from_file(os.path.join(LOCAL_PATH, '.secret_key_store'))

# Send email to the console by default
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
# Or send them to /dev/null
#EMAIL_BACKEND = 'django.core.mail.backends.dummy.EmailBackend'

# django-mailer uses a different settings attribute
MAILER_EMAIL_BACKEND = EMAIL_BACKEND

# Configure these for your outgoing email host
# EMAIL_HOST = 'smtp.my-company.com'
# EMAIL_PORT = 25
# EMAIL_HOST_USER = 'djangomail'
# EMAIL_HOST_PASSWORD = 'top-secret!'

HORIZON_CONFIG = {
    'dashboards': ('nova', 'syspanel', 'settings',),
    'default_dashboard': 'nova',
}

# TODO(tres): Remove these once Keystone has an API to identify auth backend.
OPENSTACK_KEYSTONE_BACKEND = {
    'name': 'native',
    'can_edit_user': True
}

OPENSTACK_HOST = "127.0.0.1"
OPENSTACK_KEYSTONE_URL = "http://%s:5000/v2.0" % OPENSTACK_HOST
# FIXME: this is only needed until keystone fixes its GET /tenants call
# so that it doesn't return everything for admins
OPENSTACK_KEYSTONE_ADMIN_URL = "http://%s:35357/v2.0" % OPENSTACK_HOST
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "Member"

SWIFT_PAGINATE_LIMIT = 100

# If you have external monitoring links, eg:
# EXTERNAL_MONITORING = [
#     ['Nagios','http://foo.com'],
#     ['Ganglia','http://bar.com'],
# ]

#LOGGING = {
#        'version': 1,
#        # When set to True this will disable all logging except
#        # for loggers specified in this configuration dictionary. Note that
#        # if nothing is specified here and disable_existing_loggers is True,
#        # django.db.backends will still log unless it is disabled explicitly.
#        'disable_existing_loggers': False,
#        'handlers': {
#            'null': {
#                'level': 'DEBUG',
#                'class': 'django.utils.log.NullHandler',
#                },
#            'console': {
#                # Set the level to "DEBUG" for verbose output logging.
#                'level': 'INFO',
#                'class': 'logging.StreamHandler',
#                },
#            },
#        'loggers': {
#            # Logging from django.db.backends is VERY verbose, send to null
#            # by default.
#            'django.db.backends': {
#                'handlers': ['null'],
#                'propagate': False,
#                },
#            'horizon': {
#                'handlers': ['console'],
#                'propagate': False,
#            },
#            'novaclient': {
#                'handlers': ['console'],
#                'propagate': False,
#            },
#            'keystoneclient': {
#                'handlers': ['console'],
#                'propagate': False,
#            },
#            'nose.plugins.manager': {
#                'handlers': ['console'],
#                'propagate': False,
#            }
#        }
#}
